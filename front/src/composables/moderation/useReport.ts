import type { Track, Artist, Album, Playlist, Library, Channel, Actor } from '~/types'

import { gettext } from '~/init/locale'
import store from '~/store'
const { $pgettext } = gettext

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
      label: $pgettext('*/Moderation/*/Verb', 'Report @%{ username }…', { username: account.preferred_username }),
      target: {
        type: 'account',
        _obj: account,
        full_username: account.full_username,
        label: account.full_username,
        typeLabel: $pgettext('*/*/*/Noun', 'Account')
      }
    })
  }

  if (track) {
    reportableObjs.push({
      label: $pgettext('*/Moderation/*/Verb', 'Report this track…'),
      target: {
        type: 'track',
        id: track.id,
        _obj: track,
        label: track.title,
        typeLabel: $pgettext('*/*/*/Noun', 'Track')
      }
    })

    album = track.album
    artist = track.artist
  }

  if (album) {
    reportableObjs.push({
      label: $pgettext('*/Moderation/*/Verb', 'Report this album…'),
      target: {
        type: 'album',
        id: album.id,
        label: album.title,
        _obj: album,
        typeLabel: $pgettext('*/*/*', 'Album')
      }
    })

    if (!artist) {
      artist = album.artist
    }
  }

  if (channel) {
    reportableObjs.push({
      label: $pgettext('*/Moderation/*/Verb', 'Report this channel…'),
      target: {
        type: 'channel',
        uuid: channel.uuid,
        label: channel.artist?.name ?? $pgettext('*/*/*', 'Unknown artist'),
        _obj: channel,
        typeLabel: $pgettext('*/*/*', 'Channel')
      }
    })
  } else if (artist) {
    reportableObjs.push({
      label: $pgettext('*/Moderation/*/Verb', 'Report this artist…'),
      target: {
        type: 'artist',
        id: artist.id,
        label: artist.name,
        _obj: artist,
        typeLabel: $pgettext('*/*/*/Noun', 'Artist')
      }
    })
  }

  if (playlist) {
    reportableObjs.push({
      label: $pgettext('*/Moderation/*/Verb', 'Report this playlist…'),
      target: {
        type: 'playlist',
        id: playlist.id,
        label: playlist.name,
        _obj: playlist,
        typeLabel: $pgettext('*/*/*', 'Playlist')
      }
    })
  }

  if (library) {
    reportableObjs.push({
      label: $pgettext('*/Moderation/*/Verb', 'Report this library…'),
      target: {
        type: 'library',
        uuid: library.uuid,
        label: library.name,
        _obj: library,
        typeLabel: $pgettext('*/*/*/Noun', 'Library')
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
