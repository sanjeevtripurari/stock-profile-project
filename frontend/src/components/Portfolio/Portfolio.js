import React, { useState, useEffect } from 'react';
import { getTickers, addTicker, deleteTicker, getBudget, setBudget, buyShares, sellShares } from '../../services/api';

// Helper functions for safe number formatting
const safeNumber = (value, defaultValue = 0) => {
  const num = parseFloat(value);
  return isNaN(num) ? defaultValue : num;
};

const formatCurrency = (value) => safeNumber(value).toFixed(2);
const formatNumber = (value) => safeNumber(value).toLocaleString();

function Portfolio({ tickers: initialTickers, budget: initialBudget, onRefresh }) {
  const [tickers, setTickers] = useState(initialTickers || []);
  const [budget, setBudgetState] = useState(initialBudget);
  const [loading, setLoading] = useState(false);
  const [showAddForm, setShowAddForm] = useState(false);
  const [showBudgetForm, setShowBudgetForm] = useState(false);
  const [showBuyForm, setShowBuyForm] = useState(false);
  const [showSellForm, setShowSellForm] = useState(false);
  const [selectedTicker, setSelectedTicker] = useState(null);
  const [error, setError] = useState('');

  const [newTicker, setNewTicker] = useState({
    symbol: '',
    shares: '',
    purchasePrice: '',
  });

  const [newBudget, setNewBudget] = useState('');
  
  const [tradeForm, setTradeForm] = useState({
    shares: '',
    price: '',
  });

  useEffect(() => {
    if (initialTickers) {
      setTickers(initialTickers);
    }
    if (initialBudget) {
      setBudgetState(initialBudget);
    }
  }, [initialTickers, initialBudget]);

  const handleAddTicker = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const response = await addTicker(
        newTicker.symbol.toUpperCase(),
        parseFloat(newTicker.shares) || 0,
        parseFloat(newTicker.purchasePrice) || 0
      );
      
      setNewTicker({ symbol: '', shares: '', purchasePrice: '' });
      setShowAddForm(false);
      
      // Show success message with market price if used
      if (response.marketPrice && !newTicker.purchasePrice) {
        alert(`Stock added successfully! Used current market price: $${response.marketPrice.toFixed(2)}`);
      }
      
      onRefresh();
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to add ticker');
    } finally {
      setLoading(false);
    }
  };

  const handleDeleteTicker = async (symbol) => {
    if (!window.confirm(`Are you sure you want to remove ${symbol} from your portfolio?`)) {
      return;
    }

    setLoading(true);
    try {
      await deleteTicker(symbol);
      onRefresh();
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to remove ticker');
    } finally {
      setLoading(false);
    }
  };

  const handleSetBudget = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      await setBudget(parseFloat(newBudget));
      setNewBudget('');
      setShowBudgetForm(false);
      onRefresh();
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to set budget');
    } finally {
      setLoading(false);
    }
  };

  const handleBuyShares = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const response = await buyShares(
        selectedTicker.symbol,
        parseFloat(tradeForm.shares),
        parseFloat(tradeForm.price) || undefined
      );
      
      setTradeForm({ shares: '', price: '' });
      setShowBuyForm(false);
      setSelectedTicker(null);
      
      if (response.transaction) {
        alert(`Successfully bought ${response.transaction.shares} shares at $${response.transaction.price.toFixed(2)} each. Total: $${response.transaction.total.toFixed(2)}`);
      }
      
      onRefresh();
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to buy shares');
    } finally {
      setLoading(false);
    }
  };

  const handleSellShares = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const response = await sellShares(
        selectedTicker.symbol,
        parseFloat(tradeForm.shares),
        parseFloat(tradeForm.price) || undefined
      );
      
      setTradeForm({ shares: '', price: '' });
      setShowSellForm(false);
      setSelectedTicker(null);
      
      if (response.transaction) {
        const gainLossText = response.transaction.gainLoss >= 0 
          ? `Gain: $${response.transaction.gainLoss.toFixed(2)}` 
          : `Loss: $${Math.abs(response.transaction.gainLoss).toFixed(2)}`;
        alert(`Successfully sold ${response.transaction.shares} shares at $${response.transaction.price.toFixed(2)} each. ${gainLossText}`);
      }
      
      onRefresh();
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to sell shares');
    } finally {
      setLoading(false);
    }
  };

  const totalInvested = tickers.reduce((sum, ticker) => 
    sum + (ticker.shares * ticker.purchase_price), 0
  );

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex justify-between items-center">
        <h2 className="text-2xl font-bold text-gray-900">Portfolio Management</h2>
        <div className="flex space-x-3">
          <button
            onClick={() => setShowBudgetForm(true)}
            className="bg-green-600 text-white px-4 py-2 rounded-md hover:bg-green-700 text-sm"
          >
            <i className="fas fa-dollar-sign mr-2"></i>
            Set Budget
          </button>
          <button
            onClick={() => setShowAddForm(true)}
            className="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 text-sm"
          >
            <i className="fas fa-plus mr-2"></i>
            Add Stock
          </button>
        </div>
      </div>

      {error && (
        <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-md">
          <div className="flex">
            <i className="fas fa-exclamation-circle mr-2 mt-0.5"></i>
            <span>{error}</span>
          </div>
        </div>
      )}

      {/* Budget Overview */}
      {budget && (
        <div className="bg-white shadow rounded-lg p-6">
          <h3 className="text-lg font-medium text-gray-900 mb-4">Budget Overview</h3>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div className="text-center">
              <div className="text-2xl font-bold text-blue-600">
                ${budget.total_budget?.toLocaleString('en-US', { minimumFractionDigits: 2 })}
              </div>
              <div className="text-sm text-gray-600">Total Budget</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-orange-600">
                ${budget.allocated?.toLocaleString('en-US', { minimumFractionDigits: 2 })}
              </div>
              <div className="text-sm text-gray-600">Allocated</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-green-600">
                ${budget.available?.toLocaleString('en-US', { minimumFractionDigits: 2 })}
              </div>
              <div className="text-sm text-gray-600">Available</div>
            </div>
          </div>
          
          {/* Progress Bar */}
          <div className="mt-6">
            <div className="flex justify-between text-sm text-gray-600 mb-2">
              <span>Budget Utilization</span>
              <span>{budget.total_budget > 0 ? ((budget.allocated / budget.total_budget) * 100).toFixed(1) : 0}%</span>
            </div>
            <div className="w-full bg-gray-200 rounded-full h-3">
              <div 
                className="bg-blue-600 h-3 rounded-full transition-all duration-300" 
                style={{ 
                  width: budget.total_budget > 0 ? `${Math.min((budget.allocated / budget.total_budget) * 100, 100)}%` : '0%' 
                }}
              ></div>
            </div>
          </div>
        </div>
      )}

      {/* Holdings Table */}
      <div className="bg-white shadow rounded-lg overflow-hidden">
        <div className="px-6 py-4 border-b border-gray-200">
          <h3 className="text-lg font-medium text-gray-900">Your Holdings</h3>
        </div>
        
        {tickers.length > 0 ? (
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Symbol
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Shares
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Purchase Price
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Total Value
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Allocation %
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {tickers.map((ticker) => {
                  const shares = safeNumber(ticker.shares);
                  const price = safeNumber(ticker.purchase_price);
                  const totalValue = shares * price;
                  const allocation = totalInvested > 0 ? (totalValue / totalInvested) * 100 : 0;
                  
                  return (
                    <tr key={ticker.id} className="hover:bg-gray-50">
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="font-medium text-gray-900">{ticker.symbol}</div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-gray-900">
                        {formatNumber(shares)}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-gray-900">
                        ${formatCurrency(price)}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-gray-900">
                        ${totalValue.toLocaleString('en-US', { minimumFractionDigits: 2 })}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="flex items-center">
                          <div className="w-16 bg-gray-200 rounded-full h-2 mr-2">
                            <div 
                              className="bg-blue-600 h-2 rounded-full" 
                              style={{ width: `${Math.min(allocation, 100)}%` }}
                            ></div>
                          </div>
                          <span className="text-sm text-gray-600">{allocation.toFixed(1)}%</span>
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                        <div className="flex space-x-2">
                          <button
                            onClick={() => {
                              setSelectedTicker(ticker);
                              setShowBuyForm(true);
                            }}
                            className="text-green-600 hover:text-green-900 px-2 py-1 border border-green-600 rounded text-xs"
                            disabled={loading}
                            title="Buy more shares"
                          >
                            Buy
                          </button>
                          <button
                            onClick={() => {
                              setSelectedTicker(ticker);
                              setShowSellForm(true);
                            }}
                            className="text-blue-600 hover:text-blue-900 px-2 py-1 border border-blue-600 rounded text-xs"
                            disabled={loading}
                            title="Sell shares"
                          >
                            Sell
                          </button>
                          <button
                            onClick={() => handleDeleteTicker(ticker.symbol)}
                            className="text-red-600 hover:text-red-900 px-2 py-1 border border-red-600 rounded text-xs"
                            disabled={loading}
                            title="Remove from portfolio"
                          >
                            Delete
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                }).filter(row => row !== null)}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="text-center py-12">
            <i className="fas fa-chart-pie text-gray-400 text-6xl mb-4"></i>
            <h3 className="text-lg font-medium text-gray-900 mb-2">No holdings yet</h3>
            <p className="text-gray-500 mb-4">Start building your portfolio by adding your first stock.</p>
            <button
              onClick={() => setShowAddForm(true)}
              className="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700"
            >
              <i className="fas fa-plus mr-2"></i>
              Add Your First Stock
            </button>
          </div>
        )}
      </div>

      {/* Add Ticker Modal */}
      {showAddForm && (
        <div className="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
          <div className="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
            <div className="mt-3">
              <h3 className="text-lg font-medium text-gray-900 mb-4">Add New Stock</h3>
              <form onSubmit={handleAddTicker} className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700">Stock Symbol</label>
                  <input
                    type="text"
                    value={newTicker.symbol}
                    onChange={(e) => setNewTicker({ ...newTicker, symbol: e.target.value })}
                    className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                    placeholder="e.g., AAPL"
                    required
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700">Number of Shares</label>
                  <input
                    type="number"
                    step="0.01"
                    value={newTicker.shares}
                    onChange={(e) => setNewTicker({ ...newTicker, shares: e.target.value })}
                    className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                    placeholder="0"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700">Purchase Price (optional)</label>
                  <input
                    type="number"
                    step="0.01"
                    value={newTicker.purchasePrice}
                    onChange={(e) => setNewTicker({ ...newTicker, purchasePrice: e.target.value })}
                    className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                    placeholder="Leave empty for current market price"
                  />
                  <p className="mt-1 text-sm text-gray-500">
                    Leave empty to automatically use current market price
                  </p>
                </div>
                <div className="flex justify-end space-x-3 pt-4">
                  <button
                    type="button"
                    onClick={() => setShowAddForm(false)}
                    className="px-4 py-2 text-sm font-medium text-gray-700 bg-gray-200 rounded-md hover:bg-gray-300"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={loading}
                    className="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-md hover:bg-blue-700 disabled:opacity-50"
                  >
                    {loading ? 'Adding...' : 'Add Stock'}
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      )}

      {/* Set Budget Modal */}
      {showBudgetForm && (
        <div className="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
          <div className="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
            <div className="mt-3">
              <h3 className="text-lg font-medium text-gray-900 mb-4">Set Investment Budget</h3>
              <form onSubmit={handleSetBudget} className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700">Total Budget ($)</label>
                  <input
                    type="number"
                    step="0.01"
                    value={newBudget}
                    onChange={(e) => setNewBudget(e.target.value)}
                    className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-green-500 focus:border-green-500"
                    placeholder="10000.00"
                    required
                  />
                  <p className="mt-1 text-sm text-gray-500">
                    Set your total investment budget to track allocation
                  </p>
                </div>
                <div className="flex justify-end space-x-3 pt-4">
                  <button
                    type="button"
                    onClick={() => setShowBudgetForm(false)}
                    className="px-4 py-2 text-sm font-medium text-gray-700 bg-gray-200 rounded-md hover:bg-gray-300"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={loading}
                    className="px-4 py-2 text-sm font-medium text-white bg-green-600 rounded-md hover:bg-green-700 disabled:opacity-50"
                  >
                    {loading ? 'Setting...' : 'Set Budget'}
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      )}

      {/* Buy Shares Modal */}
      {showBuyForm && selectedTicker && (
        <div className="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
          <div className="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
            <div className="mt-3">
              <h3 className="text-lg font-medium text-gray-900 mb-4">Buy More Shares - {selectedTicker.symbol}</h3>
              <form onSubmit={handleBuyShares} className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700">Number of Shares</label>
                  <input
                    type="number"
                    step="0.01"
                    value={tradeForm.shares}
                    onChange={(e) => setTradeForm({ ...tradeForm, shares: e.target.value })}
                    className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-green-500 focus:border-green-500"
                    placeholder="10"
                    required
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700">Price per Share (optional)</label>
                  <input
                    type="number"
                    step="0.01"
                    value={tradeForm.price}
                    onChange={(e) => setTradeForm({ ...tradeForm, price: e.target.value })}
                    className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-green-500 focus:border-green-500"
                    placeholder="Leave empty for current market price"
                  />
                  <p className="mt-1 text-sm text-gray-500">
                    Leave empty to use current market price
                  </p>
                </div>
                <div className="flex justify-end space-x-3 pt-4">
                  <button
                    type="button"
                    onClick={() => {
                      setShowBuyForm(false);
                      setSelectedTicker(null);
                      setTradeForm({ shares: '', price: '' });
                    }}
                    className="px-4 py-2 text-sm font-medium text-gray-700 bg-gray-200 rounded-md hover:bg-gray-300"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={loading}
                    className="px-4 py-2 text-sm font-medium text-white bg-green-600 rounded-md hover:bg-green-700 disabled:opacity-50"
                  >
                    {loading ? 'Buying...' : 'Buy Shares'}
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      )}

      {/* Sell Shares Modal */}
      {showSellForm && selectedTicker && (
        <div className="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
          <div className="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
            <div className="mt-3">
              <h3 className="text-lg font-medium text-gray-900 mb-4">Sell Shares - {selectedTicker.symbol}</h3>
              <p className="text-sm text-gray-600 mb-4">
                You own {selectedTicker.shares} shares at ${selectedTicker.purchase_price} each
              </p>
              <form onSubmit={handleSellShares} className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700">Number of Shares to Sell</label>
                  <input
                    type="number"
                    step="0.01"
                    max={selectedTicker.shares}
                    value={tradeForm.shares}
                    onChange={(e) => setTradeForm({ ...tradeForm, shares: e.target.value })}
                    className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                    placeholder={`Max: ${selectedTicker.shares}`}
                    required
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700">Sell Price per Share (optional)</label>
                  <input
                    type="number"
                    step="0.01"
                    value={tradeForm.price}
                    onChange={(e) => setTradeForm({ ...tradeForm, price: e.target.value })}
                    className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                    placeholder="Leave empty for current market price"
                  />
                  <p className="mt-1 text-sm text-gray-500">
                    Leave empty to use current market price
                  </p>
                </div>
                <div className="flex justify-end space-x-3 pt-4">
                  <button
                    type="button"
                    onClick={() => {
                      setShowSellForm(false);
                      setSelectedTicker(null);
                      setTradeForm({ shares: '', price: '' });
                    }}
                    className="px-4 py-2 text-sm font-medium text-gray-700 bg-gray-200 rounded-md hover:bg-gray-300"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={loading}
                    className="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-md hover:bg-blue-700 disabled:opacity-50"
                  >
                    {loading ? 'Selling...' : 'Sell Shares'}
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default Portfolio;