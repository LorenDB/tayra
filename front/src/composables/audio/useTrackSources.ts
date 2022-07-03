import { Track } from "~/types"
import store from '~/store'
import updateQueryString from '~/composables/updateQueryString'

export interface TrackSource {
  url: string 
  type: string
}

export default (trackData: Track): TrackSource[] => {
  const audio = document.createElement('audio')

  const allowed = ['probably', 'maybe']

  const sources = trackData.uploads
    .filter(upload => {
      const canPlay = audio.canPlayType(upload.mimetype)
      return allowed.indexOf(canPlay) > -1
    })
    .map(upload => ({
      type: upload.extension,
      url: store.getters['instance/absoluteUrl'](upload.listen_url)
    }))

  // We always add a transcoded MP3 src at the end
  // because transcoding is expensive, but we want browsers that do
  // not support other codecs to be able to play it :)
  sources.push({
    type: 'mp3',
    url: updateQueryString(
      store.getters['instance/absoluteUrl'](trackData.listen_url), 
      'to', 
      'mp3'
    )
  })

  const token = store.state.auth.scopedTokens.listen
  if (store.state.auth.authenticated && token !== null) {
      // we need to send the token directly in url
      // so authentication can be checked by the backend
      // because for audio files we cannot use the regular Authentication
      // header
      return sources.map(source => ({
        ...source,
        url: updateQueryString(source.url, 'token', token)
      }))
  }

  return sources
}