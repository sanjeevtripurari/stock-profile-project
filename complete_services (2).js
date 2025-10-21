// ============================================
// MARKET DATA SERVICE - COMPLETE
// market-data-service/src/index.js
// ============================================

const express = require('express');
const axios = require('axios');
const redis = require('redis');

const app = express();
app.use(express.json());

const redisClient = redis.createClient({
  url: process.env.REDIS_URL,
});
redisClient.connect();

const ALPHA_VANTAGE_KEY = process.env.ALPHA_VANTAGE_API_KEY;
const CACHE_TTL = 300; // 5 minutes

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'market-data-service' });
});

// Get single stock quote
app.get('/api/market/quote/:symbol', async (req, res) => {
  try {
    const { symbol } = req.params;
    const cacheKey = `quote:${symbol.toUpperCase()}`;

    // Check cache first
    const cached = await redisClient.get(cacheKey);
    if (cached) {
      return res.json({ ...JSON.parse(cached), cached: true });
    }

    // Fetch from Alpha Vantage
    const url = `https://www.alphavantage.co/query?function=GLOBAL_QUOTE&symbol=${symbol}&apikey=${ALPHA_VANTAGE_KEY}`;
    const response = await axios.get(url);

    if (!response.data['Global Quote']) {
      return res.status(404).json({ error: 'Symbol not found' });
    }

    const quote = response.data['Global Quote'];
    const data = {
      symbol: quote['01. symbol'],
      price: parseFloat(quote['05. price']),
      change: parseFloat(quote['09. change']),
      changePercent: quote['10. change percent'],
      volume: parseInt(quote['06. volume']),
      lastUpdated: quote['07. latest trading day'],
      high: parseFloat(quote['03. high']),
      low: parseFloat(quote['04. low']),
      open: parseFloat(quote['02. open']),
      previousClose: parseFloat(quote['08. previous close']),
    };

    // Cache for 5 minutes
    await redisClient.setEx(cacheKey, CACHE_TTL, JSON.stringify(data));

    res.json(data);
  } catch (error) {
    console.error('Quote fetch error:', error.message);
    res.status(500).json({ error: 'Failed to fetch quote' });
  }
});

// Get batch quotes
app.post('/api/market/batch-quotes', async (req, res) => {
  try {
    const { symbols } = req.body;

    if (!symbols || !Array.isArray(symbols)) {
      return res.status(400).json({ error: 'Symbols array required' });
    }

    const promises = symbols.map(symbol =>
      axios.get(`http://localhost:${process.env.PORT}/api/market/quote/${symbol}`)
        .then(r => r.data)
        .catch(e => ({ symbol, error: e.message }))
    );

    const quotes = await Promise.all(promises);
    res.json({ quotes });
  } catch (error) {
    console.error('Batch quotes error:', error);
    res.status(500).json({ error: 'Failed to fetch batch quotes' });
  }
});

// Get intraday data
app.get('/api/market/intraday/:symbol', async (req, res) => {
  try {
    const { symbol } = req.params;
    const { interval = '5min' } = req.query;
    const cacheKey = `intraday:${symbol}:${interval}`;

    const cached = await redisClient.get(cacheKey);
    if (cached) {
      return res.json({ ...JSON.parse(cached), cached: true });
    }

    const url = `https://www.alphavantage.co/query?function=TIME_SERIES_INTRADAY&symbol=${symbol}&interval=${interval}&apikey=${ALPHA_VANTAGE_KEY}`;
    const response = await axios.get(url);

    const timeSeries = response.data[`Time Series (${interval})`];
    if (!timeSeries) {
      return res.status(404).json({ error: 'Data not found' });
    }

    const data = {
      symbol,
      interval,
      data: Object.entries(timeSeries).slice(0, 100).map(([time, values]) => ({
        time,
        open: parseFloat(values['1. open']),
        high: parseFloat(values['2. high']),
        low: parseFloat(values['3. low']),
        close: parseFloat(values['4. close']),
        volume: parseInt(values['5. volume']),
      })),
    };

    await redisClient.setEx(cacheKey, 60, JSON.stringify(data));
    res.json(data);
  } catch (error) {
    console.error('Intraday error:', error);
    res.status(500).json({ error: 'Failed to fetch intraday data' });
  }
});

