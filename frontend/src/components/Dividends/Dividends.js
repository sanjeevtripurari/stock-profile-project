import React, { useState, useEffect } from 'react';
import { getDividendProjection, getDividendTickers, getDividendCalendar } from '../../services/api';

function Dividends({ projection: initialProjection, onRefresh }) {
  const [projection, setProjection] = useState(initialProjection);
  const [dividendTickers, setDividendTickers] = useState([]);
  const [calendar, setCalendar] = useState([]);
  const [loading, setLoading] = useState(false);
  const [activeTab, setActiveTab] = useState('projection');

  useEffect(() => {
    setProjection(initialProjection);
    loadDividendData();
  }, [initialProjection]);

  const loadDividendData = async () => {
    setLoading(true);
    try {
      const [tickersRes, calendarRes] = await Promise.allSettled([
        getDividendTickers(),
        getDividendCalendar(90), // Next 90 days
      ]);

      if (tickersRes.status === 'fulfilled') {
        setDividendTickers(tickersRes.value.tickers || []);
      }

      if (calendarRes.status === 'fulfilled') {
        setCalendar(calendarRes.value.calendar || []);
      }
    } catch (error) {
      console.error('Error loading dividend data:', error);
    } finally {
      setLoading(false);
    }
  };

  if (!projection) {
    return (
      <div className="text-center py-12">
        <i className="fas fa-coins text-gray-400 text-6xl mb-4"></i>
        <h3 className="text-lg font-medium text-gray-900 mb-2">No dividend data available</h3>
        <p className="text-gray-500">Add some dividend-paying stocks to see projections.</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex justify-between items-center">
        <h2 className="text-2xl font-bold text-gray-900">Dividend Analysis</h2>
        <button
          onClick={onRefresh}
          className="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 text-sm"
          disabled={loading}
        >
          <i className={`fas ${loading ? 'fa-spinner fa-spin' : 'fa-sync-alt'} mr-2`}></i>
          Refresh
        </button>
      </div>

      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
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
                    ${projection.totalAnnualDividend?.toLocaleString('en-US', { minimumFractionDigits: 2 })}
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
                <i className="fas fa-calendar-alt text-blue-600 text-2xl"></i>
              </div>
              <div className="ml-5 w-0 flex-1">
                <dl>
                  <dt className="text-sm font-medium text-gray-500 truncate">
                    Monthly Average
                  </dt>
                  <dd className="text-lg font-medium text-gray-900">
                    ${projection.monthlyAverage?.toLocaleString('en-US', { minimumFractionDigits: 2 })}
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
                    Average Yield
                  </dt>
                  <dd className="text-lg font-medium text-gray-900">
                    {projection.averageYield?.toFixed(2)}%
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
                <i className="fas fa-chart-pie text-indigo-600 text-2xl"></i>
              </div>
              <div className="ml-5 w-0 flex-1">
                <dl>
                  <dt className="text-sm font-medium text-gray-500 truncate">
                    Dividend Stocks
                  </dt>
                  <dd className="text-lg font-medium text-gray-900">
                    {projection.summary?.dividendPayingStocks || 0}
                  </dd>
                </dl>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Tabs */}
      <div className="border-b border-gray-200">
        <nav className="-mb-px flex space-x-8">
          {[
            { id: 'projection', name: 'Projections', icon: 'fas fa-chart-line' },
            { id: 'quarterly', name: 'Quarterly', icon: 'fas fa-calendar-check' },
            { id: 'calendar', name: 'Calendar', icon: 'fas fa-calendar-alt' },
          ].map((tab) => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`py-2 px-1 border-b-2 font-medium text-sm ${
                activeTab === tab.id
                  ? 'border-blue-500 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              }`}
            >
              <i className={`${tab.icon} mr-2`}></i>
              {tab.name}
            </button>
          ))}
        </nav>
      </div>

      {/* Tab Content */}
      {activeTab === 'projection' && (
        <div className="bg-white shadow rounded-lg overflow-hidden">
          <div className="px-6 py-4 border-b border-gray-200">
            <h3 className="text-lg font-medium text-gray-900">Dividend Projections by Stock</h3>
          </div>
          
          {projection.projections && projection.projections.length > 0 ? (
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Stock
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Shares
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Annual Dividend
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Yield
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Yield on Cost
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Current Value
                    </th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {projection.projections.map((stock) => (
                    <tr key={stock.symbol} className="hover:bg-gray-50">
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="font-medium text-gray-900">{stock.symbol}</div>
                        {stock.sector && (
                          <div className="text-sm text-gray-500">{stock.sector}</div>
                        )}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-gray-900">
                        {stock.shares?.toLocaleString()}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="text-gray-900 font-medium">
                          ${stock.annualDividend?.toLocaleString('en-US', { minimumFractionDigits: 2 })}
                        </div>
                        <div className="text-sm text-gray-500">
                          ${(stock.annualDividend / 4)?.toFixed(2)} quarterly
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${
                          stock.dividendYield > 4 
                            ? 'bg-green-100 text-green-800'
                            : stock.dividendYield > 2
                            ? 'bg-yellow-100 text-yellow-800'
                            : 'bg-red-100 text-red-800'
                        }`}>
                          {stock.dividendYield?.toFixed(2)}%
                        </span>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${
                          stock.yieldOnCost > 4 
                            ? 'bg-green-100 text-green-800'
                            : stock.yieldOnCost > 2
                            ? 'bg-yellow-100 text-yellow-800'
                            : 'bg-red-100 text-red-800'
                        }`}>
                          {stock.yieldOnCost?.toFixed(2)}%
                        </span>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="text-gray-900">
                          ${stock.currentValue?.toLocaleString('en-US', { minimumFractionDigits: 2 })}
                        </div>
                        <div className={`text-sm ${stock.gain >= 0 ? 'text-green-600' : 'text-red-600'}`}>
                          {stock.gain >= 0 ? '+' : ''}${stock.gain?.toFixed(2)} ({stock.gainPercent?.toFixed(1)}%)
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <div className="text-center py-12">
              <i className="fas fa-coins text-gray-400 text-4xl mb-4"></i>
              <p className="text-gray-500">No dividend-paying stocks in your portfolio.</p>
            </div>
          )}
        </div>
      )}

      {activeTab === 'quarterly' && (
        <div className="bg-white shadow rounded-lg p-6">
          <h3 className="text-lg font-medium text-gray-900 mb-6">Quarterly Dividend Projections</h3>
          
          {projection.quarterlyProjections && projection.quarterlyProjections.length > 0 ? (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
              {projection.quarterlyProjections.map((quarter) => (
                <div key={quarter.quarter} className="text-center p-4 border border-gray-200 rounded-lg">
                  <div className="text-2xl font-bold text-blue-600 mb-2">
                    ${quarter.total?.toLocaleString('en-US', { minimumFractionDigits: 2 })}
                  </div>
                  <div className="text-sm text-gray-600">{quarter.quarter}</div>
                  <div className="mt-2 text-xs text-gray-500">
                    Estimated quarterly income
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="text-center py-8">
              <p className="text-gray-500">No quarterly projections available.</p>
            </div>
          )}

          {/* Sector Breakdown */}
          {projection.sectorBreakdown && Object.keys(projection.sectorBreakdown).length > 0 && (
            <div className="mt-8">
              <h4 className="text-md font-medium text-gray-900 mb-4">Dividend Income by Sector</h4>
              <div className="space-y-3">
                {Object.entries(projection.sectorBreakdown).map(([sector, data]) => (
                  <div key={sector} className="flex items-center justify-between">
                    <div className="flex items-center">
                      <div className="w-32 text-sm text-gray-600">{sector}</div>
                      <div className="w-48 bg-gray-200 rounded-full h-2 ml-4">
                        <div 
                          className="bg-blue-600 h-2 rounded-full" 
                          style={{ width: `${data.percentage}%` }}
                        ></div>
                      </div>
                    </div>
                    <div className="text-sm text-gray-900 ml-4">
                      ${data.totalDividend?.toFixed(2)} ({data.percentage?.toFixed(1)}%)
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}

      {activeTab === 'calendar' && (
        <div className="bg-white shadow rounded-lg overflow-hidden">
          <div className="px-6 py-4 border-b border-gray-200">
            <h3 className="text-lg font-medium text-gray-900">Upcoming Dividend Payments (Next 90 Days)</h3>
          </div>
          
          {calendar.length > 0 ? (
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Stock
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Ex-Dividend Date
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Days Until
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Shares
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Est. Dividend
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Est. Income
                    </th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {calendar.map((item, index) => (
                    <tr key={index} className="hover:bg-gray-50">
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="font-medium text-gray-900">{item.symbol}</div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-gray-900">
                        {new Date(item.exDividendDate).toLocaleDateString()}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${
                          item.daysUntilExDate <= 7 
                            ? 'bg-red-100 text-red-800'
                            : item.daysUntilExDate <= 30
                            ? 'bg-yellow-100 text-yellow-800'
                            : 'bg-green-100 text-green-800'
                        }`}>
                          {item.daysUntilExDate} days
                        </span>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-gray-900">
                        {item.shares?.toLocaleString()}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-gray-900">
                        ${item.estimatedDividend?.toFixed(2)}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-gray-900 font-medium">
                        ${item.estimatedIncome?.toLocaleString('en-US', { minimumFractionDigits: 2 })}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <div className="text-center py-12">
              <i className="fas fa-calendar-times text-gray-400 text-4xl mb-4"></i>
              <p className="text-gray-500">No upcoming dividend payments in the next 90 days.</p>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

export default Dividends;