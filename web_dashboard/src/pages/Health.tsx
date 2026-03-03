import { useQuery } from '@tanstack/react-query'
import { getSleepSessions, getHealthMetrics } from '../api'
import {
  BarChart, Bar, LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid,
} from 'recharts'
import { format, subDays } from 'date-fns'

const today = new Date()
const start7 = format(subDays(today, 7), 'yyyy-MM-dd')
const end = format(today, 'yyyy-MM-dd')

function ChartCard({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="card">
      <h3 className="font-semibold text-sm mb-4 text-gray-300">{title}</h3>
      {children}
    </div>
  )
}

const TOOLTIP_STYLE = {
  backgroundColor: '#1a1d27',
  border: '1px solid #2a2d3a',
  borderRadius: '8px',
  color: '#fff',
}

export default function Health() {
  const { data: sleepSessions = [] } = useQuery({
    queryKey: ['sleep', start7, end],
    queryFn: () => getSleepSessions({ start: start7, end }),
  })

  const { data: stepsData = [] } = useQuery({
    queryKey: ['metrics', 'steps', start7],
    queryFn: () => getHealthMetrics({ type: 'steps', start: start7, end }),
  })

  const { data: hrvData = [] } = useQuery({
    queryKey: ['metrics', 'hrv', start7],
    queryFn: () => getHealthMetrics({ type: 'heart_rate_variability_sdnn', start: start7, end }),
  })

  const { data: hrData = [] } = useQuery({
    queryKey: ['metrics', 'resting_hr', start7],
    queryFn: () => getHealthMetrics({ type: 'resting_heart_rate', start: start7, end }),
  })

  // Aggregate steps by day
  const stepsByDay: Record<string, number> = {}
  stepsData.forEach((m: any) => {
    stepsByDay[m.date] = (stepsByDay[m.date] || 0) + m.value
  })
  const stepsChart = Object.entries(stepsByDay).map(([date, steps]) => ({
    date: format(new Date(date + 'T12:00:00'), 'EEE'),
    steps: Math.round(steps),
  }))

  // Sleep chart
  const sleepChart = sleepSessions.map((s: any) => ({
    date: format(new Date(s.date + 'T12:00:00'), 'EEE'),
    total: +(s.total_duration || 0).toFixed(1),
    deep: +(s.deep_sleep || 0).toFixed(1),
    rem: +(s.rem_sleep || 0).toFixed(1),
    light: +(s.light_sleep || 0).toFixed(1),
  }))

  // HRV chart
  const hrvByDay: Record<string, number[]> = {}
  hrvData.forEach((m: any) => {
    if (!hrvByDay[m.date]) hrvByDay[m.date] = []
    hrvByDay[m.date].push(m.value)
  })
  const hrvChart = Object.entries(hrvByDay).map(([date, vals]) => ({
    date: format(new Date(date + 'T12:00:00'), 'EEE'),
    hrv: Math.round(vals.reduce((a, b) => a + b, 0) / vals.length),
  }))

  const avgSleep = sleepChart.length
    ? (sleepChart.reduce((a: number, b: { total: number }) => a + b.total, 0) / sleepChart.length).toFixed(1)
    : '—'

  const avgSteps = stepsChart.length
    ? Math.round(stepsChart.reduce((a, b) => a + b.steps, 0) / stepsChart.length).toLocaleString()
    : '—'

  const latestHrv = hrvChart.length ? hrvChart[hrvChart.length - 1].hrv : null

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Health</h1>
        <p className="text-gray-400 text-sm">Last 7 days · Data from Amazfit via Health Connect</p>
      </div>

      <div className="grid grid-cols-3 gap-3">
        <div className="card text-center">
          <p className="text-2xl font-bold">{avgSleep}h</p>
          <p className="text-xs text-gray-400 mt-1">Avg Sleep</p>
        </div>
        <div className="card text-center">
          <p className="text-2xl font-bold">{avgSteps}</p>
          <p className="text-xs text-gray-400 mt-1">Avg Steps/Day</p>
        </div>
        <div className="card text-center">
          <p className="text-2xl font-bold">{latestHrv ? `${latestHrv} ms` : '—'}</p>
          <p className="text-xs text-gray-400 mt-1">Latest HRV</p>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <ChartCard title="Sleep (hours)">
          {sleepChart.length > 0 ? (
            <ResponsiveContainer width="100%" height={180}>
              <BarChart data={sleepChart} barSize={20}>
                <CartesianGrid strokeDasharray="3 3" stroke="#2a2d3a" vertical={false} />
                <XAxis dataKey="date" tick={{ fill: '#6b7280', fontSize: 11 }} axisLine={false} tickLine={false} />
                <YAxis tick={{ fill: '#6b7280', fontSize: 11 }} axisLine={false} tickLine={false} domain={[0, 10]} />
                <Tooltip contentStyle={TOOLTIP_STYLE} />
                <Bar dataKey="deep" stackId="a" fill="#4f6ef7" name="Deep" />
                <Bar dataKey="rem" stackId="a" fill="#7c9df7" name="REM" />
                <Bar dataKey="light" stackId="a" fill="#2a3a6e" name="Light" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          ) : (
            <div className="h-40 flex items-center justify-center text-gray-500 text-sm">
              No sleep data yet.<br />Sync your Amazfit data.
            </div>
          )}
        </ChartCard>

        <ChartCard title="Daily Steps">
          {stepsChart.length > 0 ? (
            <ResponsiveContainer width="100%" height={180}>
              <BarChart data={stepsChart} barSize={20}>
                <CartesianGrid strokeDasharray="3 3" stroke="#2a2d3a" vertical={false} />
                <XAxis dataKey="date" tick={{ fill: '#6b7280', fontSize: 11 }} axisLine={false} tickLine={false} />
                <YAxis tick={{ fill: '#6b7280', fontSize: 11 }} axisLine={false} tickLine={false} />
                <Tooltip contentStyle={TOOLTIP_STYLE} formatter={(v: any) => [v.toLocaleString(), 'Steps']} />
                <Bar dataKey="steps" fill="#4f6ef7" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          ) : (
            <div className="h-40 flex items-center justify-center text-gray-500 text-sm">
              No step data yet.
            </div>
          )}
        </ChartCard>

        <ChartCard title="Heart Rate Variability (HRV) — ms">
          {hrvChart.length > 0 ? (
            <ResponsiveContainer width="100%" height={180}>
              <LineChart data={hrvChart}>
                <CartesianGrid strokeDasharray="3 3" stroke="#2a2d3a" vertical={false} />
                <XAxis dataKey="date" tick={{ fill: '#6b7280', fontSize: 11 }} axisLine={false} tickLine={false} />
                <YAxis tick={{ fill: '#6b7280', fontSize: 11 }} axisLine={false} tickLine={false} />
                <Tooltip contentStyle={TOOLTIP_STYLE} formatter={(v: any) => [`${v} ms`, 'HRV']} />
                <Line type="monotone" dataKey="hrv" stroke="#4f6ef7" strokeWidth={2} dot={{ fill: '#4f6ef7', r: 3 }} />
              </LineChart>
            </ResponsiveContainer>
          ) : (
            <div className="h-40 flex items-center justify-center text-gray-500 text-sm">
              No HRV data yet.
            </div>
          )}
        </ChartCard>
      </div>
    </div>
  )
}
