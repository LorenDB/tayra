import type { RouteLocationRaw } from 'vue-router'

import { gettext } from '~/init/locale'

interface ModeratedField {
  id: string
  label: string
  getValueRepr?: (obj: any) => string
}

export interface Entity {
  label: string
  icon: string
  getDeleteUrl?: (object: any) => string
  urls: {
    getDetail?: (object: any) => RouteLocationRaw
    getAdminDetail?: (object: any) => RouteLocationRaw
  }
  moderatedFields: ModeratedField[]
}

export type EntityObjectType = 'artist' | 'album' | 'track' | 'library' | 'playlist' | 'account' | 'channel'
type Configs = Record<EntityObjectType, Entity>

const { $pgettext } = gettext

const tags: ModeratedField = {
  id: 'tags',
  label: $pgettext('*/*/*/Noun', 'Tags'),
  getValueRepr: (tags: string[]) => tags.slice().sort().join('\n')
}

const name: ModeratedField = {
  id: 'name',
  label: $pgettext('*/*/*/Noun', 'Name')
}

const creationDate: ModeratedField = {
  id: 'creation_date',
  label: $pgettext('Content/*/*/Noun', 'Creation date')
}

const musicBrainzId: ModeratedField = {
  id: 'mbid',
  label: $pgettext('*/*/*/Noun', 'MusicBrainz ID')
}

const visibility: ModeratedField = {
  id: 'privacy_level',
  label: $pgettext('*/*/*', 'Visibility')
}

export default (): Configs => ({
  artist: {
    label: $pgettext('*/*/*/Noun', 'Artist'),
    icon: 'users',
    getDeleteUrl: (obj) => {
      return `manage/library/artists/${obj.id}/`
    },
    urls: {
      getDetail: (obj) => ({ name: 'library.artists.detail', params: { id: obj.id } }),
      getAdminDetail: (obj) => ({ name: 'manage.library.artists.detail', params: { id: obj.id } })
    },
    moderatedFields: [
      name,
      creationDate,
      tags,
      musicBrainzId
    ]
  },
  album: {
    label: $pgettext('*/*/*', 'Album'),
    icon: 'play',
    getDeleteUrl: (obj) => {
      return `manage/library/albums/${obj.id}/`
    },
    urls: {
      getDetail: (obj) => ({ name: 'library.albums.detail', params: { id: obj.id } }),
      getAdminDetail: (obj) => ({ name: 'manage.library.albums.detail', params: { id: obj.id } })
    },
    moderatedFields: [
      {
        id: 'title',
        label: $pgettext('*/*/*/Noun', 'Title')
      },
      creationDate,
      {
        id: 'release_date',
        label: $pgettext('Content/*/*/Noun', 'Release date')
      },
      tags,
      musicBrainzId
    ]
  },
  track: {
    label: $pgettext('*/*/*/Noun', 'Track'),
    icon: 'music',
    getDeleteUrl: (obj) => {
      return `manage/library/tracks/${obj.id}/`
    },
    urls: {
      getDetail: (obj) => ({ name: 'library.tracks.detail', params: { id: obj.id } }),
      getAdminDetail: (obj) => ({ name: 'manage.library.tracks.detail', params: { id: obj.id } })
    },
    moderatedFields: [
      {
        id: 'title',
        label: $pgettext('*/*/*/Noun', 'Title')
      },
      {
        id: 'position',
        label: $pgettext('*/*/*/Short, Noun', 'Position')
      },
      {
        id: 'copyright',
        label: $pgettext('Content/Track/*/Noun', 'Copyright')
      },
      {
        id: 'license',
        label: $pgettext('Content/*/*/Noun', 'License')
      },
      tags,
      musicBrainzId
    ]
  },
  library: {
    label: $pgettext('*/*/*/Noun', 'Library'),
    icon: 'book',
    getDeleteUrl: (obj) => {
      return `manage/library/libraries/${obj.uuid}/`
    },
    urls: {
      getAdminDetail: (obj) => ({ name: 'manage.library.libraries.detail', params: { id: obj.uuid } })
    },
    moderatedFields: [
      name,
      {
        id: 'description',
        label: $pgettext('*/*/*/Noun', 'Description')
      },
      visibility
    ]
  },
  playlist: {
    label: $pgettext('*/*/*', 'Playlist'),
    icon: 'list',
    urls: {
      getDetail: (obj) => ({ name: 'library.playlists.detail', params: { id: obj.id } })
      // getAdminDetail: (obj) => ({name: 'manage.playlists.detail', params: {id: obj.id}}}
    },
    moderatedFields: [
      name,
      visibility
    ]
  },
  account: {
    label: $pgettext('*/*/*/Noun', 'Account'),
    icon: 'user',
    urls: {
      getDetail: (obj) => ({ name: 'profile.full.overview', params: { username: obj.preferred_username, domain: obj.domain } }),
      getAdminDetail: (obj) => ({ name: 'manage.moderation.accounts.detail', params: { id: `${obj.preferred_username}@${obj.domain}` } })
    },
    moderatedFields: [
      name,
      {
        id: 'summary',
        label: $pgettext('*/*/*/Noun', 'Bio')
      }
    ]
  },
  channel: {
    label: $pgettext('*/*/*', 'Channel'),
    icon: 'stream',
    urls: {
      getDetail: (obj) => ({ name: 'channels.detail', params: { id: obj.uuid } }),
      getAdminDetail: (obj) => ({ name: 'manage.channels.detail', params: { id: obj.uuid } })
    },
    moderatedFields: [
      name,
      creationDate,
      tags
    ]
  }
})
