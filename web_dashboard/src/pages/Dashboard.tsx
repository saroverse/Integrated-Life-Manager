import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { getDashboardToday, getDashboardStats, logHabit, completeTask, generateSummary } from '../api'
import ReactMarkdown from 'react-markdown'
import { format } from 'date-fns'
import { CheckCircle2, Circle, Zap, Footprints, Moon, Smartphone, RefreshCw } from 'lucide-react'
import { useState } from 'react'

function StatCard({ label, value, icon: Icon, sub }: { label: string; value: string; icon: any; sub?: string }) {
  return (
    <div className="card flex items-center gap-4">
      <div className="w-10 h-10 rounded-lg bg-primary-500/20 flex items-center justify-center shrink-0">
        <Icon size={18} className="text-primary-500" />
      </div>
      <div>
        <p className="text-2xl font-bold">{value}</p>
        <p className="text-xs text-gray-400">{label}</p>
        {sub && <p className="text-xs text-gray-500">{sub}</p>}
      </div>
    </div>
  )
}

export default function Dashboard() {
  const qc = useQueryClient()
  const today = format(new Date(), 'yyyy-MM-dd')

  const { data, isLoading } = useQuery({ queryKey: ['dashboard', 'today'], queryFn: getDashboardToday })
  const { data: stats } = useQuery({ queryKey: ['dashboard', 'stats'], queryFn: getDashboardStats })

  const logHabitMut = useMutation({
    mutationFn: ({ id, completed }: { id: string; completed: boolean }) =>
      logHabit(id, { date: today, completed: completed ? 1 : 0 }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['dashboard'] }),
  })

  const completeTaskMut = useMutation({
    mutationFn: (id: string) => completeTask(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['dashboard'] }),
  })

  const [generating, setGenerating] = useState(false)
  const genBriefing = async () => {
    setGenerating(true)
    try {
      await generateSummary({ type: 'daily_briefing', date: today })
      qc.invalidateQueries({ queryKey: ['dashboard'] })
    } finally {
      setGenerating(false)
    }
  }

  if (isLoading) return <div className="text-gray-400 animate-pulse">Loading...</div>

  const d = data || {}
  const habits = d.habits?.today || []
  const tasks = d.tasks?.due_today || []

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">{format(new Date(), 'EEEE, MMMM d')}</h1>
        <p className="text-gray-400 text-sm">Good day. Here's your overview.</p>
      </div>

      {/* Stat cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
        <StatCard
          label="Steps today"
          icon={Footprints}
          value={(d.health?.steps || 0).toLocaleString()}
        />
        <StatCard
          label="Sleep last night"
          icon={Moon}
          value={d.health?.sleep?.total ? `${d.health.sleep.total.toFixed(1)}h` : '—'}
          sub={d.health?.sleep?.score ? `Score: ${d.health.sleep.score}` : undefined}
        />
        <StatCard
          label="Habits done"
          icon={Zap}
          value={`${d.habits?.completed || 0}/${d.habits?.total || 0}`}
        />
        <StatCard
          label="Screen time"
          icon={Smartphone}
          value={`${d.screen_time?.total_hours || 0}h`}
        />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        {/* AI Briefing */}
        <div className="lg:col-span-2 card">
          <div className="flex items-center justify-between mb-3">
            <h2 className="font-semibold text-white">Daily Briefing</h2>
            <button
              onClick={genBriefing}
              disabled={generating}
              className="btn-ghost text-xs flex items-center gap-1.5"
            >
              <RefreshCw size={13} className={generating ? 'animate-spin' : ''} />
              {generating ? 'Generating...' : 'Regenerate'}
            </button>
          </div>
          {d.latest_briefing?.content ? (
            <div className="prose prose-invert prose-sm max-w-none text-gray-300">
              <ReactMarkdown>{d.latest_briefing.content}</ReactMarkdown>
            </div>
          ) : (
            <div className="text-center py-8 text-gray-500">
              <p className="mb-3">No briefing yet.</p>
              <button onClick={genBriefing} disabled={generating} className="btn-primary text-sm">
                {generating ? 'Generating...' : 'Generate Morning Briefing'}
              </button>
            </div>
          )}
        </div>

        {/* Right column */}
        <div className="space-y-4">
          {/* Today's Habits */}
          <div className="card">
            <h2 className="font-semibold mb-3">Today's Habits</h2>
            {habits.length === 0 ? (
              <p className="text-gray-500 text-sm">No habits set</p>
            ) : (
              <div className="space-y-2">
                {habits.map((h: any) => (
                  <button
                    key={h.id}
                    onClick={() => logHabitMut.mutate({ id: h.id, completed: !h.completed })}
                    className="flex items-center gap-3 w-full text-left hover:bg-white/5 rounded-lg p-1.5 transition-colors"
                  >
                    {h.completed ? (
                      <CheckCircle2 size={18} className="text-primary-500 shrink-0" />
                    ) : (
                      <Circle size={18} className="text-gray-500 shrink-0" />
                    )}
                    <span className={`text-sm ${h.completed ? 'line-through text-gray-500' : 'text-white'}`}>
                      {h.icon && <span className="mr-1">{h.icon}</span>}{h.name}
                    </span>
                  </button>
                ))}
              </div>
            )}
          </div>

          {/* Today's Tasks */}
          <div className="card">
            <div className="flex items-center justify-between mb-3">
              <h2 className="font-semibold">Due Today</h2>
              <span className="badge bg-primary-500/20 text-primary-500">{d.tasks?.completed_today || 0} done</span>
            </div>
            {tasks.length === 0 ? (
              <p className="text-gray-500 text-sm">All clear</p>
            ) : (
              <div className="space-y-1.5">
                {tasks.slice(0, 5).map((t: any) => (
                  <button
                    key={t.id}
                    onClick={() => completeTaskMut.mutate(t.id)}
                    className="flex items-center gap-3 w-full text-left hover:bg-white/5 rounded-lg p-1.5 transition-colors group"
                  >
                    <Circle size={16} className="text-gray-500 group-hover:text-primary-500 shrink-0 transition-colors" />
                    <span className="text-sm text-white truncate">{t.title}</span>
                    <span className={`ml-auto badge text-xs shrink-0 ${
                      t.priority === 'urgent' ? 'bg-red-500/20 text-red-400' :
                      t.priority === 'high' ? 'bg-orange-500/20 text-orange-400' :
                      'bg-gray-500/20 text-gray-400'
                    }`}>{t.priority}</span>
                  </button>
                ))}
                {tasks.length > 5 && (
                  <p className="text-xs text-gray-500 pt-1">+{tasks.length - 5} more</p>
                )}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
