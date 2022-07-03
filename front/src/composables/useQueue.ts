import { useTimeoutFn, useThrottleFn, useTimeAgo, useNow, whenever } from '@vueuse/core'
import { Howler } from 'howler'
import { gettext } from '~/init/locale'
import { ref, computed } from "vue"
import { Track } from "~/types"
import { sum } from 'lodash-es'
import store from "~/store"

const { $pgettext } = gettext

export default () => {
  const currentTrack = computed(() => store.getters['queue/currentTrack'])
  const currentIndex = computed(() => store.state.queue.currentIndex)
  const hasNext = computed(() => store.getters['queue/hasNext'])
  const hasPrevious = computed(() => store.getters['queue/hasPrevious'])

  const isEmpty = computed(() => store.getters['queue/isEmpty'])
  whenever(isEmpty, () => Howler.unload())

  const removeTrack = (index: number) => store.dispatch('queue/cleanTrack', index)
  const clear = () => store.dispatch('queue/clean')

  const next = () => store.dispatch('queue/next')
  const previous = () => store.dispatch('queue/previous')

  const focused = computed(() => store.state.ui.queueFocused === 'queue')

  // 
  // Track list
  //
  const tracksChangeBuffer = ref<Track[] | null>(null)
  const tracks = computed<Track[]>({
    get: () => store.state.queue.tracks,
    set: (value) => (tracksChangeBuffer.value = value)
  })

  const reorder = (oldIndex: number, newIndex: number) => {
    store.commit('queue/reorder', {
      tracks: tracksChangeBuffer.value ?? tracks.value,
      oldIndex,
      newIndex
    })

    tracksChangeBuffer.value = null
  }

  // 
  // Shuffle
  //
  const isShuffling = ref(false)

  const forceShuffle = useThrottleFn(() => {
    isShuffling.value = true

    useTimeoutFn(async () => {
      await store.dispatch('queue/shuffle')
      store.commit('ui/addMessage', {
        content: $pgettext('Content/Queue/Message', 'Queue shuffled!'),
        date: new Date()
      })

      isShuffling.value = false
    }, 100)
  })

  const shuffle = useThrottleFn(() => {
    if (isShuffling.value || isEmpty.value) {
      return
    }

    return forceShuffle()
  }, 101, false)

  //
  // Time left
  //
  const now = useNow()
  const endsIn = useTimeAgo(computed(() => {
    const seconds = sum(
      tracks.value
        .slice(currentIndex.value)
        .map((track) => track.uploads?.[0]?.duration ?? 0)
    )

    const date = new Date(now.value)
    date.setSeconds(date.getSeconds() + seconds)
    return date
  }))

  return { 
    currentTrack,
    currentIndex,
    hasNext,
    hasPrevious,
    isEmpty, 
    isShuffling,

    removeTrack,
    clear,
    next,
    previous,

    tracks,
    reorder,

    shuffle,
    forceShuffle,

    endsIn,
    focused
  }
}