import { BrowserRouter, Routes, Route } from 'react-router-dom'
import Sidebar from './components/layout/Sidebar'
import Dashboard from './pages/Dashboard'
import Tasks from './pages/Tasks'
import Habits from './pages/Habits'
import Health from './pages/Health'
import ScreenTime from './pages/ScreenTime'
import Journal from './pages/Journal'
import Summaries from './pages/Summaries'

export default function App() {
  return (
    <BrowserRouter>
      <div className="flex min-h-screen">
        <Sidebar />
        <main className="flex-1 overflow-y-auto p-6 max-w-6xl">
          <Routes>
            <Route path="/" element={<Dashboard />} />
            <Route path="/tasks" element={<Tasks />} />
            <Route path="/habits" element={<Habits />} />
            <Route path="/health" element={<Health />} />
            <Route path="/screen-time" element={<ScreenTime />} />
            <Route path="/journal" element={<Journal />} />
            <Route path="/summaries" element={<Summaries />} />
          </Routes>
        </main>
      </div>
    </BrowserRouter>
  )
}
