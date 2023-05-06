import { AudioContext } from 'standardized-audio-context-mock'
import { vi, beforeAll } from 'vitest'

beforeAll(() => {
  vi.mock('standardized-audio-context', () => ({
    AudioContext
  }))
})

