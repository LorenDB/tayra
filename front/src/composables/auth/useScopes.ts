export type ScopeId = 'profile' | 'libraries' | 'favorites' | 'listenings' | 'follows'
  | 'playlists' | 'radios' | 'filters' | 'notifications' | 'edits' | 'security' | 'reports'

export default () => [
  { id: 'profile', icon: 'user' },
  { id: 'libraries', icon: 'book' },
  { id: 'favorites', icon: 'heart' },
  { id: 'listenings', icon: 'music' },
  { id: 'follows', icon: 'users' },
  { id: 'playlists', icon: 'list' },
  { id: 'radios', icon: 'rss' },
  { id: 'filters', icon: 'eye slash' },
  { id: 'notifications', icon: 'bell' },
  { id: 'edits', icon: 'pencil alternate' },
  { id: 'security', icon: 'lock' },
  { id: 'reports', icon: 'warning sign' }
] as { id: ScopeId, icon: string }[]
