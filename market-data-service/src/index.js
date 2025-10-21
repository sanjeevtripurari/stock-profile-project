const express = require('express');
const axios = require('axios');
const redis = require('redis');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const { param, body, validationResult } = require('express-validator');

const app = express();

// Security middleware
app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Rate limiting
const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: { error: 'Too many requests, please try again later' }
});

app.use('/api/', generalLimiter);

// Redis connection
const redisClient = redis.createClient({
  url: process.env.REDIS_URL,
});

redisClient.connect().catch(console.error);

const ALPHA_VANTAGE_KEY = process.env.ALPHA_VANTAGE_API_KEY;
const CACHE_TTL = 300; // 5 minutes for quotes
const INTRADAY_CACHE_TTL = 60; // 1 minute for intraday data

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    service: 'market-data-service',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    apiKeyConfigured: !!ALPHA_VANTAGE_KEY
  });
});

// Helper function to validate Alpha Vantage response
const validateAlphaVantageResponse = (data) => {
  if (data['Error Message']) {
    throw new Error(`Alpha Vantage Error: ${data['Error Message']}`);
  }
  if (data['Note']) {
    throw new Error('API call frequency limit reached. Please try again later.');
  }
  if (data['Information']) {
    throw new Error('API call frequency limit reached. Please try again later.');
  }
  return true;
};

// Helper function to generate MVP mock data for symbols
const generateMockQuote = (symbol) => {
  // Generate consistent mock data based on symbol hash for MVP
  const hash = symbol.split('').reduce((a, b) => {
    a = ((a << 5) - a) + b.charCodeAt(0);
    return a & a;
  }, 0);
  
  const basePrice = Math.abs(hash % 500) + 50; // Price between $50-$550
  const volatility = (Math.abs(hash % 100) / 1000) + 0.01; // 1-10% volatility
  
  const high = basePrice * (1 + volatility);
  const low = basePrice * (1 - volatility);
  const open = basePrice * (1 + (volatility * (Math.random() - 0.5)));
  const change = basePrice * (volatility * (Math.random() - 0.5));
  const price = basePrice + change;
  
  return {
    symbol: symbol.toUpperCase(),
    price: parseFloat(price.toFixed(2)),
    change: parseFloat(change.toFixed(2)),
    changePercent: `${(change / basePrice * 100).toFixed(2)}%`,
    volume: Math.floor(Math.abs(hash % 10000000) + 100000),
    lastUpdated: new Date().toISOString().split('T')[0],
    high: parseFloat(high.toFixed(2)),
    low: parseFloat(low.toFixed(2)),
    open: parseFloat(open.toFixed(2)),
    previousClose: parseFloat(basePrice.toFixed(2)),
    marketCap: `${(Math.abs(hash % 1000) + 100)}B`,
    pe: parseFloat((Math.abs(hash % 30) + 5).toFixed(2)),
    fetchedAt: new Date().toISOString(),
    mvpMode: true
  };
};

// Get single stock quote
app.get('/api/market/quote/:symbol', [
  param('symbol').trim().isLength({ min: 1, max: 10 }).toUpperCase()
], async (req, res) => {
  try {
    // Check validation errors
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ 
        error: 'Invalid symbol format' 
      });
    }

    const { symbol } = req.params;
    const cacheKey = `quote:${symbol.toUpperCase()}`;

    // Check cache first
    const cached = await redisClient.get(cacheKey);
    if (cached) {
      const data = JSON.parse(cached);
      return res.json({ ...data, cached: true });
    }

    // Check if market is open
    const marketStatus = await getMarketStatus();
    let data;

    if (!ALPHA_VANTAGE_KEY || process.env.MVP_MODE === 'true') {
      // MVP Mode: Use mock data
      data = generateMockQuote(symbol);
    } else {
      try {
        // Try to fetch from Alpha Vantage
        const url = `https://www.alphavantage.co/query?function=GLOBAL_QUOTE&symbol=${symbol}&apikey=${ALPHA_VANTAGE_KEY}`;
        
        const response = await axios.get(url, {
          timeout: 10000,
          headers: {
            'User-Agent': 'Stock-Portfolio-System/1.0'
          }
        });

        validateAlphaVantageResponse(response.data);

        const quote = response.data['Global Quote'];
        if (!quote || !quote['01. symbol']) {
          // Fallback to mock data if symbol not found
          data = generateMockQuote(symbol);
        } else {
          data = {
            symbol: quote['01. symbol'],
            price: parseFloat(quote['05. price']) || 0,
            change: parseFloat(quote['09. change']) || 0,
            changePercent: quote['10. change percent'] || '0%',
            volume: parseInt(quote['06. volume']) || 0,
            lastUpdated: quote['07. latest trading day'] || new Date().toISOString().split('T')[0],
            high: parseFloat(quote['03. high']) || 0,
            low: parseFloat(quote['04. low']) || 0,
            open: parseFloat(quote['02. open']) || 0,
            previousClose: parseFloat(quote['08. previous close']) || 0,
            marketCap: null,
            pe: null,
            fetchedAt: new Date().toISOString()
          };

          // If market is closed, use the high price as current price for MVP
          if (!marketStatus.isOpen && data.high > 0) {
            data.price = data.high;
            data.change = data.high - data.previousClose;
            data.changePercent = data.previousClose > 0 ? 
              `${((data.change / data.previousClose) * 100).toFixed(2)}%` : '0%';
            data.marketClosedPrice = true;
          }
        }
      } catch (error) {
        console.warn('Alpha Vantage fetch failed, using mock data:', error.message);
        // Fallback to mock data on any error
        data = generateMockQuote(symbol);
      }
    }

    // Cache for 5 minutes
    await redisClient.setEx(cacheKey, CACHE_TTL, JSON.stringify(data));

    res.json(data);

  } catch (error) {
    console.error('Quote fetch error:', error.message);
    
    if (error.message.includes('API call frequency')) {
      return res.status(429).json({ error: 'API rate limit exceeded. Please try again later.' });
    }
    
    if (error.code === 'ECONNABORTED' || error.code === 'ETIMEDOUT') {
      return res.status(504).json({ error: 'Request timeout. Please try again.' });
    }

    res.status(500).json({ error: 'Failed to fetch quote data' });
  }
});

