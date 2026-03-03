import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { getSummaries, generateSummary } from '../api'
import { Summary } from '../types'
import ReactMarkdown from 'react-markdown'
import { format } from 'date-fns'
import { RefreshCw, Sparkles } from 'lucide-react'

const SUMMARY_TYPES = [
  { key: 'daily_briefing', label: 'Daily Briefing', emoji: '☀️' },
  { key: 'daily_recap', label: 'Daily Recap', emoji: '🌙' },
  { key: 'weekly_recap', label: 'Weekly Recap', emoji: '📅' },
  { key: 'monthly_recap', label: 'Monthly Recap', emoji: '📊' },
]

export default function Summaries() {
  const qc = useQueryClient()
  const [activeType, setActiveType] = useState('daily_briefing')
  const [generating, setGenerating] = useState(false)

  const { data: summaries = [] } = useQuery<Summary[]>({
    queryKey: ['summaries', activeType],
    queryFn: () => getSummaries({ type: activeType, limit: 10 }),
  })

  const [selectedId, setSelectedId] = useState<string | null>(null)
  const selected = summaries.find(s => s.id === selectedId) || summaries[0]

  const generate = async () => {
    setGenerating(true)
    try {
      const summary = await generateSummary({ type: activeType })
      qc.invalidateQueries({ queryKey: ['summaries'] })
      setSelectedId(summary.id)
    } finally {
      setGenerating(false)
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold">AI Summaries</h1>
          <p className="text-gray-400 text-sm">Automatic daily, weekly, and monthly recaps</p>
        </div>
        <button
          onClick={generate}
          disabled={generating}
          className="btn-primary flex items-center gap-2"
        >
          {generating ? (
            <RefreshCw size={15} className="animate-spin" />
          ) : (
            <Sparkles size={15} />
          )}
          {generating ? 'Generating...' : 'Generate Now'}
        </button>
      </div>

      <div className="flex gap-2 flex-wrap">
        {SUMMARY_TYPES.map(t => (
          <button
            key={t.key}
            onClick={() => { setActiveType(t.key); setSelectedId(null) }}
            className={`px-3 py-1.5 rounded-lg text-sm transition-colors flex items-center gap-1.5 ${
              activeType === t.key
                ? 'bg-primary-500 text-white'
                : 'bg-card text-gray-400 hover:text-white border border-border'
            }`}
          >
            {t.emoji} {t.label}
          </button>
        ))}
      </div>

      <div className="grid grid-cols-3 gap-4">
        {/* Summary list */}
        <div className="col-span-1 space-y-2">
          {summaries.length === 0 && !generating ? (
            <div className="card text-center py-8">
              <p className="text-gray-500 text-sm mb-3">No summaries yet</p>
              <button onClick={generate} className="btn-primary text-sm">
                Generate first summary
              </button>
            </div>
          ) : (
            summaries.map((s: Summary) => (
              <button
                key={s.id}
                onClick={() => setSelectedId(s.id)}
                className={`w-full text-left card transition-colors hover:border-primary-500/50 ${
                  selected?.id === s.id ? 'border-primary-500/50' : ''
                }`}
              >
                <p className="text-xs font-medium text-white">
                  {format(new Date(s.period_start + 'T12:00:00'), 'MMM d, yyyy')}
                </p>
                <p className="text-xs text-gray-500 mt-0.5">
                  {s.model_used || 'Unknown model'} · {s.generation_time?.toFixed(1)}s
                </p>
                <p className="text-xs text-gray-400 mt-1.5 line-clamp-2">{s.content.slice(0, 100)}...</p>
              </button>
            ))
          )}
        </div>

        {/* Summary content */}
        <div className="col-span-2">
          {selected ? (
            <div className="card">
              <div className="flex items-center justify-between mb-4">
                <div>
                  <p className="text-sm font-medium text-white">
                    {format(new Date(selected.period_start + 'T12:00:00'), 'EEEE, MMMM d, yyyy')}
                  </p>
                  <p className="text-xs text-gray-500">
                    {selected.model_used} · Generated in {selected.generation_time?.toFixed(1)}s
                  </p>
                </div>
              </div>
              <div className="prose prose-invert prose-sm max-w-none text-gray-300 leading-relaxed">
                <ReactMarkdown>{selected.content}</ReactMarkdown>
              </div>
            </div>
          ) : generating ? (
            <div className="card flex items-center justify-center py-16">
              <div className="text-center">
                <RefreshCw size={24} className="animate-spin text-primary-500 mx-auto mb-3" />
                <p className="text-gray-400 text-sm">Generating your summary...</p>
                <p className="text-gray-600 text-xs mt-1">This may take 15-30 seconds</p>
              </div>
            </div>
          ) : (
            <div className="card flex items-center justify-center py-16 text-gray-500">
              Select a summary to view it
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
