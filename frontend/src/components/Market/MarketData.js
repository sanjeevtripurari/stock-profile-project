import React, { useState, useEffect } from 'react';
import { getQuote, searchSymbols, getMarketStatus, getIntradayData } from '../../services/api';

function MarketData() {
  const [searchTerm, setSearchTerm] = useState('');
  const [searchResults, setSearchResults] = useState([]);
  const [selectedStock, setSelectedStock] = useState(null);
  const [quote, setQuote] = useState(null);
  const [intradayData, setIntradayData] = useState(null);
  const [marketStatus, setMarketStatus] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    loadMarketStatus();
  }, []);

  const loadMarketStatus = async () => {
    try {
      const status = await getMarketStatus();
      setMarketStatus(status);
    } catch (error) {
      console.error('Error loading market status:', error);
    }
  };

  const handleSearch = async (e) => {
    e.preventDefault();
    if (!searchTerm.trim()) return;

    setLoading(true);
    setError('');

    try {
      const results = await searchSymbols(searchTerm);
      setSearchResults(results.results || []);
    } catch (err) {
      setError(err.response?.data?.error || 'Search failed');
    } finally {
      setLoading(false);
    }
  };

  const handleSelectStock = async (symbol) => {
    setSelectedStock(symbol);
    setLoading(true);
    setError('');

    try {
      const [quoteRes, intradayRes] = await Promise.allSettled([
        getQuote(symbol),
        getIntradayData(symbol, '5min'),
      ]);

      if (quoteRes.status === 'fulfilled') {
        setQuote(quoteRes.value);
      }

      if (intradayRes.status === 'fulfilled') {
        setIntradayData(intradayRes.value);
      }
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to load stock data');
    } finally {
      setLoading(false);
    }
  };

  const popularStocks = ['AAPL', 'MSFT', 'GOOGL', 'AMZN', 'TSLA', 'NVDA', 'META', 'NFLX'];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex justify-between items-center">
        <h2 className="text-2xl font-bold text-gray-900">Market Data</h2>
        {marketStatus && (
          <div className="flex items-center space-x-2">
            <div className={`w-3 h-3 rounded-full ${
              marketStatus.isOpen ? 'bg-green-500' : 'bg-red-500'
            }`}></div>
            <span className="text-sm text-gray-600">
              Market {marketStatus.isOpen ? 'Open' : 'Closed'}
            </span>
            <span className="text-xs text-gray-500">
              ({marketStatus.currentTime})
            </span>
          </div>
        )}
      </div>

      {/* Search */}
      <div className="bg-white shadow rounded-lg p-6">
        <h3 className="text-lg font-medium text-gray-900 mb-4">Search Stocks</h3>
        
        <form onSubmit={handleSearch} className="flex space-x-4 mb-4">
          <input
            type="text"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            placeholder="Search by symbol or company name..."
            className="flex-1 border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-blue-500 focus:border-blue-500"
          />
          <button
            type="submit"
            disabled={loading}
            className="bg-blue-600 text-white px-6 py-2 rounded-md hover:bg-blue-700 disabled:opacity-50"
          >
            {loading ? (
              <i className="fas fa-spinner fa-spin"></i>
            ) : (
              <i className="fas fa-search"></i>
            )}
          </button>
        </form>

        {/* Popular Stocks */}
        <div className="mb-4">
          <p className="text-sm text-gray-600 mb-2">Popular stocks:</p>
          <div className="flex flex-wrap gap-2">
            {popularStocks.map((symbol) => (
              <button
                key={symbol}
                onClick={() => handleSelectStock(symbol)}
                className="px-3 py-1 text-sm bg-gray-100 text-gray-700 rounded-full hover:bg-gray-200"
              >
                {symbol}
              </button>
            ))}
          </div>
        </div>

        {/* Search Results */}
        {searchResults.length > 0 && (
          <div className="border border-gray-200 rounded-md max-h-60 overflow-y-auto">
            {searchResults.map((result, index) => (
              <button
                key={index}
                onClick={() => handleSelectStock(result.symbol)}
                className="w-full text-left px-4 py-3 hover:bg-gray-50 border-b border-gray-100 last:border-b-0"
              >
                <div className="flex justify-between items-center">
                  <div>
                    <div className="font-medium text-gray-900">{result.symbol}</div>
                    <div className="text-sm text-gray-600 truncate">{result.name}</div>
                  </div>
                  <div className="text-right">
                    <div className="text-sm text-gray-500">{result.type}</div>
                    <div className="text-xs text-gray-400">{result.region}</div>
                  </div>
                </div>
              </button>
            ))}
          </div>
        )}
      </div>

      {error && (
        <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-md">
          <div className="flex">
            <i className="fas fa-exclamation-circle mr-2 mt-0.5"></i>
            <span>{error}</span>
          </div>
        </div>
      )}

      {/* Stock Quote */}
      {quote && (
        <div className="bg-white shadow rounded-lg p-6">
          <div className="flex justify-between items-start mb-6">
            <div>
              <h3 className="text-2xl font-bold text-gray-900">{quote.symbol}</h3>
              <p className="text-sm text-gray-600">Last updated: {new Date(quote.lastUpdated).toLocaleDateString()}</p>
            </div>
            <div className="text-right">
              <div className="text-3xl font-bold text-gray-900">
                ${quote.price.toFixed(2)}
              </div>
              <div className={`text-lg ${quote.change >= 0 ? 'text-green-600' : 'text-red-600'}`}>
                {quote.change >= 0 ? '+' : ''}${quote.change.toFixed(2)} ({quote.changePercent})
              </div>
            </div>
          </div>

          <div className="grid grid-cols-2 md:grid-cols-4 gap-6">
            <div>
              <div className="text-sm text-gray-600">Open</div>
              <div className="text-lg font-medium text-gray-900">${quote.open.toFixed(2)}</div>
            </div>
            <div>
              <div className="text-sm text-gray-600">High</div>
              <div className="text-lg font-medium text-gray-900">${quote.high.toFixed(2)}</div>
            </div>
            <div>
              <div className="text-sm text-gray-600">Low</div>
              <div className="text-lg font-medium text-gray-900">${quote.low.toFixed(2)}</div>
            </div>
            <div>
              <div className="text-sm text-gray-600">Volume</div>
              <div className="text-lg font-medium text-gray-900">{quote.volume.toLocaleString()}</div>
            </div>
          </div>

          {quote.cached && (
            <div className="mt-4 text-xs text-gray-500 flex items-center">
              <i className="fas fa-clock mr-1"></i>
              Data cached for faster loading
            </div>
          )}
        </div>
      )}

      {/* Intraday Chart */}
      {intradayData && intradayData.data && intradayData.data.length > 0 && (
        <div className="bg-white shadow rounded-lg p-6">
          <h3 className="text-lg font-medium text-gray-900 mb-4">
            Intraday Chart ({intradayData.interval})
          </h3>
          
          {/* Simple ASCII-style chart */}
          <div className="overflow-x-auto">
            <div className="min-w-full">
              <div className="text-xs text-gray-600 mb-2">
                Price Range: ${Math.min(...intradayData.data.map(d => d.low)).toFixed(2)} - 
                ${Math.max(...intradayData.data.map(d => d.high)).toFixed(2)}
              </div>
              
              {/* Data points table */}
              <div className="max-h-64 overflow-y-auto">
                <table className="min-w-full text-xs">
                  <thead className="bg-gray-50 sticky top-0">
                    <tr>
                      <th className="px-2 py-1 text-left">Time</th>
                      <th className="px-2 py-1 text-left">Open</th>
                      <th className="px-2 py-1 text-left">High</th>
                      <th className="px-2 py-1 text-left">Low</th>
                      <th className="px-2 py-1 text-left">Close</th>
                      <th className="px-2 py-1 text-left">Volume</th>
                    </tr>
                  </thead>
                  <tbody>
                    {intradayData.data.slice(0, 20).map((point, index) => (
                      <tr key={index} className="border-b border-gray-100">
                        <td className="px-2 py-1">{new Date(point.time).toLocaleTimeString()}</td>
                        <td className="px-2 py-1">${point.open.toFixed(2)}</td>
                        <td className="px-2 py-1 text-green-600">${point.high.toFixed(2)}</td>
                        <td className="px-2 py-1 text-red-600">${point.low.toFixed(2)}</td>
                        <td className="px-2 py-1 font-medium">${point.close.toFixed(2)}</td>
                        <td className="px-2 py-1">{point.volume.toLocaleString()}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </div>

          {intradayData.cached && (
            <div className="mt-4 text-xs text-gray-500 flex items-center">
              <i className="fas fa-clock mr-1"></i>
              Intraday data cached for faster loading
            </div>
          )}
        </div>
      )}

      {/* Market Status Details */}
      {marketStatus && (
        <div className="bg-white shadow rounded-lg p-6">
          <h3 className="text-lg font-medium text-gray-900 mb-4">Market Information</h3>
          
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <div className="text-sm text-gray-600">Current Status</div>
              <div className={`text-lg font-medium ${
                marketStatus.isOpen ? 'text-green-600' : 'text-red-600'
              }`}>
                {marketStatus.isOpen ? 'Market Open' : 'Market Closed'}
              </div>
            </div>
            
            <div>
              <div className="text-sm text-gray-600">Timezone</div>
              <div className="text-lg font-medium text-gray-900">{marketStatus.timezone}</div>
            </div>
            
            <div>
              <div className="text-sm text-gray-600">Market Hours</div>
              <div className="text-lg font-medium text-gray-900">
                {marketStatus.marketOpen} - {marketStatus.marketClose}
              </div>
            </div>
            
            <div>
              <div className="text-sm text-gray-600">
                {marketStatus.isOpen ? 'Next Close' : 'Next Open'}
              </div>
              <div className="text-lg font-medium text-gray-900">
                {marketStatus.isOpen ? marketStatus.nextClose : marketStatus.nextOpen}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* No Data State */}
      {!selectedStock && (
        <div className="text-center py-12">
          <i className="fas fa-chart-bar text-gray-400 text-6xl mb-4"></i>
          <h3 className="text-lg font-medium text-gray-900 mb-2">Search for Stock Data</h3>
          <p className="text-gray-500 mb-4">
            Enter a stock symbol or company name to view real-time market data.
          </p>
          <div className="text-sm text-gray-400">
            Try searching for popular stocks like AAPL, MSFT, or GOOGL
          </div>
        </div>
      )}
    </div>
  );
}

export default MarketData;