// Get batch quotes
app.post('/api/market/batch-quotes', [
  body('symbols').isArray({ min: 1, max: 10 }),
  body('symbols.*').trim().isLength({ min: 1, max: 10 })
], async (req, res) => {
  try {
    // Check validation errors
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ 
        error: 'Invalid symbols array. Maximum 10 symbols allowed.' 
      });
    }

    const { symbols } = req.body;
    const uniqueSymbols = [...new Set(symbols.map(s => s.toUpperCase()))];

    // Process symbols in parallel with rate limiting
    const promises = uniqueSymbols.map(async (symbol) => {
      try {
        // Check cache first
        const cacheKey = `quote:${symbol}`;
        const cached = await redisClient.get(cacheKey);
        
        if (cached) {
          return { ...JSON.parse(cached), cached: true };
        }

        // If not cached, we'll need to fetch from API
        // For batch requests, we'll use a simplified approach to avoid rate limits
        const url = `https://www.alphavantage.co/query?function=GLOBAL_QUOTE&symbol=${symbol}&apikey=${ALPHA_VANTAGE_KEY}`;
        
        const response = await axios.get(url, {
          timeout: 8000,
          headers: {
            'User-Agent': 'Stock-Portfolio-System/1.0'
          }
        });

        validateAlphaVantageResponse(response.data);

        const quote = response.data['Global Quote'];
        if (!quote || !quote['01. symbol']) {
          return { symbol, error: 'Symbol not found' };
        }

        const data = {
          symbol: quote['01. symbol'],
          price: parseFloat(quote['05. price']) || 0,
          change: parseFloat(quote['09. change']) || 0,
          changePercent: quote['10. change percent'] || '0%',
          volume: parseInt(quote['06. volume']) || 0,
          lastUpdated: quote['07. latest trading day'] || new Date().toISOString().split('T')[0],
          fetchedAt: new Date().toISOString()
        };

        // Cache the result
        await redisClient.setEx(cacheKey, CACHE_TTL, JSON.stringify(data));

        return data;

      } catch (error) {
        console.error(`Error fetching ${symbol}:`, error.message);
        return { symbol, error: error.message };
      }
    });

    // Add delay between requests to respect rate limits
    const quotes = [];
    for (let i = 0; i < promises.length; i++) {
      if (i > 0) {
        await new Promise(resolve => setTimeout(resolve, 1000)); // 1 second delay
      }
      quotes.push(await promises[i]);
    }

    res.json({ 
      quotes,
      requestedSymbols: uniqueSymbols.length,
      successfulFetches: quotes.filter(q => !q.error).length
    });

  } catch (error) {
    console.error('Batch quotes error:', error);
    res.status(500).json({ error: 'Failed to fetch batch quotes' });
  }
});

