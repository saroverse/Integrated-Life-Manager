import axios from 'axios'

const TOKEN = import.meta.env.VITE_API_TOKEN || 'change-this-to-a-random-secret'

const api = axios.create({
  baseURL: '/api/v1',
  headers: {
    'X-Device-Token': TOKEN,
    'Content-Type': 'application/json',
  },
})

export default api
