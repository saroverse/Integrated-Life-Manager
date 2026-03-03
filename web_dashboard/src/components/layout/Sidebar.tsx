import { NavLink } from 'react-router-dom'
import {
  LayoutDashboard,
  CheckSquare,
  Repeat,
  Heart,
  Smartphone,
  BookOpen,
  Sparkles,
} from 'lucide-react'
import clsx from 'clsx'

const navItems = [
  { to: '/', icon: LayoutDashboard, label: 'Dashboard' },
  { to: '/tasks', icon: CheckSquare, label: 'Tasks' },
  { to: '/habits', icon: Repeat, label: 'Habits' },
  { to: '/health', icon: Heart, label: 'Health' },
  { to: '/screen-time', icon: Smartphone, label: 'Screen Time' },
  { to: '/journal', icon: BookOpen, label: 'Journal' },
  { to: '/summaries', icon: Sparkles, label: 'AI Summaries' },
]

export default function Sidebar() {
  return (
    <aside className="w-56 shrink-0 border-r border-border flex flex-col h-screen sticky top-0">
      <div className="px-5 py-5 border-b border-border">
        <h1 className="text-lg font-bold text-white">Life Manager</h1>
        <p className="text-xs text-gray-500 mt-0.5">Integrated</p>
      </div>
      <nav className="flex-1 px-3 py-4 space-y-1">
        {navItems.map(({ to, icon: Icon, label }) => (
          <NavLink
            key={to}
            to={to}
            end={to === '/'}
            className={({ isActive }) =>
              clsx(
                'flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors',
                isActive
                  ? 'bg-primary-500/20 text-primary-500'
                  : 'text-gray-400 hover:bg-white/5 hover:text-white',
              )
            }
          >
            <Icon size={17} />
            {label}
          </NavLink>
        ))}
      </nav>
    </aside>
  )
}