const PORT = process.env.PORT || 3003;
app.listen(PORT, () => {
  console.log(`Market Data Service running on port ${PORT}`);
});

// ============================================
// market-data-service/package.json
// ============================================
/*
{
  "name": "market-data-service",
  "version": "1.0.0",
  "main": "src/index.js",
  "dependencies": {
    "express": "^4.18.2",
    "axios": "^1.6.0",
    "redis": "^4.6.10"
  }
}
*/

// ============================================
// DIVIDEND SERVICE - COMPLETE
// dividend-service/src/index.js
// ============================================

const express = require('express');
const axios = require('axios');
const jwt = require('jsonwebtoken');
const { Pool } = require('pg');
const redis = require('redis');

const app = express();
app.use(express.json());

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

const redisClient = redis.createClient({
  url: process.env.REDIS_URL,
});
redisClient.connect();

const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) return res.status(401).json({ error: 'Access token required' });

  jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
    if (err) return res.status(403).json({ error: 'Invalid token' });
    req.user = user;
    next();
  });
};

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'dividend-service' });
});

// Get user's dividend-paying tickers
app.get('/api/dividends/tickers', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.userId;

    // Get user's portfolio
    const portfolio = await pool.query(
      'SELECT symbol, shares FROM portfolio WHERE user_id = $1',
      [userId]
    );

    if (portfolio.rows.length === 0) {
      return res.json({ tickers: [] });
    }

    // Fetch dividend data for each ticker
    const dividendData = await Promise.all(
      portfolio.rows.map(async (ticker) => {
        try {
          // Check cache
          const cacheKey = `dividend:${ticker.symbol}`;
          const cached = await redisClient.get(cacheKey);
          
          if (cached) {
            return { ...JSON.parse(cached), shares: ticker.shares };
          }

          // Fetch from Alpha Vantage
          const url = `https://www.alphavantage.co/query?function=OVERVIEW&symbol=${ticker.symbol}&apikey=${process.env.ALPHA_VANTAGE_API_KEY}`;
          const response = await axios.get(url);
          const data = response.data;

          if (!data.Symbol) {
            return null;
          }

          const dividendInfo = {
            symbol: ticker.symbol,
            dividendYield: parseFloat(data.DividendYield || 0) * 100,
            annualDividend: parseFloat(data.DividendPerShare || 0),
            exDividendDate: data.ExDividendDate || null,
            payoutRatio: parseFloat(data.PayoutRatio || 0) * 100,
            shares: ticker.shares,
          };

          // Cache for 24 hours
          await redisClient.setEx(cacheKey, 86400, JSON.stringify(dividendInfo));

          return dividendInfo;
        } catch (error) {
          console.error(`Error fetching dividend for ${ticker.symbol}:`, error.message);
          return null;
        }
      })
    );

    // Filter out nulls and tickers with no dividends
    const dividendTickers = dividendData.filter(
      t => t && t.annualDividend > 0
    );

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
        projections: [],
      });
    }

    let totalAnnualDividend = 0;
    let totalInvested = 0;

    const projections = await Promise.all(
      portfolio.rows.map(async (ticker) => {
        try {
          // Get current price and dividend info
          const marketUrl = `${process.env.MARKET_DATA_SERVICE_URL}/api/market/quote/${ticker.symbol}`;
          const priceResponse = await axios.get(marketUrl).catch(() => null);
          
          const currentPrice = priceResponse?.data?.price || ticker.purchase_price;

          // Get dividend info
          const cacheKey = `dividend:${ticker.symbol}`;
          let dividendInfo = await redisClient.get(cacheKey);
          
          if (!dividendInfo) {
            const url = `https://www.alphavantage.co/query?function=OVERVIEW&symbol=${ticker.symbol}&apikey=${process.env.ALPHA_VANTAGE_API_KEY}`;
            const response = await axios.get(url);
            const data = response.data;

            dividendInfo = {
              annualDividend: parseFloat(data.DividendPerShare || 0),
              dividendYield: parseFloat(data.DividendYield || 0) * 100,
            };

            await redisClient.setEx(cacheKey, 86400, JSON.stringify(dividendInfo));
          } else {
            dividendInfo = JSON.parse(dividendInfo);
          }

          const invested = ticker.shares * ticker.purchase_price;
          const currentValue = ticker.shares * currentPrice;
          const annualDividend = ticker.shares * dividendInfo.annualDividend;
          
          totalAnnualDividend += annualDividend;
          totalInvested += invested;

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
            gainPercent: ((currentValue - invested) / invested) * 100,
            annualDividend: annualDividend,
            dividendYield: dividendInfo.dividendYield,
            quarterlyPayments: [
              { quarter: 'Q1', amount: quarterlyDividend, month: 'Jan-Mar' },
              { quarter: 'Q2', amount: quarterlyDividend, month: 'Apr-Jun' },
              { quarter: 'Q3', amount: quarterlyDividend, month: 'Jul-Sep' },
              { quarter: 'Q4', amount: quarterlyDividend, month: 'Oct-Dec' },
            ],
          };
        } catch (error) {
          console.error(`Error projecting ${ticker.symbol}:`, error.message);
          return null;
        }
      })
    );

    const validProjections = projections.filter(p => p && p.annualDividend > 0);
    const averageYield = totalInvested > 0 
      ? (totalAnnualDividend / totalInvested) * 100 
      : 0;

    res.json({
      totalAnnualDividend,
      totalInvested,
      averageYield,
      monthlyAverage: totalAnnualDividend / 12,
      projections: validProjections,
    });
  } catch (error) {
    console.error('Projection error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get dividend history for a symbol
app.get('/api/dividends/history/:symbol', async (req, res) => {
  try {
    const { symbol } = req.params;

    // Check database first
    const history = await pool.query(
      'SELECT * FROM dividend_history WHERE symbol = $1 ORDER BY ex_date DESC LIMIT 20',
      [symbol.toUpperCase()]
    );

    if (history.rows.length > 0) {
      return res.json({ symbol, history: history.rows });
    }

    // Fetch from API if not in database
    const url = `https://www.alphavantage.co/query?function=TIME_SERIES_MONTHLY_ADJUSTED&symbol=${symbol}&apikey=${process.env.ALPHA_VANTAGE_API_KEY}`;
    const response = await axios.get(url);
    const timeSeries = response.data['Monthly Adjusted Time Series'];

    if (!timeSeries) {
      return res.status(404).json({ error: 'No dividend history found' });
    }

    const dividendHistory = Object.entries(timeSeries)
      .map(([date, data]) => ({
        date,
        dividend: parseFloat(data['7. dividend amount']),
      }))
      .filter(d => d.dividend > 0)
      .slice(0, 20);

    res.json({ symbol, history: dividendHistory });
  } catch (error) {
    console.error('History error:', error);
    res.status(500).json({ error: 'Failed to fetch dividend history' });
  }
});

const PORT = process.env.PORT || 3004;
app.listen(PORT, () => {
  console.log(`Dividend Service running on port ${PORT}`);
});

// ============================================
// dividend-service/package.json
// ============================================
/*
{
  "name": "dividend-service",
  "version": "1.0.0",
  "main": "src/index.js",
  "dependencies": {
    "express": "^4.18.2",
    "axios": "^1.6.0",
    "jsonwebtoken": "^9.0.2",
    "pg": "^8.11.3",
    "redis": "^4.6.10"
  }
}
*/

// ============================================
// COMPLETE PORTFOLIO SERVICE
// portfolio-service/src/index.js
// ============================================

const express = require('express');
const jwt = require('jsonwebtoken');
const { Pool } = require('pg');
const redis = require('redis');

const app = express();
app.use(express.json());

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

const redisClient = redis.createClient({
  url: process.env.REDIS_URL,
});
redisClient.connect();

const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) return res.status(401).json({ error: 'Access token required' });

  jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
    if (err) return res.status(403).json({ error: 'Invalid token' });
    req.user = user;
    next();
  });
};

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'portfolio-service' });
});

