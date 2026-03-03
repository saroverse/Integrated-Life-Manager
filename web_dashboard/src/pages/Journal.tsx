import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { getJournalEntries, getJournalToday, createJournalEntry, updateJournalEntry } from '../api'
import { JournalEntry } from '../types'
import { format } from 'date-fns'
import { Save } from 'lucide-react'

function MoodSlider({ label, value, onChange }: { label: string; value: number; onChange: (v: number) => void }) {
  return (
    <div className="flex items-center gap-3">
      <span className="text-xs text-gray-400 w-16">{label}</span>
      <input
        type="range"
        min={1}
        max={10}
        value={value}
        onChange={e => onChange(Number(e.target.value))}
        className="flex-1 accent-primary-500"
      />
      <span className="text-sm font-medium w-4 text-white">{value}</span>
    </div>
  )
}

export default function Journal() {
  const qc = useQueryClient()
  const today = format(new Date(), 'yyyy-MM-dd')

  const { data: todayEntry } = useQuery({
    queryKey: ['journal-today'],
    queryFn: getJournalToday,
  })

  const { data: entries = [] } = useQuery<JournalEntry[]>({
    queryKey: ['journal-entries'],
    queryFn: () => getJournalEntries(),
  })

  const [content, setContent] = useState('')
  const [mood, setMood] = useState(7)
  const [energy, setEnergy] = useState(7)
  const [saved, setSaved] = useState(false)

  const currentContent = todayEntry?.content || content

  const saveMut = useMutation({
    mutationFn: (data: any) =>
      todayEntry
        ? updateJournalEntry(todayEntry.id, data)
        : createJournalEntry({ ...data, date: today }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['journal'] })
      setSaved(true)
      setTimeout(() => setSaved(false), 2000)
    },
  })

  const handleSave = () => {
    saveMut.mutate({
      content: content || todayEntry?.content || '',
      mood,
      energy,
    })
  }

  return (
    <div className="space-y-6 max-w-2xl">
      <div>
        <h1 className="text-2xl font-bold">Journal</h1>
        <p className="text-gray-400 text-sm">{format(new Date(), 'EEEE, MMMM d')}</p>
      </div>

      <div className="card space-y-4">
        <div className="space-y-2">
          <MoodSlider label="Mood" value={todayEntry?.mood || mood} onChange={setMood} />
          <MoodSlider label="Energy" value={todayEntry?.energy || energy} onChange={setEnergy} />
        </div>
        <textarea
          className="w-full bg-surface/50 border border-border rounded-lg p-3 text-sm text-white placeholder-gray-500 focus:outline-none focus:border-primary-500/50 resize-none"
          placeholder="How was your day? What's on your mind?"
          rows={8}
          defaultValue={todayEntry?.content || ''}
          onChange={e => setContent(e.target.value)}
        />
        <div className="flex items-center justify-between">
          {saved && <span className="text-xs text-green-400">Saved!</span>}
          <button
            onClick={handleSave}
            disabled={saveMut.isPending}
            className="btn-primary ml-auto flex items-center gap-2"
          >
            <Save size={14} />
            {saveMut.isPending ? 'Saving...' : 'Save Entry'}
          </button>
        </div>
      </div>

      <div>
        <h2 className="text-lg font-semibold mb-3">Past Entries</h2>
        <div className="space-y-3">
          {entries.filter((e: JournalEntry) => e.date !== today).slice(0, 10).map((entry: JournalEntry) => (
            <div key={entry.id} className="card">
              <div className="flex items-center justify-between mb-2">
                <span className="text-sm font-medium">{format(new Date(entry.date + 'T12:00:00'), 'EEEE, MMMM d')}</span>
                <div className="flex gap-3 text-xs text-gray-500">
                  {entry.mood && <span>Mood: {entry.mood}/10</span>}
                  {entry.energy && <span>Energy: {entry.energy}/10</span>}
                </div>
              </div>
              <p className="text-sm text-gray-300 line-clamp-3">{entry.content}</p>
            </div>
          ))}
          {entries.filter((e: JournalEntry) => e.date !== today).length === 0 && (
            <p className="text-gray-500 text-sm">No past entries yet.</p>
          )}
        </div>
      </div>
    </div>
  )
}
