import { InitModule } from '~/types'
import { Howl } from 'howler'

export const install: InitModule = ({ app }) => {
  // TODO (wvffle): Check if it is needed

  // this is needed to unlock audio playing under some browsers,
  // cf https://github.com/goldfire/howler.js#mobilechrome-playback
  // but we never actually load those audio files
  const dummyAudio = new Howl({
    preload: false,
    autoplay: false,
    src: ['noop.webm', 'noop.mp3']
  })

  return dummyAudio
}