// Add ticker to portfolio
app.post('/api/portfolio/tickers', authenticateToken, async (req, res) => {
  try {
    const { symbol, shares, purchasePrice } = req.body;
    const userId = req.user.userId;

    if (!symbol) {
      return res.status(400).json({ error: 'Ticker symbol is required' });
    }

    // Check if ticker already exists
    const existing = await pool.query(
      'SELECT id FROM portfolio WHERE user_id = $1 AND symbol = $2',
      [userId, symbol.toUpperCase()]
    );

    if (existing.rows.length > 0) {
      return res.status(409).json({ error: 'Ticker already in portfolio' });
    }

    // Add ticker
    const result = await pool.query(
      'INSERT INTO portfolio (user_id, symbol, shares, purchase_price) VALUES ($1, $2, $3, $4) RETURNING *',
      [userId, symbol.toUpperCase(), shares || 0, purchasePrice || 0]
    );

    // Update allocated budget if shares and price provided
    if (shares && purchasePrice) {
      const allocation = shares * purchasePrice;
      await pool.query(
        'UPDATE budget SET allocated = allocated + $1 WHERE user_id = $2',
        [allocation, userId]
      );
    }

    // Invalidate cache
    await redisClient.del(`portfolio:${userId}`);

    res.status(201).json({
      message: 'Ticker added successfully',
      ticker: result.rows[0],
    });
  } catch (error) {
    console.error('Add ticker error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get user's tickers
app.get('/api/portfolio/tickers', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.userId;

    // Check cache
    const cached = await redisClient.get(`portfolio:${userId}`);
    if (cached) {
      return res.json({ tickers: JSON.parse(cached), cached: true });
    }

    // Get from database
    const result = await pool.query(
      'SELECT * FROM portfolio WHERE user_id = $1 ORDER BY created_at DESC',
      [userId]
    );

    // Cache for 5 minutes
    await redisClient.setEx(
      `portfolio:${userId}`,
      300,
      JSON.stringify(result.rows)
    );

    res.json({ tickers: result.rows });
  } catch (error) {
    console.error('Get tickers error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update ticker
app.put('/api/portfolio/tickers/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { shares, purchasePrice } = req.body;
    const userId = req.user.userId;

    // Get current ticker
    const current = await pool.query(
      'SELECT * FROM portfolio WHERE id = $1 AND user_id = $2',
      [id, userId]
    );

    if (current.rows.length === 0) {
      return res.status(404).json({ error: 'Ticker not found' });
    }

    const oldAllocation = current.rows[0].shares * current.rows[0].purchase_price;
    const newAllocation = (shares || current.rows[0].shares) * 
                         (purchasePrice || current.rows[0].purchase_price);

    // Update ticker
    const result = await pool.query(
      'UPDATE portfolio SET shares = $1, purchase_price = $2 WHERE id = $3 AND user_id = $4 RETURNING *',
      [shares || current.rows[0].shares, purchasePrice || current.rows[0].purchase_price, id, userId]
    );

    // Update budget allocation
    const allocationDiff = newAllocation - oldAllocation;
    await pool.query(
      'UPDATE budget SET allocated = allocated + $1 WHERE user_id = $2',
      [allocationDiff, userId]
    );

    // Invalidate cache
    await redisClient.del(`portfolio:${userId}`);

    res.json({
      message: 'Ticker updated successfully',
      ticker: result.rows[0],
    });
  } catch (error) {
    console.error('Update ticker error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Delete ticker
app.delete('/api/portfolio/tickers/:symbol', authenticateToken, async (req, res) => {
  try {
    const { symbol } = req.params;
    const userId = req.user.userId;

    // Get ticker to calculate allocation release
    const ticker = await pool.query(
      'SELECT * FROM portfolio WHERE user_id = $1 AND symbol = $2',
      [userId, symbol.toUpperCase()]
    );

    if (ticker.rows.length === 0) {
      return res.status(404).json({ error: 'Ticker not found' });
    }

    const allocation = ticker.rows[0].shares * ticker.rows[0].purchase_price;

    // Delete ticker
    await pool.query(
      'DELETE FROM portfolio WHERE user_id = $1 AND symbol = $2',
      [userId, symbol.toUpperCase()]
    );

    // Release allocation
    await pool.query(
      'UPDATE budget SET allocated = allocated - $1 WHERE user_id = $2',
      [allocation, userId]
    );

    // Invalidate cache
    await redisClient.del(`portfolio:${userId}`);

    res.json({ message: 'Ticker removed successfully' });
  } catch (error) {
    console.error('Delete ticker error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Set/Update budget
app.put('/api/portfolio/budget', authenticateToken, async (req, res) => {
  try {
    const { totalBudget } = req.body;
    const userId = req.user.userId;

    if (!totalBudget || totalBudget <= 0) {
      return res.status(400).json({ error: 'Valid budget amount required' });
    }

    // Check if budget exists
    const existing = await pool.query(
      'SELECT * FROM budget WHERE user_id = $1',
      [userId]
    );

    let result;
    if (existing.rows.length > 0) {
      // Update existing budget
      result = await pool.query(
        'UPDATE budget SET total_budget = $1, updated_at = CURRENT_TIMESTAMP WHERE user_id = $2 RETURNING *',
        [totalBudget, userId]
      );
    } else {
      // Create new budget
      result = await pool.query(
        'INSERT INTO budget (user_id, total_budget) VALUES ($1, $2) RETURNING *',
        [userId, totalBudget]
      );
    }

    res.json({
      message: 'Budget updated successfully',
      budget: result.rows[0],
    });
  } catch (error) {
    console.error('Budget update error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get budget
app.get('/api/portfolio/budget', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.userId;

    const result = await pool.query(
      'SELECT * FROM budget WHERE user_id = $1',
      [userId]
    );

    if (result.rows.length === 0) {
      return res.json({
        total_budget: 0,
        allocated: 0,
        available: 0,
      });
    }

    res.json({ budget: result.rows[0] });
  } catch (error) {
    console.error('Get budget error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get portfolio summary
app.get('/api/portfolio/summary', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.userId;

    // Get all tickers
    const tickers = await pool.query(
      'SELECT * FROM portfolio WHERE user_id = $1',
      [userId]
    );

    // Get budget
    const budget = await pool.query(
      'SELECT * FROM budget WHERE user_id = $1',
      [userId]
    );

    const totalTickers = tickers.rows.length;
    const totalShares = tickers.rows.reduce((sum, t) => sum + parseFloat(t.shares || 0), 0);
    const totalInvested = tickers.rows.reduce((sum, t) => 
      sum + (parseFloat(t.shares || 0) * parseFloat(t.purchase_price || 0)), 0
    );

    res.json({
      totalTickers,
      totalShares,
      totalInvested,
      budget: budget.rows[0] || { total_budget: 0, allocated: 0, available: 0 },
    });
  } catch (error) {
    console.error('Summary error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

const PORT = process.env.PORT || 3002;
app.listen(PORT, () => {
  console.log(`Portfolio Service running on port ${PORT}`);
});

// ============================================
// NGINX Configuration
// nginx/nginx.conf
// ============================================
/*
events {
    worker_connections 1024;
}

http {
    upstream user_service {
        server user-service:3001;
    }

    upstream portfolio_service {
        server portfolio-service:3002;
    }

    upstream market_data_service {
        server market-data-service:3003;
    }

    upstream dividend_service {
        server dividend-service:3004;
    }

    server {
        listen 80;
        
        # Request logging
        access_log /var/log/nginx/access.log;
        error_log /var/log/nginx/error.log;

        # CORS headers
        add_header 'Access-Control-Allow-Origin' '*' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'Authorization, Content-Type' always;

        # OPTIONS handling
        if ($request_method = 'OPTIONS') {
            return 204;
        }

        # User service routes
        location /api/users {
            proxy_pass http://user_service;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        # Portfolio service routes
        location /api/portfolio {
            proxy_pass http://portfolio_service;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        # Market data service routes
        location /api/market {
            proxy_pass http://market_data_service;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        # Dividend service routes
        location /api/dividends {
            proxy_pass http://dividend_service;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        # Health check endpoint
        location /health {
            return 200 '{"status":"healthy","service":"api-gateway"}';
            add_header Content-Type application/json;
        }
    }
}
*/

// ============================================
// nginx/Dockerfile
// ============================================
/*
FROM nginx:alpine
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
*/