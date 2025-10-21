const express = require('express');
const jwt = require('jsonwebtoken');
const { Pool } = require('pg');
const redis = require('redis');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const { body, validationResult } = require('express-validator');
const axios = require('axios');

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

// Helper function to get current market price (uses high price when market closed)
const getCurrentPrice = async (symbol) => {
  try {
    const response = await axios.get(`${process.env.MARKET_DATA_SERVICE_URL}/api/market/quote/${symbol}`, {
      timeout: 5000
    });

    if (response.data) {
      // Use current price if available, otherwise use high price
      let price = response.data.price || response.data.high || 0;

      if (price > 0) {
        return parseFloat(price);
      }
    }

    // Fallback: generate mock price if MVP mode is enabled
    if (process.env.MVP_MODE === 'true') {
      return generateMockPrice(symbol);
    }

    return 0;
  } catch (error) {
    console.warn(`Could not fetch current price for ${symbol}:`, error.message);

    // Fallback: generate mock price if MVP mode is enabled
    if (process.env.MVP_MODE === 'true') {
      return generateMockPrice(symbol);
    }

    return 0;
  }
};

// Helper function to generate consistent mock prices for MVP mode
const generateMockPrice = (symbol) => {
  const hash = symbol.split('').reduce((a, b) => {
    a = ((a << 5) - a) + b.charCodeAt(0);
    return a & a;
  }, 0);

  const basePrice = Math.abs(hash % 500) + 50; // Price between $50-$550
  return parseFloat(basePrice.toFixed(2));
};

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
app.get('/health', async (req, res) => {
  try {
    // Check database connectivity
    const dbResult = await pool.query('SELECT 1 as health_check');
    const dbHealthy = dbResult.rows && dbResult.rows.length > 0;
    
    // Check Redis connectivity  
    const redisResult = await redisClient.ping();
    const redisHealthy = redisResult === 'PONG';
    
    const overallHealthy = dbHealthy && redisHealthy;
    
    res.status(overallHealthy ? 200 : 503).json({
      status: overallHealthy ? 'healthy' : 'unhealthy',
      service: 'portfolio-service',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      dependencies: {
        database: dbHealthy ? 'connected' : 'disconnected',
        redis: redisHealthy ? 'connected' : 'disconnected'
      }
    });
  } catch (error) {
    console.error('Health check failed:', error);
    res.status(503).json({
      status: 'unhealthy',
      service: 'portfolio-service',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      error: error.message,
      dependencies: {
        database: 'disconnected',
        redis: 'disconnected'
      }
    });
  }
});

