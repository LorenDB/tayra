import type { App } from 'vue'
import type { Store } from 'vuex'
import type { Router } from 'vue-router'
import type { AxiosError } from 'axios'
import type { RootState } from '~/store'

// eslint-disable-next-line
import type { ComponentPublicInstance } from '@vue/runtime-core'

export type FunctionRef = Element | ComponentPublicInstance | null

// App structure stuff
export interface InitModuleContext {
  app: App
  router: Router
  store: Store<RootState>
}

export type InitModule = (ctx: InitModuleContext) => void | Promise<void>

export interface QueueItemSource {
  id: string
  track: Track
  duration: string
  coverUrl: string

  // TODO (wvffle): Maybe use <translate> component to avoid passing the labels
  labels: {
    remove: string
    selectTrack: string
    favorite: string
  }
}

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
  downloads_count: number

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

  metadata?: {
    itunes_category?: unknown
    itunes_subcategory?: unknown
    language?: string
    owner_name?: string
    owner_email?: string
  }
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
    large_square_crop: string
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

export interface Listening {
  id: string
  track: Track
  user: User
  actor: Actor
  creation_date: string
}

// API stuff
// eslint-disable-next-line
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

// FS Browser
export interface FSEntry {
  dir: boolean
  name: string
}

export interface FileSystem {
  root: boolean
  content: FSEntry[]
  import: FSLogs
}

export interface FSLogs {
  status: 'pending' | 'started'
  reference: unknown // TODO (wvffle): Find correct type
  logs: string[]
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
  uuid: string
  filename?: string
  source?: string
  duration?: number
  mimetype: string
  extension: string
  listen_url: string
  bitrate?: number
  size?: number

  import_status: ImportStatus
  import_details?: {
    detail: object
    error_code: string
  }

  import_metadata?: Record<string, string>
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
  email: string
  // TODO (wvffle): Is it really a string? Or maybe it's { text: string, content_type: string }
  summary: string
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
  type: 'request' | 'report'
  author?: Actor // TODO (wvffle): Check if is valid
  summary?: string
  creation_date?: string
}

// Instance policy stuff
export interface InstancePolicy {
  id: number
  uuid: string
  creation_date: string
  actor: Actor

  summary: string
  is_active: boolean
  block_all: boolean
  silence_activity: boolean
  silence_notifications: boolean
  reject_media: boolean
}

// Plugin stuff
export interface Plugin {
  name: string
  label: string
  homepage?: string
  enabled: boolean
  description?: string
  source?: string
  values?: Record<string, string>
  conf?: {
    name: string
    label: string
    type: 'text' | 'long_text' | 'url' | 'password'
    help?: string
  }[]
}

// Report stuff
export type EntityObjectType = 'artist' | 'album' | 'track' | 'library' | 'playlist' | 'account' | 'channel'

export interface ReportTarget {
  id: string
  type: EntityObjectType
}

export type ReviewStatePayload = { value: unknown } | Partial<Artist> | Partial<Album> | Partial<Track>
export interface ReviewState {
  [id: string]: ReviewStatePayload
}

export interface Review {
  uuid: string
  is_applied: boolean | null
  is_approved: boolean | null
  created_by: Actor
  previous_state: ReviewState
  payload: ReviewState
  target?: ReportTarget & {
    type: 'artist' | 'album' | 'track'
    repr: string
  }
  creation_date: string
  summary?: string
  type: 'update'
}

export interface Report {
  uuid: string
  summary?: string
  is_applied: boolean
  is_handled: boolean
  previous_state: string
  notes: Note[]
  type: string

  assigned_to?: Actor
  submitter?: Actor
  submitter_email?: string

  target_owner?: Actor
  target?: ReportTarget
  target_state: {
    _target: ReportTarget
    domain: string
    [k: string]: unknown
  }

  creation_date: string
  handled_date: string
}

// User request stuff
export type UserRequestStatus = 'approved' | 'refused' | 'pending'
export interface UserRequest {
  uuid: string
  notes: Note[]
  status: UserRequestStatus

  assigned_to?: Actor
  submitter?: Actor
  submitter_email?: string

  creation_date: string
  handled_date: string

  metadata: Record<string, string>
}

// Notification stuff
export interface Notification {
  id: number
  is_read: boolean
}

// Tags stuff
export interface Tag {
  name: string
}

// Application stuff
export interface Application {
  client_id: string
  name: string
  redirect_uris: string
  scopes: string

  // This is actually a date string
  created: string
}
