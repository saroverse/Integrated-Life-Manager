import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { getHabits, getHabitsToday, createHabit, logHabit, getHabitStreak } from '../api'
import { Habit, TodayHabit } from '../types'
import { CheckCircle2, Circle, Plus, Flame } from 'lucide-react'
import { format } from 'date-fns'

function HabitCreateForm({ onSubmit, onCancel }: { onSubmit: (d: any) => void; onCancel: () => void }) {
  const [name, setName] = useState('')
  const [category, setCategory] = useState('')
  const [icon, setIcon] = useState('')
  const [reminderTime, setReminderTime] = useState('')
  const [frequency, setFrequency] = useState('daily')

  return (
    <div className="card border-primary-500/30 space-y-3">
      <div className="flex gap-2">
        <input
          placeholder="Emoji (optional)"
          className="w-14 bg-surface border border-border rounded-lg px-2 py-1.5 text-sm text-white focus:outline-none text-center"
          value={icon}
          onChange={e => setIcon(e.target.value)}
          maxLength={2}
        />
        <input
          autoFocus
          placeholder="Habit name..."
          className="flex-1 bg-surface border border-border rounded-lg px-3 py-1.5 text-sm text-white focus:outline-none placeholder-gray-500"
          value={name}
          onChange={e => setName(e.target.value)}
        />
      </div>
      <div className="flex gap-2">
        <select
          className="bg-surface border border-border rounded-lg px-2 py-1.5 text-sm text-gray-300 focus:outline-none"
          value={frequency}
          onChange={e => setFrequency(e.target.value)}
        >
          <option value="daily">Daily</option>
          <option value="weekdays">Weekdays</option>
          <option value="weekly">Weekly</option>
        </select>
        <input
          placeholder="Category"
          className="flex-1 bg-surface border border-border rounded-lg px-3 py-1.5 text-sm text-white focus:outline-none placeholder-gray-500"
          value={category}
          onChange={e => setCategory(e.target.value)}
        />
        <input
          type="time"
          className="bg-surface border border-border rounded-lg px-2 py-1.5 text-sm text-gray-300 focus:outline-none"
          value={reminderTime}
          onChange={e => setReminderTime(e.target.value)}
          title="Reminder time"
        />
      </div>
      <div className="flex gap-2 justify-end">
        <button onClick={onCancel} className="btn-ghost text-sm">Cancel</button>
        <button
          disabled={!name}
          onClick={() => name && onSubmit({ name, icon: icon || undefined, category: category || undefined, frequency, reminder_time: reminderTime || undefined })}
          className="btn-primary text-sm"
        >
          Create Habit
        </button>
      </div>
    </div>
  )
}

function HabitCard({ habit, todayLog, onLog }: { habit: TodayHabit; todayLog?: any; onLog: (completed: boolean) => void }) {
  const { data: streak } = useQuery({
    queryKey: ['habit-streak', habit.id],
    queryFn: () => getHabitStreak(habit.id),
  })

  return (
    <div className="card flex items-center gap-4">
      <button
        onClick={() => onLog(!habit.completed)}
        className={`w-10 h-10 rounded-full border-2 flex items-center justify-center transition-all shrink-0 ${
          habit.completed
            ? 'bg-primary-500 border-primary-500'
            : 'border-gray-600 hover:border-primary-500'
        }`}
      >
        {habit.completed ? (
          <CheckCircle2 size={20} className="text-white" />
        ) : (
          <span className="text-lg">{habit.icon || '◯'}</span>
        )}
      </button>
      <div className="flex-1 min-w-0">
        <p className={`font-medium text-sm ${habit.completed ? 'text-gray-400 line-through' : 'text-white'}`}>
          {habit.name}
        </p>
        {habit.category && <p className="text-xs text-gray-500 mt-0.5">{habit.category}</p>}
      </div>
      {streak && streak.current_streak > 0 && (
        <div className="flex items-center gap-1 text-orange-400 shrink-0">
          <Flame size={14} />
          <span className="text-sm font-medium">{streak.current_streak}</span>
        </div>
      )}
    </div>
  )
}

export default function Habits() {
  const qc = useQueryClient()
  const today = format(new Date(), 'yyyy-MM-dd')
  const [showForm, setShowForm] = useState(false)

  const { data: todayHabits = [] } = useQuery<TodayHabit[]>({
    queryKey: ['habits-today'],
    queryFn: getHabitsToday,
  })

  const createMut = useMutation({
    mutationFn: createHabit,
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['habits'] }); qc.invalidateQueries({ queryKey: ['habits-today'] }); setShowForm(false) },
  })

  const logMut = useMutation({
    mutationFn: ({ id, completed }: { id: string; completed: boolean }) =>
      logHabit(id, { date: today, completed: completed ? 1 : 0 }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['habits-today'] }); qc.invalidateQueries({ queryKey: ['dashboard'] }) },
  })

  const done = todayHabits.filter(h => h.completed).length
  const total = todayHabits.length

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold">Habits</h1>
          <p className="text-gray-400 text-sm">{done}/{total} completed today</p>
        </div>
        <button onClick={() => setShowForm(true)} className="btn-primary flex items-center gap-2">
          <Plus size={16} /> New Habit
        </button>
      </div>

      {total > 0 && (
        <div className="card">
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm text-gray-400">Today's progress</span>
            <span className="text-sm font-medium">{done}/{total}</span>
          </div>
          <div className="h-2 bg-border rounded-full overflow-hidden">
            <div
              className="h-full bg-primary-500 rounded-full transition-all"
              style={{ width: `${total ? (done / total) * 100 : 0}%` }}
            />
          </div>
        </div>
      )}

      {showForm && (
        <HabitCreateForm
          onSubmit={(d) => createMut.mutate(d)}
          onCancel={() => setShowForm(false)}
        />
      )}

      <div className="space-y-2">
        {todayHabits.map(habit => (
          <HabitCard
            key={habit.id}
            habit={habit}
            onLog={(completed) => logMut.mutate({ id: habit.id, completed })}
          />
        ))}
        {todayHabits.length === 0 && !showForm && (
          <div className="text-center py-12 text-gray-500">
            <p className="mb-3">No habits yet</p>
            <button onClick={() => setShowForm(true)} className="btn-primary text-sm">
              Create your first habit
            </button>
          </div>
        )}
      </div>
    </div>
  )
}
