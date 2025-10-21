import React, { useState, useEffect } from 'react';
import { getUserFromToken } from '../../utils/auth';
import { logout, getTickers, getBudget, getDividendProjection, getMarketStatus } from '../../services/api';
import Portfolio from '../Portfolio/Portfolio';
import Dividends from '../Dividends/Dividends';
import MarketData from '../Market/MarketData';

function Dashboard({ onLogout }) {
  const [activeTab, setActiveTab] = useState('overview');
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [dashboardData, setDashboardData] = useState({
    tickers: [],
    budget: null,
    dividendProjection: null,
    marketStatus: null,
  });

  useEffect(() => {
    const userData = getUserFromToken();
    setUser(userData);
    loadDashboardData();
  }, []);

  const loadDashboardData = async () => {
    try {
      setLoading(true);
      
      const [tickersRes, budgetRes, dividendRes, marketRes] = await Promise.allSettled([
        getTickers(),
        getBudget(),
        getDividendProjection(),
        getMarketStatus(),
      ]);

      const tickers = tickersRes.status === 'fulfilled' ? (tickersRes.value.tickers || []) : [];

      setDashboardData({
        tickers: tickers,
        budget: budgetRes.status === 'fulfilled' ? budgetRes.value.budget : null,
        dividendProjection: dividendRes.status === 'fulfilled' ? dividendRes.value : null,
        marketStatus: marketRes.status === 'fulfilled' ? marketRes.value : null,
      });
    } catch (error) {
      console.error('Error loading dashboard data:', error);
      // Set default empty data on error
      setDashboardData({
        tickers: [],
        budget: null,
        dividendProjection: null,
        marketStatus: null,
      });
    } finally {
      setLoading(false);
    }
  };

  const handleLogout = async () => {
    try {
      await logout();
    } catch (error) {
      console.error('Logout error:', error);
    }
    onLogout();
  };

  const refreshData = () => {
    loadDashboardData();
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading dashboard...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white shadow-sm border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center py-4">
            <div className="flex items-center">
              <div className="h-8 w-8 bg-blue-600 rounded-lg flex items-center justify-center mr-3">
                <i className="fas fa-chart-line text-white"></i>
              </div>
              <h1 className="text-xl font-semibold text-gray-900">
                Stock Portfolio Manager
              </h1>
            </div>
            
            <div className="flex items-center space-x-4">
              {dashboardData.marketStatus && (
                <div className="flex items-center text-sm">
                  <div className={`w-2 h-2 rounded-full mr-2 ${
                    dashboardData.marketStatus.isOpen ? 'bg-green-500' : 'bg-red-500'
                  }`}></div>
                  <span className="text-gray-600">
                    Market {dashboardData.marketStatus.isOpen ? 'Open' : 'Closed'}
                  </span>
                </div>
              )}
              
              <div className="flex items-center text-sm text-gray-600">
                <i className="fas fa-user-circle mr-2"></i>
                <span>{user?.name || user?.email}</span>
              </div>
              
              <button
                onClick={handleLogout}
                className="text-gray-500 hover:text-gray-700 text-sm"
              >
                <i className="fas fa-sign-out-alt mr-1"></i>
                Logout
              </button>
            </div>
          </div>
        </div>
      </header>

      {/* Navigation Tabs */}
      <nav className="bg-white border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex space-x-8">
            {[
              { id: 'overview', name: 'Overview', icon: 'fas fa-tachometer-alt' },
              { id: 'portfolio', name: 'Portfolio', icon: 'fas fa-briefcase' },
              { id: 'dividends', name: 'Dividends', icon: 'fas fa-coins' },
              { id: 'market', name: 'Market Data', icon: 'fas fa-chart-bar' },
            ].map((tab) => (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                className={`py-4 px-1 border-b-2 font-medium text-sm ${
                  activeTab === tab.id
                    ? 'border-blue-500 text-blue-600'
                    : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                }`}
              >
                <i className={`${tab.icon} mr-2`}></i>
                {tab.name}
              </button>
            ))}
          </div>
        </div>
      </nav>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
        {activeTab === 'overview' && (
          <OverviewTab 
            data={dashboardData} 
            onRefresh={refreshData}
          />
        )}
        
        {activeTab === 'portfolio' && (
          <Portfolio 
            tickers={dashboardData.tickers}
            budget={dashboardData.budget}
            onRefresh={refreshData}
          />
        )}
        
        {activeTab === 'dividends' && (
          <Dividends 
            projection={dashboardData.dividendProjection}
            onRefresh={refreshData}
          />
        )}
        
        {activeTab === 'market' && (
          <MarketData />
        )}
      </main>
    </div>
  );
}

