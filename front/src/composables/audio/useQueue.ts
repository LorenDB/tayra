import { useTimeAgo, useNow } from '@vueuse/core'
import { gettext } from '~/init/locale'
import { computed } from 'vue'
import { sum } from 'lodash-es'
import store from '~/store'

const currentIndex = computed(() => store.state.queue.currentIndex)
const currentTrack = computed(() => store.state.queue.tracks[currentIndex.value])
const hasNext = computed(() => store.getters['queue/hasNext'])
const hasPrevious = computed(() => store.getters['queue/hasPrevious'])
const tracks = computed(() => store.state.queue.tracks)
const isShuffling = computed(() => !!store.state.queue.shuffleAbortController)
const isShuffled = computed(() => !!store.state.queue.unshuffled.length)
const isEmpty = computed(() => tracks.value.length === 0)
const clear = () => store.dispatch('queue/clean')
const removeTrack = (index: number) => store.dispatch('queue/cleanTrack', index)
const reorder = (oldIndex: number, newIndex: number) => {
  store.commit('queue/reorder', {
    oldIndex,
    newIndex
  })
}

//
// Shuffle
const { $pgettext } = gettext
const shuffle = async () => {
  await store.dispatch('queue/shuffle')
  store.commit('ui/addMessage', {
    content: $pgettext('Content/Queue/Message', 'Queue shuffled!'),
    date: new Date()
  })
}

const unshuffle = async () => {
  await store.dispatch('queue/unshuffle')
  store.commit('ui/addMessage', {
    content: $pgettext('Content/Queue/Message', 'Queue order restored!'),
    date: new Date()
  })
}

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

export default () => ({
  currentIndex,
  currentTrack,
  hasNext,
  hasPrevious,
  tracks,
  isEmpty,
  shuffle,
  unshuffle,
  isShuffling,
  isShuffled,
  endsIn,
  clear,
  removeTrack,
  reorder
})
