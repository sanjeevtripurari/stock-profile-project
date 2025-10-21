const express = require('express');
const axios = require('axios');
const jwt = require('jsonwebtoken');
const { Pool } = require('pg');
const redis = require('redis');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const { param, validationResult } = require('express-validator');

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

// Database connection
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

// Redis connection
const redisClient = redis.createClient({
  url: process.env.REDIS_URL,
});

redisClient.connect().catch(console.error);

// Middleware to authenticate JWT tokens
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ error: 'Invalid or expired token' });
    }
    req.user = user;
    next();
  });
};

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    service: 'dividend-service',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    apiKeyConfigured: !!process.env.ALPHA_VANTAGE_API_KEY
  });
});

// Helper function to generate MVP mock dividend data
const generateMockDividendData = (symbol) => {
  // Generate consistent mock data based on symbol hash for MVP
  const hash = symbol.split('').reduce((a, b) => {
    a = ((a << 5) - a) + b.charCodeAt(0);
    return a & a;
  }, 0);
  
  const sectors = ['Technology', 'Healthcare', 'Financial Services', 'Consumer Goods', 'Energy', 'Utilities', 'Real Estate'];
  const industries = ['Software', 'Biotechnology', 'Banking', 'Retail', 'Oil & Gas', 'Electric Utilities', 'REITs'];
  
  // Popular dividend-paying stocks always have dividends, others have 70% chance
  const popularDividendStocks = ['AAPL', 'MSFT', 'GOOGL', 'AMZN', 'TSLA', 'META', 'NVDA', 'JPM', 'JNJ', 'PG', 'KO', 'PEP', 'WMT', 'HD', 'VZ', 'T', 'XOM', 'CVX'];
  const hasDividend = popularDividendStocks.includes(symbol.toUpperCase()) || Math.abs(hash % 100) > 30;
  
  if (!hasDividend) {
    return {
      symbol: symbol.toUpperCase(),
      dividendYield: 0,
      annualDividend: 0,
      exDividendDate: null,
      payoutRatio: 0,
      dividendDate: null,
      forwardPE: Math.abs(hash % 30) + 10,
      trailingPE: Math.abs(hash % 25) + 8,
      beta: (Math.abs(hash % 200) / 100) + 0.5,
      marketCap: `${Math.abs(hash % 500) + 100}B`,
      sector: sectors[Math.abs(hash) % sectors.length],
      industry: industries[Math.abs(hash) % industries.length],
      mvpMode: true
    };
  }

  const dividendYield = (Math.abs(hash % 600) / 100) + 1.5; // 1.5-7.5% yield
  const annualDividend = (Math.abs(hash % 800) / 100) + 1.0; // $1.00-$9.00 annual dividend
  
  // Generate realistic ex-dividend date (quarterly)
  const today = new Date();
  const quarterMonths = [0, 3, 6, 9]; // Jan, Apr, Jul, Oct
  const currentMonth = today.getMonth();
  const nextQuarterMonth = quarterMonths.find(m => m > currentMonth) || quarterMonths[0];
  const exDate = new Date(today.getFullYear(), nextQuarterMonth, 15 + (Math.abs(hash % 10)));
  
  return {
    symbol: symbol.toUpperCase(),
    dividendYield: parseFloat(dividendYield.toFixed(2)),
    annualDividend: parseFloat(annualDividend.toFixed(2)),
    exDividendDate: exDate.toISOString().split('T')[0],
    payoutRatio: Math.abs(hash % 80) + 20, // 20-100% payout ratio
    dividendDate: exDate.toISOString().split('T')[0],
    forwardPE: Math.abs(hash % 30) + 10,
    trailingPE: Math.abs(hash % 25) + 8,
    beta: parseFloat(((Math.abs(hash % 200) / 100) + 0.5).toFixed(2)),
    marketCap: `${Math.abs(hash % 500) + 100}B`,
    sector: sectors[Math.abs(hash) % sectors.length],
    industry: industries[Math.abs(hash) % industries.length],
    mvpMode: true
  };
};

