import { AudioContext } from 'standardized-audio-context-mock'
import { vi } from 'vitest'

vi.mock('standardized-audio-context', () => ({
  AudioContext
}))

