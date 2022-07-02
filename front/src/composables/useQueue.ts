import { useTimeoutFn, useThrottleFn } from "@vueuse/core"
import { useTimeAgo, useNow } from '@vueuse/core'
import { useGettext } from "vue3-gettext"
import { useStore } from "~/store"
import { ref, computed } from "vue"
import { Track } from "~/types"
import { sum } from 'lodash-es'

export default () => {
  const store = useStore()
  const { $pgettext } = useGettext()

  const currentTrack = computed(() => store.getters['queue/currentTrack'])
  const currentIndex = computed(() => store.state.queue.currentIndex)
  const hasNext = computed(() => store.getters['queue/hasNext'])
  const isEmpty = computed(() => store.getters['queue/isEmpty'])

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
    hasNext,
    isEmpty,

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