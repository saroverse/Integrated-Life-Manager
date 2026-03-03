import api from './client'

// Dashboard
export const getDashboardToday = () => api.get('/dashboard/today').then(r => r.data)
export const getDashboardStats = () => api.get('/dashboard/stats').then(r => r.data)

// Tasks
export const getTasks = (params?: { status?: string; priority?: string }) =>
  api.get('/tasks', { params }).then(r => r.data)
export const getTasksToday = () => api.get('/tasks/today').then(r => r.data)
export const createTask = (data: any) => api.post('/tasks', data).then(r => r.data)
export const updateTask = (id: string, data: any) => api.put(`/tasks/${id}`, data).then(r => r.data)
export const completeTask = (id: string) => api.post(`/tasks/${id}/complete`).then(r => r.data)
export const deleteTask = (id: string) => api.delete(`/tasks/${id}`)

// Habits
export const getHabits = () => api.get('/habits').then(r => r.data)
export const getHabitsToday = () => api.get('/habits/today').then(r => r.data)
export const createHabit = (data: any) => api.post('/habits', data).then(r => r.data)
export const updateHabit = (id: string, data: any) => api.put(`/habits/${id}`, data).then(r => r.data)
export const logHabit = (id: string, data: any) => api.post(`/habits/${id}/log`, data).then(r => r.data)
export const getHabitStreak = (id: string) => api.get(`/habits/${id}/streak`).then(r => r.data)
export const getHabitLogs = (id: string, params?: { start?: string; end?: string }) =>
  api.get(`/habits/${id}/logs`, { params }).then(r => r.data)

// Health
export const getHealthSummary = (date?: string) =>
  api.get('/health/summary', { params: { date } }).then(r => r.data)
export const getSleepSessions = (params?: { start?: string; end?: string }) =>
  api.get('/health/sleep', { params }).then(r => r.data)
export const getHealthMetrics = (params?: { type?: string; start?: string; end?: string }) =>
  api.get('/health/metrics', { params }).then(r => r.data)
export const getWorkouts = (params?: { start?: string; end?: string }) =>
  api.get('/health/workouts', { params }).then(r => r.data)

// Screen Time
export const getScreenTimeDaily = (date?: string) =>
  api.get('/screen-time/daily', { params: { date } }).then(r => r.data)
export const getScreenTimeTrends = (params?: { start?: string; end?: string }) =>
  api.get('/screen-time/trends', { params }).then(r => r.data)

// Journal
export const getJournalEntries = (params?: { start?: string; end?: string }) =>
  api.get('/journal', { params }).then(r => r.data)
export const getJournalToday = () => api.get('/journal/today').then(r => r.data)
export const createJournalEntry = (data: any) => api.post('/journal', data).then(r => r.data)
export const updateJournalEntry = (id: string, data: any) => api.put(`/journal/${id}`, data).then(r => r.data)

// Summaries
export const getSummaries = (params?: { type?: string; limit?: number }) =>
  api.get('/summaries', { params }).then(r => r.data)
export const getLatestSummary = (type: string) =>
  api.get('/summaries/latest', { params: { type } }).then(r => r.data)
export const generateSummary = (data: { type: string; date?: string }) =>
  api.post('/summaries/generate', data).then(r => r.data)
