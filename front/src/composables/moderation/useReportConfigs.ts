import type { EntityObjectType } from '~/types'
import type { RouteLocationRaw } from 'vue-router'

import { useI18n } from 'vue-i18n'

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

type Configs = Record<EntityObjectType, Entity>

const { t } = useI18n()

const tags: ModeratedField = {
  id: 'tags',
  label: t('Tags'),
  getValueRepr: (tags: string[]) => tags.slice().sort().join('\n')
}

const name: ModeratedField = {
  id: 'name',
  label: t('Name')
}

const creationDate: ModeratedField = {
  id: 'creation_date',
  label: t('Creation date')
}

const musicBrainzId: ModeratedField = {
  id: 'mbid',
  label: t('MusicBrainz ID')
}

const visibility: ModeratedField = {
  id: 'privacy_level',
  label: t('Visibility')
}

export default (): Configs => ({
  artist: {
    label: t('Artist'),
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
    label: t('Album'),
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
        label: t('Title')
      },
      creationDate,
      {
        id: 'release_date',
        label: t('Release date')
      },
      tags,
      musicBrainzId
    ]
  },
  track: {
    label: t('Track'),
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
        label: t('Title')
      },
      {
        id: 'position',
        label: t('Position')
      },
      {
        id: 'copyright',
        label: t('Copyright')
      },
      {
        id: 'license',
        label: t('License')
      },
      tags,
      musicBrainzId
    ]
  },
  library: {
    label: t('Library'),
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
        label: t('Description')
      },
      visibility
    ]
  },
  playlist: {
    label: t('Playlist'),
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
    label: t('Account'),
    icon: 'user',
    urls: {
      getDetail: (obj) => ({ name: 'profile.full.overview', params: { username: obj.preferred_username, domain: obj.domain } }),
      getAdminDetail: (obj) => ({ name: 'manage.moderation.accounts.detail', params: { id: `${obj.preferred_username}@${obj.domain}` } })
    },
    moderatedFields: [
      name,
      {
        id: 'summary',
        label: t('Bio')
      }
    ]
  },
  channel: {
    label: t('Channel'),
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
