import { MaybeRef } from "@vueuse/core"
import { Howl } from "howler"
import { sortBy } from "lodash-es"
import { reactive, watchEffect, ref, unref } from "vue"

export interface CachedSound {
  id: string
  date: Date
  sound: Howl
}

export default (maxPreloaded: MaybeRef<number>) => {
  const soundCache = reactive(new Map<string, CachedSound>())
  const cleaningCache = ref(false)

  watchEffect(() => {
    let toRemove = soundCache.size - unref(maxPreloaded)

    if (toRemove > 0 && !cleaningCache.value) {
      cleaningCache.value = true

      const excess = sortBy([...soundCache.values()], [(cached: CachedSound) => cached.date])
        .slice(0, toRemove)

      for (const cached of excess) {
        console.log('Removing cached element:', cached)
        soundCache.delete(cached.id)
        cached.sound.unload()
      }

      cleaningCache.value = false
    }
  })

  return soundCache
}