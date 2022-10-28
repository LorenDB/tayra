import LRU from 'lru-cache'
import { reactive } from 'vue'

export default <T, K>(options: LRU.Options<T, K>) => {
  const cache = new LRU(options)

  // @ts-expect-error keyMap is used internally so it is not defined in the types
  cache.keyMap = reactive(cache.keyMap)

  return cache
}
