-- Stock Portfolio Management System Database Schema
-- PostgreSQL initialization script

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- Create portfolio table
CREATE TABLE IF NOT EXISTS portfolio (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    symbol VARCHAR(10) NOT NULL,
    shares DECIMAL(10,2) DEFAULT 0,
    purchase_price DECIMAL(10,2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, symbol)
);

-- Create budget table
CREATE TABLE IF NOT EXISTS budget (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE UNIQUE,
    total_budget DECIMAL(15,2) NOT NULL,
    allocated DECIMAL(15,2) DEFAULT 0,
    available DECIMAL(15,2) GENERATED ALWAYS AS (total_budget - allocated) STORED,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create dividend history table
CREATE TABLE IF NOT EXISTS dividend_history (
    id SERIAL PRIMARY KEY,
    symbol VARCHAR(10) NOT NULL,
    ex_date DATE NOT NULL,
    payment_date DATE,
    amount DECIMAL(10,4) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(symbol, ex_date)
);

-- Create user sessions table (for JWT blacklisting)
CREATE TABLE IF NOT EXISTS user_sessions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_portfolio_user_id ON portfolio(user_id);
CREATE INDEX IF NOT EXISTS idx_portfolio_symbol ON portfolio(symbol);
CREATE INDEX IF NOT EXISTS idx_portfolio_user_symbol ON portfolio(user_id, symbol);
CREATE INDEX IF NOT EXISTS idx_dividend_symbol ON dividend_history(symbol);
CREATE INDEX IF NOT EXISTS idx_dividend_ex_date ON dividend_history(ex_date);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_active ON users(is_active);
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_token_hash ON user_sessions(token_hash);
CREATE INDEX IF NOT EXISTS idx_sessions_expires_at ON user_sessions(expires_at);

-- Create function to update timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for users table
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON users
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Create trigger for portfolio table
DROP TRIGGER IF EXISTS update_portfolio_updated_at ON portfolio;
CREATE TRIGGER update_portfolio_updated_at 
    BEFORE UPDATE ON portfolio
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Create trigger for budget table
DROP TRIGGER IF EXISTS update_budget_updated_at ON budget;
CREATE TRIGGER update_budget_updated_at 
    BEFORE UPDATE ON budget
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Function to clean expired sessions
CREATE OR REPLACE FUNCTION clean_expired_sessions()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM user_sessions WHERE expires_at < CURRENT_TIMESTAMP;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions to stockuser
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO stockuser;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO stockuser;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO stockuser;

-- Insert sample data for testing (uncomment for development)
-- INSERT INTO users (email, password_hash, name) VALUES
-- ('demo@example.com', '$2b$10$rQZ8kqV1qQZ8kqV1qQZ8kOEp3xYzK4rQZ8kqV1qQZ8kqV1qQZ8kq', 'Demo User');

-- Create view for portfolio summary
CREATE OR REPLACE VIEW portfolio_summary AS
SELECT 
    u.id as user_id,
    u.name,
    u.email,
    COUNT(p.id) as total_tickers,
    COALESCE(SUM(p.shares), 0) as total_shares,
    COALESCE(SUM(p.shares * p.purchase_price), 0) as total_invested,
    b.total_budget,
    b.allocated,
    b.available
FROM users u
LEFT JOIN portfolio p ON u.id = p.user_id
LEFT JOIN budget b ON u.id = b.user_id
WHERE u.is_active = true
GROUP BY u.id, u.name, u.email, b.total_budget, b.allocated, b.available;

-- Grant access to view
GRANT SELECT ON portfolio_summary TO stockuser;

-- Database initialization complete
SELECT 'Database initialized successfully!' as status;