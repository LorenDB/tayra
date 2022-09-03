import type { Token } from '~/utils/search'

import { compileTokens, normalizeQuery, parseTokens } from '~/utils/search'
import { refWithControl } from '@vueuse/core'
import { computed, ref, watch } from 'vue'
import { useRouter } from 'vue-router'

export interface SmartSearchProps {
  defaultQuery?: string
  updateUrl?: boolean
}

export default (props: SmartSearchProps) => {
  const query = refWithControl(props.defaultQuery ?? '')
  const tokens = ref([] as Token[])

  watch(query, (value) => {
    tokens.value = parseTokens(normalizeQuery(value))
  }, { immediate: true })

  const updateHandlers = new Set<() => void>()
  const onSearch = (fn: () => void) => {
    updateHandlers.add(fn)
    return () => updateHandlers.delete(fn)
  }

  const router = useRouter()
  watch(tokens, (value) => {
    const newQuery = compileTokens(value)
    if (props.updateUrl) {
      return router.replace({ query: { q: newQuery } })
    }

    // TODO (wvffle): updateUrl = false only in FilesTable.vue
    query.set(newQuery, false)
    for (const handler of updateHandlers) {
      handler()
    }
    // this.page = 1
    // this.fetchData()
  }, { deep: true })

  const getTokenValue = (key: string, fallback: string) => {
    const matching = tokens.value.find(token => {
      return token.field === key
    })

    return matching?.value ?? fallback
  }

  const addSearchToken = (key: string, value: string) => {
    if (value === '') {
      tokens.value = tokens.value.filter(token => {
        return token.field !== key
      })

      return
    }

    const existing = tokens.value.filter(token => {
      return token.field === key
    })

    if (!existing.length) {
      tokens.value.push({ field: key, value })
      return
    }

    for (const token of existing) {
      token.value = value
    }
  }

  return {
    getTokenValue,
    addSearchToken,
    onSearch,
    query: computed({
      get: () => compileTokens(tokens.value),
      set: (value: string) => query.set(value, true)
    })
  }
}
