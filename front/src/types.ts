import type { App } from 'vue'
import type { Store } from 'vuex'
import { Router } from 'vue-router'
import {AxiosError} from "axios";

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
  store: Store<any>
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
export interface Artist {
  name: string
}

export interface Album {
  artist: Artist
}

export interface Track {
  title: string
  album?: Album
  artist?: Artist
}

// API stuff
export interface APIErrorResponse {
  [key: string]: APIErrorResponse | string[]
}

export interface BackendError extends AxiosError {
  backendErrors: string[]
  rawPayload?: object
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

// Form stuff
export interface FormHelpText {
  content_type: string
  text?: string
}

export interface FormField {
  label: string
  input_type: 'short_text' | 'long_text'
  required: boolean
}

export interface Form {
  fields: FormField[]
  help_text: FormHelpText
}

// Yet uncategorized stuff
export interface Actor {
  preferred_username: string
  full_username: string
  is_local: boolean
  domain: string
}