// Helper function to fetch dividend data from Alpha Vantage or use mock data
const fetchDividendData = async (symbol) => {
  try {
    // Use mock data in MVP mode or if no API key
    if (process.env.MVP_MODE === 'true' || !process.env.ALPHA_VANTAGE_API_KEY) {
      return generateMockDividendData(symbol);
    }

    const url = `https://www.alphavantage.co/query?function=OVERVIEW&symbol=${symbol}&apikey=${process.env.ALPHA_VANTAGE_API_KEY}`;
    const response = await axios.get(url, {
      timeout: 10000,
      headers: {
        'User-Agent': 'Stock-Portfolio-System/1.0'
      }
    });

    const data = response.data;

    if (data['Error Message']) {
      console.warn(`Alpha Vantage Error for ${symbol}, using mock data:`, data['Error Message']);
      return generateMockDividendData(symbol);
    }

    if (data['Note'] || data['Information']) {
      console.warn(`API rate limit for ${symbol}, using mock data`);
      return generateMockDividendData(symbol);
    }

    if (!data.Symbol) {
      return generateMockDividendData(symbol);
    }

    return {
      symbol: data.Symbol,
      dividendYield: parseFloat(data.DividendYield || 0) * 100,
      annualDividend: parseFloat(data.DividendPerShare || 0),
      exDividendDate: data.ExDividendDate || null,
      payoutRatio: parseFloat(data.PayoutRatio || 0) * 100,
      dividendDate: data.DividendDate || null,
      forwardPE: parseFloat(data.ForwardPE || 0),
      trailingPE: parseFloat(data.PERatio || 0),
      beta: parseFloat(data.Beta || 0),
      marketCap: data.MarketCapitalization || null,
      sector: data.Sector || null,
      industry: data.Industry || null
    };

  } catch (error) {
    console.warn(`Error fetching dividend data for ${symbol}, using mock data:`, error.message);
    return generateMockDividendData(symbol);
  }
};

