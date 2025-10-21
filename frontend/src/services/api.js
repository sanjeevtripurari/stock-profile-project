import axios from 'axios';
import { getToken, removeToken } from '../utils/auth';

// Create axios instance
const api = axios.create({
  baseURL: process.env.REACT_APP_API_URL || '/api',
  timeout: 10000,
});

// Request interceptor to add auth token
api.interceptors.request.use(
  (config) => {
    const token = getToken();
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Response interceptor to handle auth errors
api.interceptors.response.use(
  (response) => {
    return response;
  },
  (error) => {
    if (error.response?.status === 401 || error.response?.status === 403) {
      removeToken();
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

// Auth API calls
export const register = async (name, email, password) => {
  const response = await api.post('/users/register', {
    name,
    email,
    password,
  });
  return response.data;
};

export const login = async (email, password) => {
  const response = await api.post('/users/login', {
    email,
    password,
  });
  return response.data;
};

export const getProfile = async () => {
  const response = await api.get('/users/profile');
  return response.data;
};

export const updateProfile = async (data) => {
  const response = await api.put('/users/profile', data);
  return response.data;
};

export const changePassword = async (currentPassword, newPassword) => {
  const response = await api.put('/users/password', {
    currentPassword,
    newPassword,
  });
  return response.data;
};

export const logout = async () => {
  try {
    await api.post('/users/logout');
  } catch (error) {
    // Ignore errors on logout
  }
  removeToken();
};

// Portfolio API calls
export const getTickers = async () => {
  const response = await api.get('/portfolio/tickers');
  return response.data;
};

export const addTicker = async (symbol, shares, purchasePrice) => {
  const response = await api.post('/portfolio/tickers', {
    symbol,
    shares,
    purchasePrice,
  });
  return response.data;
};

export const updateTicker = async (id, data) => {
  const response = await api.put(`/portfolio/tickers/${id}`, data);
  return response.data;
};

export const deleteTicker = async (symbol) => {
  const response = await api.delete(`/portfolio/tickers/${symbol}`);
  return response.data;
};

export const buyShares = async (symbol, shares, price) => {
  const response = await api.post(`/portfolio/tickers/${symbol}/buy`, {
    shares,
    price,
  });
  return response.data;
};

export const sellShares = async (symbol, shares, price) => {
  const response = await api.post(`/portfolio/tickers/${symbol}/sell`, {
    shares,
    price,
  });
  return response.data;
};

export const getBudget = async () => {
  const response = await api.get('/portfolio/budget');
  return response.data;
};

export const setBudget = async (totalBudget) => {
  const response = await api.put('/portfolio/budget', {
    totalBudget,
  });
  return response.data;
};

export const getPortfolioSummary = async () => {
  const response = await api.get('/portfolio/summary');
  return response.data;
};

// Market Data API calls
export const getQuote = async (symbol) => {
  const response = await api.get(`/market/quote/${symbol}`);
  return response.data;
};

export const getBatchQuotes = async (symbols) => {
  const response = await api.post('/market/batch-quotes', {
    symbols,
  });
  return response.data;
};

export const getIntradayData = async (symbol, interval = '5min') => {
  const response = await api.get(`/market/intraday/${symbol}?interval=${interval}`);
  return response.data;
};

export const searchSymbols = async (keywords) => {
  const response = await api.get(`/market/search?keywords=${encodeURIComponent(keywords)}`);
  return response.data;
};

export const getMarketStatus = async () => {
  const response = await api.get('/market/status');
  return response.data;
};

// Dividend API calls
export const getDividendTickers = async () => {
  const response = await api.get('/dividends/tickers');
  return response.data;
};

export const getDividendProjection = async () => {
  const response = await api.get('/dividends/projection');
  return response.data;
};

export const getDividendHistory = async (symbol) => {
  const response = await api.get(`/dividends/history/${symbol}`);
  return response.data;
};

export const getDividendCalendar = async (days = 30) => {
  const response = await api.get(`/dividends/calendar?days=${days}`);
  return response.data;
};

// Health check
export const healthCheck = async () => {
  const response = await axios.get('/health');
  return response.data;
};

export default api;