// Get intraday data
app.get('/api/market/intraday/:symbol', [
  param('symbol').trim().isLength({ min: 1, max: 10 }).toUpperCase()
], async (req, res) => {
  try {
    // Check validation errors
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ 
        error: 'Invalid symbol format' 
      });
    }

    const { symbol } = req.params;
    const { interval = '5min', outputsize = 'compact' } = req.query;
    
    // Validate interval
    const validIntervals = ['1min', '5min', '15min', '30min', '60min'];
    if (!validIntervals.includes(interval)) {
      return res.status(400).json({ 
        error: 'Invalid interval. Must be one of: ' + validIntervals.join(', ') 
      });
    }

    const cacheKey = `intraday:${symbol}:${interval}:${outputsize}`;

    // Check cache
    const cached = await redisClient.get(cacheKey);
    if (cached) {
      const data = JSON.parse(cached);
      return res.json({ ...data, cached: true });
    }

    if (!ALPHA_VANTAGE_KEY) {
      return res.status(500).json({ error: 'Alpha Vantage API key not configured' });
    }

    const url = `https://www.alphavantage.co/query?function=TIME_SERIES_INTRADAY&symbol=${symbol}&interval=${interval}&outputsize=${outputsize}&apikey=${ALPHA_VANTAGE_KEY}`;
    
    const response = await axios.get(url, {
      timeout: 15000, // 15 second timeout for intraday data
      headers: {
        'User-Agent': 'Stock-Portfolio-System/1.0'
      }
    });

    validateAlphaVantageResponse(response.data);

    const timeSeries = response.data[`Time Series (${interval})`];
    if (!timeSeries) {
      return res.status(404).json({ error: 'Intraday data not found for symbol' });
    }

    // Process and limit data points
    const dataPoints = Object.entries(timeSeries)
      .slice(0, outputsize === 'compact' ? 100 : 500)
      .map(([time, values]) => ({
        time,
        open: parseFloat(values['1. open']) || 0,
        high: parseFloat(values['2. high']) || 0,
        low: parseFloat(values['3. low']) || 0,
        close: parseFloat(values['4. close']) || 0,
        volume: parseInt(values['5. volume']) || 0,
      }))
      .sort((a, b) => new Date(a.time) - new Date(b.time)); // Sort chronologically

    const data = {
      symbol,
      interval,
      outputsize,
      dataPoints: dataPoints.length,
      data: dataPoints,
      lastRefreshed: response.data['Meta Data'] ? response.data['Meta Data']['3. Last Refreshed'] : new Date().toISOString(),
      fetchedAt: new Date().toISOString()
    };

    // Cache for 1 minute (intraday data changes frequently)
    await redisClient.setEx(cacheKey, INTRADAY_CACHE_TTL, JSON.stringify(data));

    res.json(data);

  } catch (error) {
    console.error('Intraday error:', error.message);
    
    if (error.message.includes('API call frequency')) {
      return res.status(429).json({ error: 'API rate limit exceeded. Please try again later.' });
    }
    
    if (error.code === 'ECONNABORTED' || error.code === 'ETIMEDOUT') {
      return res.status(504).json({ error: 'Request timeout. Please try again.' });
    }

    res.status(500).json({ error: 'Failed to fetch intraday data' });
  }
});

// Search symbols
app.get('/api/market/search', async (req, res) => {
  try {
    const { keywords } = req.query;
    
    if (!keywords || keywords.trim().length < 2) {
      return res.status(400).json({ error: 'Keywords must be at least 2 characters long' });
    }

    const cacheKey = `search:${keywords.toLowerCase()}`;

    // Check cache
    const cached = await redisClient.get(cacheKey);
    if (cached) {
      const data = JSON.parse(cached);
      return res.json({ ...data, cached: true });
    }

    if (!ALPHA_VANTAGE_KEY) {
      return res.status(500).json({ error: 'Alpha Vantage API key not configured' });
    }

    const url = `https://www.alphavantage.co/query?function=SYMBOL_SEARCH&keywords=${encodeURIComponent(keywords)}&apikey=${ALPHA_VANTAGE_KEY}`;
    
    const response = await axios.get(url, {
      timeout: 10000,
      headers: {
        'User-Agent': 'Stock-Portfolio-System/1.0'
      }
    });

    validateAlphaVantageResponse(response.data);

    const matches = response.data['bestMatches'] || [];
    
    const results = matches.slice(0, 10).map(match => ({
      symbol: match['1. symbol'],
      name: match['2. name'],
      type: match['3. type'],
      region: match['4. region'],
      marketOpen: match['5. marketOpen'],
      marketClose: match['6. marketClose'],
      timezone: match['7. timezone'],
      currency: match['8. currency'],
      matchScore: parseFloat(match['9. matchScore']) || 0
    }));

    const data = {
      keywords,
      results,
      count: results.length,
      fetchedAt: new Date().toISOString()
    };

    // Cache search results for 1 hour
    await redisClient.setEx(cacheKey, 3600, JSON.stringify(data));

    res.json(data);

  } catch (error) {
    console.error('Search error:', error.message);
    
    if (error.message.includes('API call frequency')) {
      return res.status(429).json({ error: 'API rate limit exceeded. Please try again later.' });
    }

    res.status(500).json({ error: 'Failed to search symbols' });
  }
});

