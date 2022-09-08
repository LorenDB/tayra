import type { Track, Artist, Album, Playlist, Library, Channel, Actor } from '~/types'

import { i18n } from '~/init/locale'

import store from '~/store'

const { t } = i18n.global

interface Objects {
  track?: Track | null
  album?: Album | null
  artist?: Artist | null
  playlist?: Playlist | null
  account?: Actor | null
  library?: Library | null
  channel?: Channel | null
}

interface ReportableObject {
  label: string,
  target: {
    type: keyof Objects
    label: string
    typeLabel: string
    _obj: Objects[keyof Objects]

    full_username?: string
    id?: number
    uuid?: string
  }
}

const getReportableObjects = ({ track, album, artist, playlist, account, library, channel }: Objects) => {
  const reportableObjs: ReportableObject[] = []

  if (account) {
    reportableObjs.push({
      label: t('Report @%{ username }…', { username: account.preferred_username }),
      target: {
        type: 'account',
        _obj: account,
        full_username: account.full_username,
        label: account.full_username,
        typeLabel: t('Account')
      }
    })
  }

  if (track) {
    reportableObjs.push({
      label: t('Report this track…'),
      target: {
        type: 'track',
        id: track.id,
        _obj: track,
        label: track.title,
        typeLabel: t('Track')
      }
    })

    album = track.album
    artist = track.artist
  }

  if (album) {
    reportableObjs.push({
      label: t('Report this album…'),
      target: {
        type: 'album',
        id: album.id,
        label: album.title,
        _obj: album,
        typeLabel: t('Album')
      }
    })

    if (!artist) {
      artist = album.artist
    }
  }

  if (channel) {
    reportableObjs.push({
      label: t('Report this channel…'),
      target: {
        type: 'channel',
        uuid: channel.uuid,
        label: channel.artist?.name ?? t('Unknown artist'),
        _obj: channel,
        typeLabel: t('Channel')
      }
    })
  } else if (artist) {
    reportableObjs.push({
      label: t('Report this artist…'),
      target: {
        type: 'artist',
        id: artist.id,
        label: artist.name,
        _obj: artist,
        typeLabel: t('Artist')
      }
    })
  }

  if (playlist) {
    reportableObjs.push({
      label: t('Report this playlist…'),
      target: {
        type: 'playlist',
        id: playlist.id,
        label: playlist.name,
        _obj: playlist,
        typeLabel: t('Playlist')
      }
    })
  }

  if (library) {
    reportableObjs.push({
      label: t('Report this library…'),
      target: {
        type: 'library',
        uuid: library.uuid,
        label: library.name,
        _obj: library,
        typeLabel: t('Library')
      }
    })
  }

  return reportableObjs
}

const report = (obj: ReportableObject) => {
  store.dispatch('moderation/report', obj.target)
}

export default () => ({
  getReportableObjects,
  report
})
