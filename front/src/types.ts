import type { App } from 'vue'
import type { Store } from 'vuex'
import type { Router } from 'vue-router'
import type { AxiosError } from 'axios'
import type { RootState } from '~/store'
import type { ComponentPublicInstance } from '@vue/runtime-core'

export type FunctionRef = Element | ComponentPublicInstance | null

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
export type ContentCategory = 'podcast' | 'music'

export interface Artist {
  id: string
  fid: string
  mbid?: string

  name: string
  description: Content
  cover?: Cover
  channel?: Channel
  tags: string[]

  content_category: ContentCategory
  albums: Album[]
  tracks_count: number
  attributed_to: Actor
  is_local: boolean
  is_playable: boolean
  modification_date?: string
}

export interface Album {
  id: string
  fid: string
  mbid?: string

  title: string
  description: Content
  release_date?: string
  cover?: Cover
  tags: string[]

  artist: Artist
  tracks_count: number
  tracks: Track[]

  is_playable: boolean
  is_local: boolean
}

export interface Track {
  id: string
  fid: string
  mbid?: string

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
  disc_number: number

  listen_url: string
  creation_date: string
  attributed_to: Actor

  is_playable: boolean
  is_local: boolean
}


export interface Channel {
  id: string
  uuid: string
  artist?: Artist
  actor: Actor
  attributed_to: Actor
  url?: string
  rss_url: string
  subscriptions_count: number
  downloads_count: number
  content_category: ContentCategory
}

export type PrivacyLevel = 'everyone' | 'instance' | 'me'

export interface Library {
  id: string
  uuid: string
  fid?: string
  name: string
  actor: Actor
  uploads_count: number
  size: number
  description: string
  privacy_level: PrivacyLevel
  creation_date: string
  follow?: LibraryFollow
  latest_scan: LibraryScan
}

export type ImportStatus = 'scanning' | 'pending' | 'finished' | 'errored' | 'draft' | 'skipped'
export interface LibraryScan {
  processed_files: number
  total_files: number
  status: ImportStatus
  errored_files: number
  modification_date: string
}

export interface LibraryFollow {
  uuid: string
  approved: boolean

  // TODO (wvffle): Check if it's not added only on frontend side
  isLoading?: boolean
}

export interface Cover {
  uuid: string
  urls: {
    original: string
    medium_square_crop: string
  }
}

export interface License {
  code: string
  name: string
  url: string
}

export interface Playlist {
  id: string
  name: string
  modification_date: string
  user: User
  privacy_level: PrivacyLevel
  tracks_count: number
  duration: number
  album_covers: string[]

  is_playable: boolean
}

export interface PlaylistTrack {
  track: Track
  position?: number
}

export interface Radio {
  id: string
  name: string
  user: User
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

// Profile stuff
export interface Actor {
  id: string
  fid?: string
  name?: string
  icon?: Cover
  summary: string
  preferred_username: string
  full_username: string
  is_local: boolean
  domain: string
}

export interface User {
  id: string
  avatar?: Cover
  username: string
  full_username: string
  instance_support_message_display_date: string
  funkwhale_support_message_display_date: string
  is_superuser: boolean
  privacy_level: PrivacyLevel
}

// Settings stuff
export type SettingsId = 'instance'
export interface SettingsGroup {
  label: string
  id: SettingsId
  settings: SettingsField[]
}

export interface SettingsField {
  name: string
  fieldType?: 'markdown'
  fieldParams?: {
    charLimit: number | null
    permissive: boolean
  }
}

export interface SettingsDataEntry {
  identifier: string
  fieldType: string
  fieldParams: object
  help_text: string
  verbose_name: string
  value: unknown
  field: {
    class: string
    widget: {
      class: string
    }
  }

  additional_data: {
    choices: [string, string]
  }
}

// Note stuff
export interface Note {
  uuid: string
  author: Actor // TODO (wvffle): Check if is valid
  summary: string
  creation_date: string
}