// Helper function to get market status
const getMarketStatus = async () => {
  try {
    const cacheKey = 'market:status';
    const cached = await redisClient.get(cacheKey);
    if (cached) {
      return JSON.parse(cached);
    }

    // Simple market status based on time (US Eastern Time)
    const now = new Date();
    const easternTime = new Date(now.toLocaleString("en-US", {timeZone: "America/New_York"}));
    const hour = easternTime.getHours();
    const minute = easternTime.getMinutes();
    const dayOfWeek = easternTime.getDay();
    
    const currentTime = hour * 60 + minute;
    const marketOpen = 9 * 60 + 30; // 9:30 AM
    const marketClose = 16 * 60; // 4:00 PM

    const isWeekday = dayOfWeek >= 1 && dayOfWeek <= 5;
    const isDuringMarketHours = currentTime >= marketOpen && currentTime < marketClose;
    
    const status = {
      isOpen: isWeekday && isDuringMarketHours,
      timezone: 'America/New_York',
      currentTime: easternTime.toLocaleTimeString('en-US', { 
        timeZone: 'America/New_York',
        hour12: false 
      }),
      marketOpen: '09:30',
      marketClose: '16:00',
      fetchedAt: new Date().toISOString()
    };

    await redisClient.setEx(cacheKey, 300, JSON.stringify(status));
    return status;
  } catch (error) {
    console.error('Market status error:', error);
    return { isOpen: false, fetchedAt: new Date().toISOString() };
  }
};

// Get market status
app.get('/api/market/status', async (req, res) => {
  try {
    const status = await getMarketStatus();
    
    // Calculate next open/close times for display
    const now = new Date();
    const easternTime = new Date(now.toLocaleString("en-US", {timeZone: "America/New_York"}));
    const dayOfWeek = easternTime.getDay();
    const weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    const currentWeekday = weekdays[dayOfWeek];

    if (status.isOpen) {
      status.nextClose = `${currentWeekday} 16:00`;
    } else if (dayOfWeek >= 1 && dayOfWeek <= 5) {
      const hour = easternTime.getHours();
      const minute = easternTime.getMinutes();
      const currentTime = hour * 60 + minute;
      const marketOpen = 9 * 60 + 30;
      
      if (currentTime < marketOpen) {
        status.nextOpen = `${currentWeekday} 09:30`;
      } else {
        status.nextOpen = 'Monday 09:30';
      }
    } else {
      status.nextOpen = 'Monday 09:30';
    }

    res.json(status);

  } catch (error) {
    console.error('Market status error:', error);
    res.status(500).json({ error: 'Failed to get market status' });
  }
});

// Clear cache endpoint (for admin use)
app.delete('/api/market/cache/:symbol?', async (req, res) => {
  try {
    const { symbol } = req.params;

    if (symbol) {
      // Clear specific symbol cache
      const keys = await redisClient.keys(`*:${symbol.toUpperCase()}*`);
      if (keys.length > 0) {
        await redisClient.del(keys);
      }
      res.json({ message: `Cache cleared for ${symbol.toUpperCase()}`, keysCleared: keys.length });
    } else {
      // Clear all market data cache
      const keys = await redisClient.keys('quote:*');
      const intradayKeys = await redisClient.keys('intraday:*');
      const searchKeys = await redisClient.keys('search:*');
      const allKeys = [...keys, ...intradayKeys, ...searchKeys];
      
      if (allKeys.length > 0) {
        await redisClient.del(allKeys);
      }
      res.json({ message: 'All market data cache cleared', keysCleared: allKeys.length });
    }

  } catch (error) {
    console.error('Cache clear error:', error);
    res.status(500).json({ error: 'Failed to clear cache' });
  }
});

// Error handling middleware
app.use((error, req, res, next) => {
  console.error('Unhandled error:', error);
  res.status(500).json({ error: 'Internal server error' });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ error: 'Endpoint not found' });
});

const PORT = process.env.PORT || 3003;

app.listen(PORT, () => {
  console.log(`Market Data Service running on port ${PORT}`);
  console.log(`Health check: http://localhost:${PORT}/health`);
  console.log(`Alpha Vantage API configured: ${!!ALPHA_VANTAGE_KEY}`);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down gracefully');
  await redisClient.quit();
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('SIGINT received, shutting down gracefully');
  await redisClient.quit();
  process.exit(0);
});