// Overview Tab Component
function OverviewTab({ data, onRefresh }) {
  const { tickers, budget, dividendProjection, marketStatus } = data;

  const totalInvested = tickers.reduce((sum, ticker) => 
    sum + (ticker.shares * ticker.purchase_price), 0
  );

  const totalShares = tickers.reduce((sum, ticker) => sum + ticker.shares, 0);

  return (
    <div className="space-y-6">
      {/* Quick Stats */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <div className="bg-white overflow-hidden shadow rounded-lg">
          <div className="p-5">
            <div className="flex items-center">
              <div className="flex-shrink-0">
                <i className="fas fa-chart-pie text-blue-600 text-2xl"></i>
              </div>
              <div className="ml-5 w-0 flex-1">
                <dl>
                  <dt className="text-sm font-medium text-gray-500 truncate">
                    Total Invested
                  </dt>
                  <dd className="text-lg font-medium text-gray-900">
                    ${totalInvested.toLocaleString('en-US', { minimumFractionDigits: 2 })}
                  </dd>
                </dl>
              </div>
            </div>
          </div>
        </div>

        <div className="bg-white overflow-hidden shadow rounded-lg">
          <div className="p-5">
            <div className="flex items-center">
              <div className="flex-shrink-0">
                <i className="fas fa-coins text-green-600 text-2xl"></i>
              </div>
              <div className="ml-5 w-0 flex-1">
                <dl>
                  <dt className="text-sm font-medium text-gray-500 truncate">
                    Annual Dividends
                  </dt>
                  <dd className="text-lg font-medium text-gray-900">
                    ${(dividendProjection?.totalAnnualDividend || 0).toLocaleString('en-US', { minimumFractionDigits: 2 })}
                  </dd>
                </dl>
              </div>
            </div>
          </div>
        </div>

        <div className="bg-white overflow-hidden shadow rounded-lg">
          <div className="p-5">
            <div className="flex items-center">
              <div className="flex-shrink-0">
                <i className="fas fa-percentage text-purple-600 text-2xl"></i>
              </div>
              <div className="ml-5 w-0 flex-1">
                <dl>
                  <dt className="text-sm font-medium text-gray-500 truncate">
                    Avg Dividend Yield
                  </dt>
                  <dd className="text-lg font-medium text-gray-900">
                    {(dividendProjection?.averageYield || 0).toFixed(2)}%
                  </dd>
                </dl>
              </div>
            </div>
          </div>
        </div>

        <div className="bg-white overflow-hidden shadow rounded-lg">
          <div className="p-5">
            <div className="flex items-center">
              <div className="flex-shrink-0">
                <i className="fas fa-list text-indigo-600 text-2xl"></i>
              </div>
              <div className="ml-5 w-0 flex-1">
                <dl>
                  <dt className="text-sm font-medium text-gray-500 truncate">
                    Total Positions
                  </dt>
                  <dd className="text-lg font-medium text-gray-900">
                    {tickers.length}
                  </dd>
                </dl>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Budget Overview */}
      {budget && (
        <div className="bg-white shadow rounded-lg p-6">
          <h3 className="text-lg font-medium text-gray-900 mb-4">Budget Overview</h3>
          <div className="space-y-4">
            <div className="flex justify-between items-center">
              <span className="text-sm text-gray-600">Total Budget</span>
              <span className="font-medium">${budget.total_budget?.toLocaleString('en-US', { minimumFractionDigits: 2 })}</span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-sm text-gray-600">Allocated</span>
              <span className="font-medium">${budget.allocated?.toLocaleString('en-US', { minimumFractionDigits: 2 })}</span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-sm text-gray-600">Available</span>
              <span className="font-medium text-green-600">${budget.available?.toLocaleString('en-US', { minimumFractionDigits: 2 })}</span>
            </div>
            
            {/* Budget Progress Bar */}
            <div className="mt-4">
              <div className="flex justify-between text-sm text-gray-600 mb-1">
                <span>Budget Utilization</span>
                <span>{budget.total_budget > 0 ? ((budget.allocated / budget.total_budget) * 100).toFixed(1) : 0}%</span>
              </div>
              <div className="w-full bg-gray-200 rounded-full h-2">
                <div 
                  className="bg-blue-600 h-2 rounded-full" 
                  style={{ 
                    width: budget.total_budget > 0 ? `${Math.min((budget.allocated / budget.total_budget) * 100, 100)}%` : '0%' 
                  }}
                ></div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Recent Holdings */}
      <div className="bg-white shadow rounded-lg">
        <div className="px-6 py-4 border-b border-gray-200 flex justify-between items-center">
          <h3 className="text-lg font-medium text-gray-900">Recent Holdings</h3>
          <button
            onClick={onRefresh}
            className="text-blue-600 hover:text-blue-800 text-sm"
          >
            <i className="fas fa-sync-alt mr-1"></i>
            Refresh
          </button>
        </div>
        <div className="px-6 py-4">
          {tickers.length > 0 ? (
            <div className="space-y-3">
              {tickers.slice(0, 5).map((ticker) => (
                <div key={ticker.id} className="flex justify-between items-center">
                  <div>
                    <span className="font-medium text-gray-900">{ticker.symbol}</span>
                    <span className="text-sm text-gray-500 ml-2">
                      {ticker.shares} shares @ ${ticker.purchase_price}
                    </span>
                  </div>
                  <div className="text-right">
                    <div className="font-medium text-gray-900">
                      ${(ticker.shares * ticker.purchase_price).toLocaleString('en-US', { minimumFractionDigits: 2 })}
                    </div>
                  </div>
                </div>
              ))}
              {tickers.length > 5 && (
                <div className="text-center pt-2">
                  <span className="text-sm text-gray-500">
                    and {tickers.length - 5} more...
                  </span>
                </div>
              )}
            </div>
          ) : (
            <div className="text-center py-8">
              <i className="fas fa-chart-line text-gray-400 text-4xl mb-4"></i>
              <p className="text-gray-500">No holdings yet. Start by adding your first stock!</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

export default Dashboard;