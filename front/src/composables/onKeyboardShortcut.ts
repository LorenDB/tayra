import { DefaultMagicKeysAliasMap, tryOnScopeDispose, useActiveElement, useEventListener } from '@vueuse/core'
import { computed, reactive } from 'vue'
import { isEqual, isMatch } from 'lodash-es'

type KeyFilter = string | string[]

interface Entry {
  handler: () => unknown,
  prevent: boolean,
  __location?: string
}

const combinations = reactive(new Map())
const activeElement = useActiveElement()
const bodyIsActive = computed(() => activeElement.value === document.body)

const current = new Set()
useEventListener(window, 'keydown', (event) => {
  if (!bodyIsActive.value && !event.key) return
  current.add(event.key.toLowerCase())

  const currentArray = [...current]
  for (const [requiredKeys, { handler, prevent }] of combinations.entries()) {
    if (isEqual(currentArray, requiredKeys)) {
      if (prevent) event.preventDefault()
      handler()
    }
  }
})

useEventListener(window, 'keyup', (event) => {
  if (!event.key) {
    current.delete(event.key.toLowerCase())
  }
})

export default (key: KeyFilter, handler: () => unknown, prevent = false) => {
  const combination = (Array.isArray(key) ? key : [key as string]).map(key => {
    return DefaultMagicKeysAliasMap[key] ?? key
  })

  const entry: Entry = { prevent, handler }

  if (import.meta.env.DEV) {
    entry.__location = new Error().stack?.split('\n', 2).pop()
      // TODO: Get correct line number somehow?
      //       Currently $3 is a line number that should work in .ts files,
      //       though in .vue files we need to get the line of the script plus
      //       the position of <script> tag in SFC
      ?.replace(/^(.+?)@.+\/(.+\..+?)(?:\?.+?|):(\d+):.+$/, 'Method $1 in $2')

    // NOTE: Inform about possible combination collision
    for (const [keys, { __location }] of combinations.entries()) {
      const collisions = []
      if (isMatch(keys, combination) || isMatch(combination, keys)) {
        collisions.push(`${__location}: ${keys.join(' + ')}`)
      }

      if (collisions.length) {
        console.warn([
          'onKeyboardShortcut detected a possible collision in:',
          `${entry.__location}: ${combination.join(' + ')}`,
          ...collisions
        ].join('\n'))
      }
    }
  }

  combinations.set(combination, entry)

  const stop = () => combinations.delete(combination)
  tryOnScopeDispose(stop)
  return stop
}
