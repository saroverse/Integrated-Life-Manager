import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { getTasks, createTask, updateTask, completeTask, deleteTask } from '../api'
import { Task } from '../types'
import { Plus, Check, Trash2, ChevronDown, ChevronUp } from 'lucide-react'

const PRIORITY_COLORS: Record<string, string> = {
  urgent: 'bg-red-500/20 text-red-400 border-red-500/30',
  high: 'bg-orange-500/20 text-orange-400 border-orange-500/30',
  medium: 'bg-blue-500/20 text-blue-400 border-blue-500/30',
  low: 'bg-gray-500/20 text-gray-400 border-gray-500/30',
}

function TaskForm({ onSubmit, onCancel }: { onSubmit: (data: any) => void; onCancel: () => void }) {
  const [title, setTitle] = useState('')
  const [priority, setPriority] = useState('medium')
  const [dueDate, setDueDate] = useState('')
  const [description, setDescription] = useState('')

  return (
    <div className="card border-primary-500/30 space-y-3">
      <input
        autoFocus
        className="w-full bg-transparent text-white placeholder-gray-500 focus:outline-none text-sm font-medium"
        placeholder="Task title..."
        value={title}
        onChange={e => setTitle(e.target.value)}
        onKeyDown={e => e.key === 'Enter' && title && onSubmit({ title, priority, due_date: dueDate || undefined, description: description || undefined })}
      />
      <input
        className="w-full bg-transparent text-gray-300 placeholder-gray-600 focus:outline-none text-sm"
        placeholder="Description (optional)"
        value={description}
        onChange={e => setDescription(e.target.value)}
      />
      <div className="flex items-center gap-3">
        <select
          className="bg-surface border border-border rounded-lg px-2 py-1 text-sm text-gray-300 focus:outline-none"
          value={priority}
          onChange={e => setPriority(e.target.value)}
        >
          <option value="low">Low</option>
          <option value="medium">Medium</option>
          <option value="high">High</option>
          <option value="urgent">Urgent</option>
        </select>
        <input
          type="date"
          className="bg-surface border border-border rounded-lg px-2 py-1 text-sm text-gray-300 focus:outline-none"
          value={dueDate}
          onChange={e => setDueDate(e.target.value)}
        />
        <div className="ml-auto flex gap-2">
          <button onClick={onCancel} className="btn-ghost text-sm px-3 py-1">Cancel</button>
          <button
            disabled={!title}
            onClick={() => title && onSubmit({ title, priority, due_date: dueDate || undefined, description: description || undefined })}
            className="btn-primary text-sm px-3 py-1"
          >
            Add Task
          </button>
        </div>
      </div>
    </div>
  )
}

function TaskRow({ task, onComplete, onDelete }: { task: Task; onComplete: () => void; onDelete: () => void }) {
  const [expanded, setExpanded] = useState(false)

  return (
    <div className={`card transition-opacity ${task.status === 'done' ? 'opacity-50' : ''}`}>
      <div className="flex items-start gap-3">
        <button
          onClick={onComplete}
          className={`mt-0.5 shrink-0 w-5 h-5 rounded-full border-2 flex items-center justify-center transition-colors ${
            task.status === 'done' ? 'bg-primary-500 border-primary-500' : 'border-gray-600 hover:border-primary-500'
          }`}
        >
          {task.status === 'done' && <Check size={11} className="text-white" />}
        </button>
        <div className="flex-1 min-w-0">
          <p className={`text-sm font-medium ${task.status === 'done' ? 'line-through text-gray-500' : 'text-white'}`}>
            {task.title}
          </p>
          {task.due_date && (
            <p className="text-xs text-gray-500 mt-0.5">{task.due_date}</p>
          )}
          {task.description && expanded && (
            <p className="text-xs text-gray-400 mt-2 leading-relaxed">{task.description}</p>
          )}
        </div>
        <div className="flex items-center gap-2 shrink-0">
          <span className={`badge border ${PRIORITY_COLORS[task.priority]}`}>{task.priority}</span>
          {task.description && (
            <button onClick={() => setExpanded(e => !e)} className="text-gray-500 hover:text-gray-300">
              {expanded ? <ChevronUp size={14} /> : <ChevronDown size={14} />}
            </button>
          )}
          <button onClick={onDelete} className="text-gray-600 hover:text-red-400 transition-colors">
            <Trash2 size={14} />
          </button>
        </div>
      </div>
    </div>
  )
}

export default function Tasks() {
  const qc = useQueryClient()
  const [showForm, setShowForm] = useState(false)
  const [filter, setFilter] = useState<string | undefined>(undefined)

  const { data: tasks = [], isLoading } = useQuery<Task[]>({
    queryKey: ['tasks', filter],
    queryFn: () => getTasks(filter ? { status: filter } : undefined),
  })

  const createMut = useMutation({
    mutationFn: createTask,
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['tasks'] }); setShowForm(false) },
  })

  const completeMut = useMutation({
    mutationFn: completeTask,
    onSuccess: () => qc.invalidateQueries({ queryKey: ['tasks'] }),
  })

  const deleteMut = useMutation({
    mutationFn: deleteTask,
    onSuccess: () => qc.invalidateQueries({ queryKey: ['tasks'] }),
  })

  const filters = [
    { label: 'All', value: undefined },
    { label: 'Pending', value: 'pending' },
    { label: 'In Progress', value: 'in_progress' },
    { label: 'Done', value: 'done' },
  ]

  const pending = tasks.filter(t => t.status !== 'done')
  const done = tasks.filter(t => t.status === 'done')

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold">Tasks</h1>
          <p className="text-gray-400 text-sm">{pending.length} pending</p>
        </div>
        <button onClick={() => setShowForm(true)} className="btn-primary flex items-center gap-2">
          <Plus size={16} /> New Task
        </button>
      </div>

      <div className="flex gap-2">
        {filters.map(f => (
          <button
            key={String(f.value)}
            onClick={() => setFilter(f.value)}
            className={`px-3 py-1.5 rounded-lg text-sm transition-colors ${
              filter === f.value ? 'bg-primary-500 text-white' : 'bg-card text-gray-400 hover:text-white border border-border'
            }`}
          >
            {f.label}
          </button>
        ))}
      </div>

      {showForm && (
        <TaskForm
          onSubmit={(data) => createMut.mutate(data)}
          onCancel={() => setShowForm(false)}
        />
      )}

      {isLoading ? (
        <p className="text-gray-500 animate-pulse">Loading...</p>
      ) : (
        <div className="space-y-2">
          {tasks.map(task => (
            <TaskRow
              key={task.id}
              task={task}
              onComplete={() => completeMut.mutate(task.id)}
              onDelete={() => deleteMut.mutate(task.id)}
            />
          ))}
          {tasks.length === 0 && (
            <div className="text-center py-12 text-gray-500">
              <p className="mb-3">No tasks yet</p>
              <button onClick={() => setShowForm(true)} className="btn-primary text-sm">
                Add your first task
              </button>
            </div>
          )}
        </div>
      )}
    </div>
  )
}
