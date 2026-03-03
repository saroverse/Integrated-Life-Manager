export interface Task {
  id: string
  title: string
  description?: string
  status: 'pending' | 'in_progress' | 'done' | 'cancelled'
  priority: 'low' | 'medium' | 'high' | 'urgent'
  due_date?: string
  recurrence?: string
  tags?: string
  project_id?: string
  completed_at?: string
  created_at: string
  updated_at: string
}

export interface Habit {
  id: string
  name: string
  description?: string
  frequency: string
  frequency_days?: string
  target_count: number
  icon?: string
  color?: string
  category?: string
  reminder_time?: string
  active: number
  created_at: string
}

export interface HabitLog {
  id: string
  habit_id: string
  date: string
  completed: number
  count: number
  note?: string
  logged_at: string
}

export interface TodayHabit {
  id: string
  name: string
  icon?: string
  color?: string
  category?: string
  target_count: number
  completed: boolean
  log_id?: string
}

export interface SleepSession {
  id: string
  date: string
  bedtime: string
  wake_time: string
  total_duration?: number
  deep_sleep?: number
  rem_sleep?: number
  light_sleep?: number
  awake_time?: number
  sleep_score?: number
  source: string
}

export interface Summary {
  id: string
  summary_type: string
  period_start: string
  period_end: string
  content: string
  model_used?: string
  generation_time?: number
  status: string
  created_at: string
}

export interface JournalEntry {
  id: string
  date: string
  content: string
  mood?: number
  energy?: number
  tags?: string
  created_at: string
  updated_at: string
}

export interface HealthSummary {
  date: string
  steps: number
  resting_heart_rate?: number
  heart_rate_variability_sdnn?: number
  sleep?: {
    total?: number
    deep?: number
    rem?: number
    score?: number
    bedtime?: string
    wake_time?: string
  }
  workouts: { type: string; duration?: number; calories?: number }[]
}