// Get user's dividend-paying tickers
app.get('/api/dividends/tickers', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.userId;

    // Check cache first
    const cacheKey = `dividend_tickers:${userId}`;
    const cached = await redisClient.get(cacheKey);
    if (cached) {
      return res.json({ tickers: JSON.parse(cached), cached: true });
    }

    // Get user's portfolio
    const portfolio = await pool.query(
      'SELECT symbol, shares, purchase_price FROM portfolio WHERE user_id = $1',
      [userId]
    );

    if (portfolio.rows.length === 0) {
      return res.json({ tickers: [] });
    }

    // Fetch dividend data for each ticker
    const dividendData = await Promise.all(
      portfolio.rows.map(async (ticker) => {
        try {
          // Check individual ticker cache
          const tickerCacheKey = `dividend:${ticker.symbol}`;
          let dividendInfo = await redisClient.get(tickerCacheKey);
          
          if (dividendInfo) {
            dividendInfo = JSON.parse(dividendInfo);
          } else {
            // Fetch from Alpha Vantage
            dividendInfo = await fetchDividendData(ticker.symbol);
            
            if (dividendInfo) {
              // Cache for 24 hours
              await redisClient.setEx(tickerCacheKey, 86400, JSON.stringify(dividendInfo));
            }
          }

          if (!dividendInfo || dividendInfo.annualDividend <= 0) {
            return null; // Skip non-dividend paying stocks
          }

          return {
            ...dividendInfo,
            shares: ticker.shares,
            purchasePrice: ticker.purchase_price,
            totalValue: ticker.shares * ticker.purchase_price,
            annualDividendIncome: ticker.shares * dividendInfo.annualDividend
          };

        } catch (error) {
          console.error(`Error processing dividend for ${ticker.symbol}:`, error.message);
          return null;
        }
      })
    );

    // Filter out nulls and tickers with no dividends
    const dividendTickers = dividendData.filter(t => t !== null);

    // Cache the result for 30 minutes
    await redisClient.setEx(cacheKey, 1800, JSON.stringify(dividendTickers));

    res.json({ tickers: dividendTickers });

  } catch (error) {
    console.error('Get dividend tickers error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get yearly dividend projection
app.get('/api/dividends/projection', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.userId;

    // Check cache first
    const cacheKey = `dividend_projection:${userId}`;
    const cached = await redisClient.get(cacheKey);
    if (cached) {
      return res.json({ ...JSON.parse(cached), cached: true });
    }

    // Get user's portfolio
    const portfolio = await pool.query(
      'SELECT symbol, shares, purchase_price FROM portfolio WHERE user_id = $1',
      [userId]
    );

    if (portfolio.rows.length === 0) {
      return res.json({
        totalAnnualDividend: 0,
        totalInvested: 0,
        averageYield: 0,
        monthlyAverage: 0,
        quarterlyProjections: [],
        projections: [],
      });
    }

    let totalAnnualDividend = 0;
    let totalInvested = 0;
    let totalCurrentValue = 0;

    const projections = await Promise.all(
      portfolio.rows.map(async (ticker) => {
        try {
          // Get current price from market data service
          let currentPrice = ticker.purchase_price;
          try {
            const marketResponse = await axios.get(
              `${process.env.MARKET_DATA_SERVICE_URL}/api/market/quote/${ticker.symbol}`,
              { timeout: 5000 }
            );
            currentPrice = marketResponse.data.price || ticker.purchase_price;
          } catch (error) {
            console.warn(`Could not fetch current price for ${ticker.symbol}, using purchase price`);
          }

          // Get dividend info
          const tickerCacheKey = `dividend:${ticker.symbol}`;
          let dividendInfo = await redisClient.get(tickerCacheKey);
          
          if (!dividendInfo) {
            dividendInfo = await fetchDividendData(ticker.symbol);
            if (dividendInfo) {
              await redisClient.setEx(tickerCacheKey, 86400, JSON.stringify(dividendInfo));
            }
          } else {
            dividendInfo = JSON.parse(dividendInfo);
          }

          if (!dividendInfo || dividendInfo.annualDividend <= 0) {
            return null; // Skip non-dividend paying stocks
          }

          const invested = ticker.shares * ticker.purchase_price;
          const currentValue = ticker.shares * currentPrice;
          const annualDividend = ticker.shares * dividendInfo.annualDividend;
          
          totalAnnualDividend += annualDividend;
          totalInvested += invested;
          totalCurrentValue += currentValue;

          // Calculate quarterly payments (assuming quarterly dividends)
          const quarterlyDividend = annualDividend / 4;

          return {
            symbol: ticker.symbol,
            shares: ticker.shares,
            purchasePrice: ticker.purchase_price,
            currentPrice: currentPrice,
            invested: invested,
            currentValue: currentValue,
            gain: currentValue - invested,
            gainPercent: invested > 0 ? ((currentValue - invested) / invested) * 100 : 0,
            annualDividend: annualDividend,
            dividendYield: dividendInfo.dividendYield,
            yieldOnCost: invested > 0 ? (annualDividend / invested) * 100 : 0,
            quarterlyPayments: [
              { quarter: 'Q1', amount: quarterlyDividend, months: 'Jan-Mar' },
              { quarter: 'Q2', amount: quarterlyDividend, months: 'Apr-Jun' },
              { quarter: 'Q3', amount: quarterlyDividend, months: 'Jul-Sep' },
              { quarter: 'Q4', amount: quarterlyDividend, months: 'Oct-Dec' },
            ],
            exDividendDate: dividendInfo.exDividendDate,
            payoutRatio: dividendInfo.payoutRatio,
            sector: dividendInfo.sector,
            industry: dividendInfo.industry
          };

        } catch (error) {
          console.error(`Error projecting ${ticker.symbol}:`, error.message);
          return null;
        }
      })
    );

    const validProjections = projections.filter(p => p !== null);
    const averageYield = totalInvested > 0 ? (totalAnnualDividend / totalInvested) * 100 : 0;
    const currentYield = totalCurrentValue > 0 ? (totalAnnualDividend / totalCurrentValue) * 100 : 0;

    // Calculate quarterly projections
    const quarterlyProjections = [
      { quarter: 'Q1', total: validProjections.reduce((sum, p) => sum + p.quarterlyPayments[0].amount, 0) },
      { quarter: 'Q2', total: validProjections.reduce((sum, p) => sum + p.quarterlyPayments[1].amount, 0) },
      { quarter: 'Q3', total: validProjections.reduce((sum, p) => sum + p.quarterlyPayments[2].amount, 0) },
      { quarter: 'Q4', total: validProjections.reduce((sum, p) => sum + p.quarterlyPayments[3].amount, 0) },
    ];

    // Calculate sector diversification
    const sectorBreakdown = {};
    validProjections.forEach(p => {
      const sector = p.sector || 'Unknown';
      if (!sectorBreakdown[sector]) {
        sectorBreakdown[sector] = { count: 0, totalDividend: 0, percentage: 0 };
      }
      sectorBreakdown[sector].count++;
      sectorBreakdown[sector].totalDividend += p.annualDividend;
    });

    Object.keys(sectorBreakdown).forEach(sector => {
      sectorBreakdown[sector].percentage = totalAnnualDividend > 0 
        ? (sectorBreakdown[sector].totalDividend / totalAnnualDividend) * 100 
        : 0;
    });

    const result = {
      totalAnnualDividend,
      totalInvested,
      totalCurrentValue,
      averageYield,
      currentYield,
      monthlyAverage: totalAnnualDividend / 12,
      quarterlyProjections,
      projections: validProjections,
      sectorBreakdown,
      summary: {
        dividendPayingStocks: validProjections.length,
        totalStocks: portfolio.rows.length,
        highestYieldStock: validProjections.length > 0 
          ? validProjections.reduce((max, p) => p.dividendYield > max.dividendYield ? p : max)
          : null,
        largestDividendStock: validProjections.length > 0
          ? validProjections.reduce((max, p) => p.annualDividend > max.annualDividend ? p : max)
          : null
      },
      fetchedAt: new Date().toISOString()
    };

    // Cache for 15 minutes
    await redisClient.setEx(cacheKey, 900, JSON.stringify(result));

    res.json(result);

  } catch (error) {
    console.error('Projection error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get dividend history for a symbol
app.get('/api/dividends/history/:symbol', [
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

    // Check cache first
    const cacheKey = `dividend_history:${symbol}`;
    const cached = await redisClient.get(cacheKey);
    if (cached) {
      return res.json({ ...JSON.parse(cached), cached: true });
    }

    // Check database first
    const history = await pool.query(
      'SELECT * FROM dividend_history WHERE symbol = $1 ORDER BY ex_date DESC LIMIT 20',
      [symbol.toUpperCase()]
    );

    if (history.rows.length > 0) {
      const result = { 
        symbol, 
        history: history.rows,
        source: 'database',
        fetchedAt: new Date().toISOString()
      };
      
      // Cache for 1 hour
      await redisClient.setEx(cacheKey, 3600, JSON.stringify(result));
      
      return res.json(result);
    }

    // Fetch from Alpha Vantage if not in database
    if (!process.env.ALPHA_VANTAGE_API_KEY) {
      return res.status(500).json({ error: 'Alpha Vantage API key not configured' });
    }

    const url = `https://www.alphavantage.co/query?function=TIME_SERIES_MONTHLY_ADJUSTED&symbol=${symbol}&apikey=${process.env.ALPHA_VANTAGE_API_KEY}`;
    
    const response = await axios.get(url, {
      timeout: 15000,
      headers: {
        'User-Agent': 'Stock-Portfolio-System/1.0'
      }
    });

    if (response.data['Error Message']) {
      return res.status(404).json({ error: 'Symbol not found' });
    }

    if (response.data['Note'] || response.data['Information']) {
      return res.status(429).json({ error: 'API rate limit exceeded. Please try again later.' });
    }

    const timeSeries = response.data['Monthly Adjusted Time Series'];
    if (!timeSeries) {
      return res.status(404).json({ error: 'No dividend history found' });
    }

    const dividendHistory = Object.entries(timeSeries)
      .map(([date, data]) => ({
        ex_date: date,
        amount: parseFloat(data['7. dividend amount']),
        payment_date: null, // Not available in this API
        currency: 'USD'
      }))
      .filter(d => d.amount > 0)
      .slice(0, 20);

    // Store in database for future use
    try {
      for (const dividend of dividendHistory) {
        await pool.query(
          'INSERT INTO dividend_history (symbol, ex_date, amount, currency) VALUES ($1, $2, $3, $4) ON CONFLICT (symbol, ex_date) DO NOTHING',
          [symbol.toUpperCase(), dividend.ex_date, dividend.amount, dividend.currency]
        );
      }
    } catch (dbError) {
      console.warn('Could not store dividend history in database:', dbError.message);
    }

    const result = { 
      symbol, 
      history: dividendHistory,
      source: 'alpha_vantage',
      fetchedAt: new Date().toISOString()
    };

    // Cache for 1 hour
    await redisClient.setEx(cacheKey, 3600, JSON.stringify(result));

    res.json(result);

  } catch (error) {
    console.error('History error:', error.message);
    
    if (error.message.includes('API rate limit')) {
      return res.status(429).json({ error: 'API rate limit exceeded. Please try again later.' });
    }
    
    if (error.code === 'ECONNABORTED' || error.code === 'ETIMEDOUT') {
      return res.status(504).json({ error: 'Request timeout. Please try again.' });
    }

    res.status(500).json({ error: 'Failed to fetch dividend history' });
  }
});

// Get dividend calendar (upcoming ex-dividend dates)
app.get('/api/dividends/calendar', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.userId;
    const { days = 30 } = req.query;

    // Check cache
    const cacheKey = `dividend_calendar:${userId}:${days}`;
    const cached = await redisClient.get(cacheKey);
    if (cached) {
      return res.json({ ...JSON.parse(cached), cached: true });
    }

    // Get user's dividend-paying portfolio
    const portfolio = await pool.query(
      'SELECT symbol, shares FROM portfolio WHERE user_id = $1',
      [userId]
    );

    if (portfolio.rows.length === 0) {
      return res.json({ calendar: [] });
    }

    const calendar = [];
    const today = new Date();
    const futureDate = new Date();
    futureDate.setDate(today.getDate() + parseInt(days));

    for (const ticker of portfolio.rows) {
      try {
        // Get dividend info
        const tickerCacheKey = `dividend:${ticker.symbol}`;
        let dividendInfo = await redisClient.get(tickerCacheKey);
        
        if (!dividendInfo) {
          dividendInfo = await fetchDividendData(ticker.symbol);
          if (dividendInfo) {
            await redisClient.setEx(tickerCacheKey, 86400, JSON.stringify(dividendInfo));
          }
        } else {
          dividendInfo = JSON.parse(dividendInfo);
        }

        if (dividendInfo && dividendInfo.exDividendDate && dividendInfo.annualDividend > 0) {
          const exDate = new Date(dividendInfo.exDividendDate);
          
          // Check if ex-dividend date is within the specified range
          if (exDate >= today && exDate <= futureDate) {
            calendar.push({
              symbol: ticker.symbol,
              shares: ticker.shares,
              exDividendDate: dividendInfo.exDividendDate,
              estimatedDividend: dividendInfo.annualDividend / 4, // Quarterly estimate
              estimatedIncome: ticker.shares * (dividendInfo.annualDividend / 4),
              dividendYield: dividendInfo.dividendYield,
              daysUntilExDate: Math.ceil((exDate - today) / (1000 * 60 * 60 * 24))
            });
          }
        }
      } catch (error) {
        console.warn(`Could not process calendar for ${ticker.symbol}:`, error.message);
      }
    }

    // Sort by ex-dividend date
    calendar.sort((a, b) => new Date(a.exDividendDate) - new Date(b.exDividendDate));

    const result = {
      calendar,
      totalUpcomingIncome: calendar.reduce((sum, item) => sum + item.estimatedIncome, 0),
      daysRange: parseInt(days),
      fetchedAt: new Date().toISOString()
    };

    // Cache for 6 hours
    await redisClient.setEx(cacheKey, 21600, JSON.stringify(result));

    res.json(result);

  } catch (error) {
    console.error('Calendar error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Clear dividend cache
app.delete('/api/dividends/cache/:symbol?', async (req, res) => {
  try {
    const { symbol } = req.params;

    if (symbol) {
      // Clear specific symbol cache
      const keys = await redisClient.keys(`*dividend*:*${symbol.toUpperCase()}*`);
      if (keys.length > 0) {
        await redisClient.del(keys);
      }
      res.json({ message: `Dividend cache cleared for ${symbol.toUpperCase()}`, keysCleared: keys.length });
    } else {
      // Clear all dividend cache
      const keys = await redisClient.keys('dividend*');
      if (keys.length > 0) {
        await redisClient.del(keys);
      }
      res.json({ message: 'All dividend cache cleared', keysCleared: keys.length });
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

const PORT = process.env.PORT || 3004;

app.listen(PORT, () => {
  console.log(`Dividend Service running on port ${PORT}`);
  console.log(`Health check: http://localhost:${PORT}/health`);
  console.log(`Alpha Vantage API configured: ${!!process.env.ALPHA_VANTAGE_API_KEY}`);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down gracefully');
  await pool.end();
  await redisClient.quit();
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('SIGINT received, shutting down gracefully');
  await pool.end();
  await redisClient.quit();
  process.exit(0);
});