// Add ticker to portfolio
app.post('/api/portfolio/tickers', authenticateToken, [
  body('symbol').trim().isLength({ min: 1, max: 10 }).toUpperCase(),
  body('shares').optional().isFloat({ min: 0 }),
  body('purchasePrice').optional().isFloat({ min: 0 })
], async (req, res) => {
  try {
    // Check validation errors
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Validation failed',
        details: errors.array()
      });
    }

    let { symbol, shares = 0, purchasePrice } = req.body;
    const userId = req.user.userId;
    symbol = symbol.toUpperCase();

    // Ensure numeric values
    shares = parseFloat(shares) || 0;
    purchasePrice = parseFloat(purchasePrice) || 0;

    // If no purchase price provided, fetch current market price
    if (!purchasePrice || purchasePrice === 0) {
      purchasePrice = await getCurrentPrice(symbol);
      if (purchasePrice === 0) {
        return res.status(400).json({
          error: 'Could not fetch current market price. Please provide a purchase price.'
        });
      }
    }

    // Check if ticker already exists
    const existing = await pool.query(
      'SELECT id, shares, purchase_price FROM portfolio WHERE user_id = $1 AND symbol = $2',
      [userId, symbol]
    );

    if (existing.rows.length > 0) {
      return res.status(409).json({
        error: 'Ticker already in portfolio. Use Buy button to add more shares.'
      });
    }

    // Start transaction
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Add ticker
      const result = await client.query(
        'INSERT INTO portfolio (user_id, symbol, shares, purchase_price) VALUES ($1, $2, $3, $4) RETURNING *',
        [userId, symbol, shares, purchasePrice]
      );

      // Update allocated budget if shares and price provided
      if (shares > 0 && purchasePrice > 0) {
        const allocation = shares * purchasePrice;

        // Check if budget exists, create if not
        const budgetCheck = await client.query(
          'SELECT id FROM budget WHERE user_id = $1',
          [userId]
        );

        if (budgetCheck.rows.length === 0) {
          await client.query(
            'INSERT INTO budget (user_id, total_budget, allocated) VALUES ($1, $2, $3)',
            [userId, allocation, allocation]
          );
        } else {
          await client.query(
            'UPDATE budget SET allocated = allocated + $1 WHERE user_id = $2',
            [allocation, userId]
          );
        }
      }

      await client.query('COMMIT');

      // Invalidate cache
      await redisClient.del(`portfolio:${userId}`);
      await redisClient.del(`budget:${userId}`);

      res.status(201).json({
        message: 'Ticker added successfully',
        ticker: result.rows[0],
        marketPrice: purchasePrice,
        usedMarketPrice: !req.body.purchasePrice
      });

    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }

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
      const cachedData = JSON.parse(cached);
      // Ensure cached data is also properly formatted
      const formattedCached = cachedData.map(ticker => ({
        ...ticker,
        shares: parseFloat(ticker.shares),
        purchase_price: parseFloat(ticker.purchase_price)
      }));
      return res.json({ tickers: formattedCached, cached: true });
    }

    // Get from database
    const result = await pool.query(
      'SELECT * FROM portfolio WHERE user_id = $1 ORDER BY created_at DESC',
      [userId]
    );

    // Format numbers properly
    const formattedTickers = result.rows.map(ticker => ({
      ...ticker,
      shares: parseFloat(ticker.shares),
      purchase_price: parseFloat(ticker.purchase_price)
    }));

    // Cache for 5 minutes
    await redisClient.setEx(
      `portfolio:${userId}`,
      300,
      JSON.stringify(formattedTickers)
    );

    res.json({ tickers: formattedTickers });

  } catch (error) {
    console.error('Get tickers error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update ticker
app.put('/api/portfolio/tickers/:id', authenticateToken, [
  body('shares').optional().isFloat({ min: 0 }),
  body('purchasePrice').optional().isFloat({ min: 0 })
], async (req, res) => {
  try {
    // Check validation errors
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Validation failed',
        details: errors.array()
      });
    }

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

    const currentTicker = current.rows[0];
    const currentShares = parseFloat(currentTicker.shares);
    const currentPrice = parseFloat(currentTicker.purchase_price);
    const oldAllocation = currentShares * currentPrice;

    const newShares = shares !== undefined ? parseFloat(shares) : currentShares;
    const newPrice = purchasePrice !== undefined ? parseFloat(purchasePrice) : currentPrice;
    const newAllocation = newShares * newPrice;

    // Start transaction
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Update ticker
      const result = await client.query(
        'UPDATE portfolio SET shares = $1, purchase_price = $2, updated_at = CURRENT_TIMESTAMP WHERE id = $3 AND user_id = $4 RETURNING *',
        [newShares, newPrice, id, userId]
      );

      // Update budget allocation
      const allocationDiff = newAllocation - oldAllocation;
      if (allocationDiff !== 0) {
        // Ensure budget exists
        const budgetCheck = await client.query(
          'SELECT id FROM budget WHERE user_id = $1',
          [userId]
        );

        if (budgetCheck.rows.length === 0) {
          await client.query(
            'INSERT INTO budget (user_id, total_budget, allocated) VALUES ($1, $2, $3)',
            [userId, Math.max(newAllocation, 0), Math.max(newAllocation, 0)]
          );
        } else {
          await client.query(
            'UPDATE budget SET allocated = GREATEST(allocated + $1, 0) WHERE user_id = $2',
            [allocationDiff, userId]
          );
        }
      }

      await client.query('COMMIT');

      // Invalidate cache
      await redisClient.del(`portfolio:${userId}`);
      await redisClient.del(`budget:${userId}`);

      res.json({
        message: 'Ticker updated successfully',
        ticker: result.rows[0],
      });

    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }

  } catch (error) {
    console.error('Update ticker error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Buy more shares (add to existing position)
app.post('/api/portfolio/tickers/:symbol/buy', authenticateToken, [
  body('shares').isFloat({ min: 0.01 }),
  body('price').optional().isFloat({ min: 0 })
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Validation failed',
        details: errors.array()
      });
    }

    const { symbol } = req.params;
    let { shares, price } = req.body;
    const userId = req.user.userId;

    // Get current market price if not provided
    if (!price) {
      price = await getCurrentPrice(symbol.toUpperCase());
      if (price === 0) {
        return res.status(400).json({
          error: 'Could not fetch current market price. Please provide a price.'
        });
      }
    }

    // Get existing position
    const existing = await pool.query(
      'SELECT * FROM portfolio WHERE user_id = $1 AND symbol = $2',
      [userId, symbol.toUpperCase()]
    );

    if (existing.rows.length === 0) {
      return res.status(404).json({ error: 'Stock not found in portfolio' });
    }

    const currentPosition = existing.rows[0];
    const currentShares = parseFloat(currentPosition.shares);
    const currentPrice = parseFloat(currentPosition.purchase_price);
    const newShares = parseFloat(shares);
    const newPrice = parseFloat(price);

    const newTotalShares = currentShares + newShares;
    const newAvgPrice = ((currentShares * currentPrice) + (newShares * newPrice)) / newTotalShares;
    const allocation = newShares * newPrice;

    // Start transaction
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Update position
      const result = await client.query(
        'UPDATE portfolio SET shares = $1, purchase_price = $2, updated_at = CURRENT_TIMESTAMP WHERE user_id = $3 AND symbol = $4 RETURNING *',
        [newTotalShares, newAvgPrice, userId, symbol.toUpperCase()]
      );

      // Update budget allocation
      await client.query(
        'UPDATE budget SET allocated = allocated + $1 WHERE user_id = $2',
        [allocation, userId]
      );

      await client.query('COMMIT');

      // Invalidate cache
      await redisClient.del(`portfolio:${userId}`);

      res.json({
        message: 'Shares purchased successfully',
        ticker: result.rows[0],
        transaction: {
          type: 'buy',
          shares: newShares,
          price: newPrice,
          total: newShares * newPrice
        }
      });

    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }

  } catch (error) {
    console.error('Buy shares error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Sell shares (reduce existing position)
app.post('/api/portfolio/tickers/:symbol/sell', authenticateToken, [
  body('shares').isFloat({ min: 0.01 }),
  body('price').optional().isFloat({ min: 0 })
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Validation failed',
        details: errors.array()
      });
    }

    const { symbol } = req.params;
    let { shares, price } = req.body;
    const userId = req.user.userId;

    // Get current market price if not provided
    if (!price) {
      price = await getCurrentPrice(symbol.toUpperCase());
      if (price === 0) {
        return res.status(400).json({
          error: 'Could not fetch current market price. Please provide a price.'
        });
      }
    }

    // Get existing position
    const existing = await pool.query(
      'SELECT * FROM portfolio WHERE user_id = $1 AND symbol = $2',
      [userId, symbol.toUpperCase()]
    );

    if (existing.rows.length === 0) {
      return res.status(404).json({ error: 'Stock not found in portfolio' });
    }

    const currentPosition = existing.rows[0];

    const currentShares = parseFloat(currentPosition.shares);
    const currentPrice = parseFloat(currentPosition.purchase_price);
    const sellShares = parseFloat(shares);
    const sellPrice = parseFloat(price);

    if (sellShares > currentShares) {
      return res.status(400).json({
        error: `Cannot sell ${sellShares} shares. You only own ${currentShares} shares.`
      });
    }

    const newTotalShares = currentShares - sellShares;
    const allocationReduction = sellShares * currentPrice; // Use original purchase price for allocation

    // Start transaction
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      if (newTotalShares === 0) {
        // Remove position entirely
        await client.query(
          'DELETE FROM portfolio WHERE user_id = $1 AND symbol = $2',
          [userId, symbol.toUpperCase()]
        );
      } else {
        // Update position
        await client.query(
          'UPDATE portfolio SET shares = $1, updated_at = CURRENT_TIMESTAMP WHERE user_id = $2 AND symbol = $3',
          [newTotalShares, userId, symbol.toUpperCase()]
        );
      }

      // Update budget allocation (reduce)
      await client.query(
        'UPDATE budget SET allocated = GREATEST(allocated - $1, 0) WHERE user_id = $2',
        [allocationReduction, userId]
      );

      await client.query('COMMIT');

      // Invalidate cache
      await redisClient.del(`portfolio:${userId}`);

      const gainLoss = (sellPrice - currentPrice) * sellShares;

      res.json({
        message: newTotalShares === 0 ? 'Position closed successfully' : 'Shares sold successfully',
        transaction: {
          type: 'sell',
          shares: sellShares,
          price: sellPrice,
          total: sellShares * sellPrice,
          gainLoss: gainLoss,
          remainingShares: newTotalShares
        }
      });

    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }

  } catch (error) {
    console.error('Sell shares error:', error);
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

    const tickerShares = parseFloat(ticker.rows[0].shares);
    const tickerPrice = parseFloat(ticker.rows[0].purchase_price);
    const allocation = tickerShares * tickerPrice;

    // Start transaction
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Delete ticker
      await client.query(
        'DELETE FROM portfolio WHERE user_id = $1 AND symbol = $2',
        [userId, symbol.toUpperCase()]
      );

      // Release allocation
      if (allocation > 0) {
        await client.query(
          'UPDATE budget SET allocated = GREATEST(allocated - $1, 0) WHERE user_id = $2',
          [allocation, userId]
        );
      }

      await client.query('COMMIT');

      // Invalidate cache
      await redisClient.del(`portfolio:${userId}`);
      await redisClient.del(`budget:${userId}`);

      res.json({ message: 'Ticker removed successfully' });

    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }

  } catch (error) {
    console.error('Delete ticker error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Set/Update budget
app.put('/api/portfolio/budget', authenticateToken, [
  body('totalBudget').isFloat({ min: 0 })
], async (req, res) => {
  try {
    // Check validation errors
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Valid budget amount required'
      });
    }

    const { totalBudget } = req.body;
    const userId = req.user.userId;

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

    // Invalidate cache
    await redisClient.del(`budget:${userId}`);

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

    // Check cache
    const cached = await redisClient.get(`budget:${userId}`);
    if (cached) {
      return res.json({ budget: JSON.parse(cached), cached: true });
    }

    const result = await pool.query(
      'SELECT * FROM budget WHERE user_id = $1',
      [userId]
    );

    let budget;
    if (result.rows.length === 0) {
      budget = {
        total_budget: 0,
        allocated: 0,
        available: 0,
      };
    } else {
      budget = result.rows[0];
    }

    // Cache for 5 minutes
    await redisClient.setEx(`budget:${userId}`, 300, JSON.stringify(budget));

    res.json({ budget });

  } catch (error) {
    console.error('Get budget error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get portfolio summary
app.get('/api/portfolio/summary', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.userId;

    // Check cache
    const cached = await redisClient.get(`summary:${userId}`);
    if (cached) {
      return res.json({ summary: JSON.parse(cached), cached: true });
    }

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

    // Calculate allocation percentages
    const allocations = tickers.rows.map(ticker => {
      const shares = parseFloat(ticker.shares);
      const price = parseFloat(ticker.purchase_price);
      const tickerValue = shares * price;
      return {
        symbol: ticker.symbol,
        value: tickerValue,
        percentage: totalInvested > 0 ? (tickerValue / totalInvested) * 100 : 0
      };
    });

    const summary = {
      totalTickers,
      totalShares,
      totalInvested,
      budget: budget.rows[0] || { total_budget: 0, allocated: 0, available: 0 },
      allocations,
      diversification: {
        isWellDiversified: allocations.every(a => a.percentage <= 20),
        maxAllocation: Math.max(...allocations.map(a => a.percentage), 0),
        recommendations: []
      }
    };

    // Add diversification recommendations
    if (summary.diversification.maxAllocation > 30) {
      summary.diversification.recommendations.push('Consider reducing concentration in your largest position');
    }
    if (totalTickers < 5 && totalTickers > 0) {
      summary.diversification.recommendations.push('Consider adding more stocks for better diversification');
    }

    // Cache for 5 minutes
    await redisClient.setEx(`summary:${userId}`, 300, JSON.stringify(summary));

    res.json({ summary });

  } catch (error) {
    console.error('Summary error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get ticker details
app.get('/api/portfolio/tickers/:symbol', authenticateToken, async (req, res) => {
  try {
    const { symbol } = req.params;
    const userId = req.user.userId;

    const result = await pool.query(
      'SELECT * FROM portfolio WHERE user_id = $1 AND symbol = $2',
      [userId, symbol.toUpperCase()]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Ticker not found in portfolio' });
    }

    res.json({ ticker: result.rows[0] });

  } catch (error) {
    console.error('Get ticker error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Error handling middleware
app.use((error, req, res, next) => {
  console.error('Unhandled error:', error);
  res.status(500).json({ error: 'Internal server error' });
});

// Clear cache endpoint (for debugging)
app.delete('/api/portfolio/cache', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.userId;
    await redisClient.del(`portfolio:${userId}`);
    await redisClient.del(`budget:${userId}`);
    res.json({ message: 'Cache cleared successfully' });
  } catch (error) {
    console.error('Cache clear error:', error);
    res.status(500).json({ error: 'Failed to clear cache' });
  }
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ error: 'Endpoint not found' });
});

const PORT = process.env.PORT || 3002;

app.listen(PORT, () => {
  console.log(`Portfolio Service running on port ${PORT}`);
  console.log(`Health check: http://localhost:${PORT}/health`);
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