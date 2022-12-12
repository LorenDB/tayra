import type { EntityObjectType } from '~/types'
import type { RouteLocationRaw } from 'vue-router'

import { i18n } from '~/init/locale'

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

export default (): Configs => {
  const { t } = i18n.global

  const tags: ModeratedField = {
    id: 'tags',
    label: t('composables.moderation.useReportConfigs.tags.label'),
    getValueRepr: (tags: string[]) => tags.slice().sort().join('\n')
  }

  const name: ModeratedField = {
    id: 'name',
    label: t('composables.moderation.useReportConfigs.name.label')
  }

  const creationDate: ModeratedField = {
    id: 'creation_date',
    label: t('composables.moderation.useReportConfigs.creationDate.label')
  }

  const musicBrainzId: ModeratedField = {
    id: 'mbid',
    label: t('composables.moderation.useReportConfigs.musicbrainzId.label')
  }

  const visibility: ModeratedField = {
    id: 'privacy_level',
    label: t('composables.moderation.useReportConfigs.visibility.label')
  }

  return {
    artist: {
      label: t('composables.moderation.useReportConfigs.artist.label'),
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
      label: t('composables.moderation.useReportConfigs.album.label'),
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
          label: t('composables.moderation.useReportConfigs.album.title')
        },
        creationDate,
        {
          id: 'release_date',
          label: t('composables.moderation.useReportConfigs.album.releaseDate')
        },
        tags,
        musicBrainzId
      ]
    },
    track: {
      label: t('composables.moderation.useReportConfigs.track.label'),
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
          label: t('composables.moderation.useReportConfigs.track.title')
        },
        {
          id: 'position',
          label: t('composables.moderation.useReportConfigs.track.position')
        },
        {
          id: 'copyright',
          label: t('composables.moderation.useReportConfigs.track.copyright')
        },
        {
          id: 'license',
          label: t('composables.moderation.useReportConfigs.track.license')
        },
        tags,
        musicBrainzId
      ]
    },
    library: {
      label: t('composables.moderation.useReportConfigs.library.label'),
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
          label: t('composables.moderation.useReportConfigs.library.description')
        },
        visibility
      ]
    },
    playlist: {
      label: t('composables.moderation.useReportConfigs.playlist.label'),
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
      label: t('composables.moderation.useReportConfigs.account.label'),
      icon: 'user',
      urls: {
        getDetail: (obj) => ({ name: 'profile.full.overview', params: { username: obj.preferred_username, domain: obj.domain } }),
        getAdminDetail: (obj) => ({ name: 'manage.moderation.accounts.detail', params: { id: `${obj.preferred_username}@${obj.domain}` } })
      },
      moderatedFields: [
        name,
        {
          id: 'summary',
          label: t('composables.moderation.useReportConfigs.account.summary')
        }
      ]
    },
    channel: {
      label: t('composables.moderation.useReportConfigs.channel.label'),
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
  }
}
