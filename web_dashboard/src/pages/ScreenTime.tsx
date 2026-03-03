import { useQuery } from '@tanstack/react-query'
import { getScreenTimeDaily, getScreenTimeTrends } from '../api'
import {
  BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid, LineChart, Line,
} from 'recharts'
import { format, subDays } from 'date-fns'

const today = format(new Date(), 'yyyy-MM-dd')
const start14 = format(subDays(new Date(), 14), 'yyyy-MM-dd')

const TOOLTIP_STYLE = {
  backgroundColor: '#1a1d27',
  border: '1px solid #2a2d3a',
  borderRadius: '8px',
  color: '#fff',
}

function formatMinutes(seconds: number) {
  const h = Math.floor(seconds / 3600)
  const m = Math.floor((seconds % 3600) / 60)
  if (h > 0) return `${h}h ${m}m`
  return `${m}m`
}

export default function ScreenTime() {
  const { data: daily } = useQuery({
    queryKey: ['screen-time-daily', today],
    queryFn: () => getScreenTimeDaily(today),
  })

  const { data: trends = [] } = useQuery({
    queryKey: ['screen-time-trends', start14],
    queryFn: () => getScreenTimeTrends({ start: start14, end: today }),
  })

  const apps = daily?.apps || []
  const totalHours = daily?.total_hours || 0

  const trendChart = trends.map((t: any) => ({
    date: format(new Date(t.date + 'T12:00:00'), 'EEE d'),
    hours: t.total_hours,
  }))

  const avgHours = trendChart.length
    ? (trendChart.reduce((a: number, b: any) => a + b.hours, 0) / trendChart.length).toFixed(1)
    : '—'

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Screen Time</h1>
        <p className="text-gray-400 text-sm">Today · Data collected by the Android app</p>
      </div>

      <div className="grid grid-cols-2 gap-3">
        <div className="card text-center">
          <p className="text-3xl font-bold">{totalHours}h</p>
          <p className="text-xs text-gray-400 mt-1">Total Today</p>
        </div>
        <div className="card text-center">
          <p className="text-3xl font-bold">{avgHours}h</p>
          <p className="text-xs text-gray-400 mt-1">14-Day Average</p>
        </div>
      </div>

      <div className="card">
        <h3 className="font-semibold text-sm mb-4 text-gray-300">Trend — Last 14 Days</h3>
        {trendChart.length > 0 ? (
          <ResponsiveContainer width="100%" height={180}>
            <LineChart data={trendChart}>
              <CartesianGrid strokeDasharray="3 3" stroke="#2a2d3a" vertical={false} />
              <XAxis dataKey="date" tick={{ fill: '#6b7280', fontSize: 10 }} axisLine={false} tickLine={false} />
              <YAxis tick={{ fill: '#6b7280', fontSize: 11 }} axisLine={false} tickLine={false} unit="h" />
              <Tooltip contentStyle={TOOLTIP_STYLE} formatter={(v: any) => [`${v}h`, 'Screen time']} />
              <Line type="monotone" dataKey="hours" stroke="#4f6ef7" strokeWidth={2} dot={{ fill: '#4f6ef7', r: 3 }} />
            </LineChart>
          </ResponsiveContainer>
        ) : (
          <div className="h-40 flex items-center justify-center text-gray-500 text-sm">
            No screen time data yet.<br />Install and configure the Android app.
          </div>
        )}
      </div>

      <div className="card">
        <h3 className="font-semibold text-sm mb-4 text-gray-300">Today by App</h3>
        {apps.length > 0 ? (
          <div className="space-y-3">
            {apps.map((app: any, i: number) => (
              <div key={app.package} className="flex items-center gap-3">
                <div className="w-6 text-center text-xs text-gray-500">{i + 1}</div>
                <div className="flex-1">
                  <div className="flex items-center justify-between mb-1">
                    <span className="text-sm text-white">{app.name}</span>
                    <span className="text-xs text-gray-400">{formatMinutes(app.duration_seconds)}</span>
                  </div>
                  <div className="h-1.5 bg-border rounded-full overflow-hidden">
                    <div
                      className="h-full bg-primary-500 rounded-full"
                      style={{ width: `${(app.duration_seconds / (daily.total_seconds || 1)) * 100}%` }}
                    />
                  </div>
                </div>
                {app.category && (
                  <span className="badge bg-gray-500/20 text-gray-400 text-xs">{app.category}</span>
                )}
              </div>
            ))}
          </div>
        ) : (
          <p className="text-gray-500 text-sm text-center py-6">No app usage data for today yet.</p>
        )}
      </div>
    </div>
  )
}
