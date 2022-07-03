import type { App } from 'vue'
import type { Store } from 'vuex'
import { Router } from 'vue-router'
import { AxiosError } from 'axios'
import { RootState } from '~/store'

declare global {
  interface Window {
    $: JQueryStatic
    jQuery: JQueryStatic
  }
}

// App structure stuff
export interface InitModuleContext {
  app: App
  router: Router
  store: Store<RootState>
}

export type InitModule = (ctx: InitModuleContext) => void

// Theme stuff
export type Theme = 'auto' | 'light' | 'dark'

export interface ThemeEntry {
  icon: string
  name: string
  key: Theme
}

// Track stuff
export type ContentCategory = 'podcast'

export interface Artist {
  id: string

  name: string
  description: Content
  cover?: Cover
  tags: string[]

  content_category: ContentCategory
  albums: Album[]
}

export interface Album {
  id: string

  title: string
  description: Content
  release_date?: string
  cover?: Cover
  tags: string[]

  artist: Artist
  tracks_count: number
  tracks: Track[]
}

export interface Track {
  id: string

  title: string
  description: Content
  cover?: Cover
  position?: number
  copyright?: string
  license?: License
  tags: string[]
  uploads: Upload[]

  album?: Album
  artist?: Artist

  // TODO (wvffle): Make sure it really has listen_url
  listen_url: string
}


export interface Channel {
  id: string
  artist?: Artist
}

export interface Cover {
  uuid: string
}

export interface License {
  code: string
  name: string
  url: string
}

export interface Playlist {
  id: string
  name: string
  modification_date: Date // TODO (wvffle): Find correct type
}

// API stuff
export interface APIErrorResponse extends Record<string, APIErrorResponse | string[] | { code: string }[]> {}

export interface BackendError extends AxiosError {
  backendErrors: string[]
  rawPayload?: APIErrorResponse
}

export interface RateLimitStatus {
  limit: string
  scope: string
  remaining: string
  duration: string
  availableSeconds: number
  reset: string
  resetSeconds: string
}

// WebSocket stuff
export interface PendingReviewEditsWSEvent {
  pending_review_count: number
}

export interface PendingReviewReportsWSEvent {
  unresolved_count: number
}

export interface PendingReviewRequestsWSEvent {
  pending_count: number
}

export interface ListenWsEventObject {
  local_id: string
}

export interface ListenWSEvent {
  actor: ListenWsEventObject
  object: ListenWsEventObject
}

export type WebSocketEvent = PendingReviewEditsWSEvent | PendingReviewReportsWSEvent | PendingReviewRequestsWSEvent | ListenWSEvent

// FS Browser
export interface FSEntry {
  dir: boolean
  name: string
}

export interface FileSystem {
  root: boolean
  content: FSEntry[]
}

// Content stuff
export interface Content {
  content_type: 'text/plain' | 'text/markdown'
  text: string // TODO (wvffle): Ensure it's not nullable from backend side
}

// Form stuff
export interface FormField {
  label: string
  input_type: 'short_text' | 'long_text'
  required: boolean
}

export interface Form {
  fields: FormField[]
  help_text: Content
}

// Upload stuff
export interface Upload {
  filename?: string
  source?: string
  uuid: string
  duration?: number
  mimetype: string
  extension: string
  listen_url: string
}

// FileSystem Logs
export interface FSLogs {
  status: 'pending' | 'started'
  reference: unknown // TODO (wvffle): Find correct type
  logs: string[]
}

// Yet uncategorized stuff
export interface Actor {
  preferred_username: string
  full_username: string
  is_local: boolean
  domain: string
}
