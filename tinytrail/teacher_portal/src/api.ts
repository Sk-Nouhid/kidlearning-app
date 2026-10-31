export const API_BASE = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5000').replace(/\/$/, '')

export type Template = { id: number; template_key: string; name: string; description: string | null }
export type Game = {
  id: number
  title: string
  description: string | null
  status: 'draft' | 'published'
  template_id: number
  template_name: string
  created_at: string
  updated_at: string
}
export type MatchingData = { type: 'matching'; pairs: { left: string; right: string }[] }
export type MultipleChoiceData = { type: 'multiple_choice'; options: string[]; answer: string }
export type QuestionData = MatchingData | MultipleChoiceData
export type Question = { id: number; prompt: string; question_data: QuestionData; sort_order: number }
export type LibraryQuestion = Omit<Question, 'sort_order'> & { created_at?: string; updated_at?: string }
export type MediaAsset = {
  id: number
  original_name: string
  storage_key: string
  media_type: string
  mime_type: string
  created_at: string
  url: string
}

export class ApiError extends Error {
  status: number
  constructor(message: string, status: number) {
    super(message)
    this.status = status
  }
}

export async function request<T>(path: string, token?: string | null, options: RequestInit = {}): Promise<T> {
  const headers = new Headers(options.headers)
  if (token) headers.set('Authorization', `Bearer ${token}`)
  if (options.body && !(options.body instanceof FormData)) headers.set('Content-Type', 'application/json')
  let response: Response
  try {
    response = await fetch(`${API_BASE}${path}`, { ...options, headers })
  } catch {
    throw new ApiError(`Could not reach TinyTrail at ${API_BASE}. Check that the API is running and try again.`, 0)
  }
  const body = await response.json().catch(() => ({})) as { message?: string }
  if (response.status === 401 && token) {
    window.dispatchEvent(new Event('tinytrail:unauthorized'))
  }
  if (!response.ok) throw new ApiError(body.message || `Request failed (${response.status})`, response.status)
  return body as T
}

export function imageUrl(path: string) {
  return path.startsWith('http') ? path : `${API_BASE}${path}`
}
