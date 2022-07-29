import type { Howl } from 'howler'

import { sortBy } from 'lodash-es'
import { reactive, watchEffect, ref } from 'vue'

const MAX_PRELOADED = 3

export interface CachedSound {
  id: string
  date: Date
  howl: Howl
}

const soundCache = reactive(new Map<string, CachedSound>())
const cleaningCache = ref(false)

watchEffect(() => {
  const toRemove = soundCache.size - MAX_PRELOADED

  if (toRemove > 0 && !cleaningCache.value) {
    cleaningCache.value = true

    const excess = sortBy([...soundCache.values()], [(cached: CachedSound) => cached.date])
      .slice(0, toRemove)

    for (const cached of excess) {
      console.log('Removing cached element:', cached)
      soundCache.delete(cached.id)
      cached.howl.unload()
    }

    cleaningCache.value = false
  }
})

export default () => {
  return soundCache
}
