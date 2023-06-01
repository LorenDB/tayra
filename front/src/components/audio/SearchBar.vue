<script setup lang="ts">
import type { Artist, Track, Album, Tag } from '~/types'
import type { RouteRecordName, RouteLocationNamedRaw } from 'vue-router'

import jQuery from 'jquery'
import { trim } from 'lodash-es'
import { useFocus, useCurrentElement } from '@vueuse/core'
import { ref, computed, onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import { useStore } from '~/store'

import onKeyboardShortcut from '~/composables/onKeyboardShortcut'

interface Events {
  (e: 'search'): void
}

type CategoryCode = 'federation' | 'podcasts' | 'artists' | 'albums' | 'tracks' | 'tags' | 'more'
interface Category {
  code: CategoryCode,
  name: string,
  route: RouteRecordName
  getId: (obj: unknown) => number
  getTitle: (obj: unknown) => string
  getDescription: (obj: unknown) => string
}

type SimpleCategory = Partial<Category> & Pick<Category, 'code' | 'name'>
const isCategoryGuard = (object: Category | SimpleCategory): object is Category => typeof object.route === 'string'

interface Results {
  name: string,
  results: Result[]
}

interface Result {
  title: string
  id?: number
  description?: string
  routerUrl: RouteLocationNamedRaw
}

const emit = defineEmits<Events>()

const search = ref()
const { focused } = useFocus(search)
onKeyboardShortcut(['shift', 'f'], () => (focused.value = true), true)
onKeyboardShortcut(['ctrl', 'k'], () => (focused.value = true), true)

const { t } = useI18n()
const labels = computed(() => ({
  placeholder: t('components.audio.SearchBar.placeholder.search'),
  searchContent: t('components.audio.SearchBar.label.search'),
  artist: t('components.audio.SearchBar.label.artist'),
  album: t('components.audio.SearchBar.label.album'),
  track: t('components.audio.SearchBar.label.track'),
  tag: t('components.audio.SearchBar.label.tag')
}))

const router = useRouter()
const store = useStore()
const el = useCurrentElement()
const query = ref()

const enter = () => {
  jQuery(el.value).search('cancel query')

  // Cancel any API search request to backend…
  return router.push(`/search?q=${query.value}&type=artists`)
}

const blur = () => {
  search.value.blur()
}

const categories = computed(() => [
  {
    code: 'federation',
    name: t('components.audio.SearchBar.label.category.federation')
  },
  {
    code: 'podcasts',
    name: t('components.audio.SearchBar.label.category.podcasts')
  },
  {
    code: 'artists',
    route: 'library.artists.detail',
    name: labels.value.artist,
    getId: (obj: Artist) => obj.id,
    getTitle: (obj: Artist) => obj.name,
    getDescription: () => ''
  },
  {
    code: 'albums',
    route: 'library.albums.detail',
    name: labels.value.album,
    getId: (obj: Album) => obj.id,
    getTitle: (obj: Album) => obj.title,
    getDescription: (obj: Album) => obj.artist.name
  },
  {
    code: 'tracks',
    route: 'library.tracks.detail',
    name: labels.value.track,
    getId: (obj: Track) => obj.id,
    getTitle: (obj: Track) => obj.title,
    getDescription: (obj: Track) => obj.album?.artist.name ?? obj.artist?.name ?? ''
  },
  {
    code: 'tags',
    route: 'library.tags.detail',
    name: labels.value.tag,
    getId: (obj: Tag) => obj.name,
    getTitle: (obj: Tag) => `#${obj.name}`,
    getDescription: (obj: Tag) => ''
  },
  {
    code: 'more',
    name: ''
  }
] as (Category | SimpleCategory)[])

const objectId = computed(() => {
  const trimmedQuery = trim(trim(query.value), '@')

  if (trimmedQuery.startsWith('http://') || trimmedQuery.startsWith('https://') || trimmedQuery.includes('@')) {
    return query.value
  }

  return null
})

onMounted(() => {
  jQuery(el.value).search({
    type: 'category',
    minCharacters: 3,
    showNoResults: true,
    error: {
      // @ts-expect-error Semantic is broken
      noResultsHeader: t('components.audio.SearchBar.header.noResults'),
      noResults: t('components.audio.SearchBar.empty.noResults')
    },

    onSelect (result, response) {
      jQuery(el.value).search('set value', query.value)
      router.push(result.routerUrl)
      jQuery(el.value).search('hide results')
      return false
    },
    onSearchQuery (value) {
      // query.value = value
      emit('search')
    },
    apiSettings: {
      url: store.getters['instance/absoluteUrl']('api/v1/search?query={query}'),
      beforeXHR: function (xhrObject) {
        if (!store.state.auth.authenticated) {
          return xhrObject
        }

        if (store.state.auth.oauth.accessToken) {
          xhrObject.setRequestHeader('Authorization', store.getters['auth/header'])
        }

        return xhrObject
      },
      onResponse: function (initialResponse) {
        const id = objectId.value
        const results: Partial<Record<CategoryCode, Results>> = {}

        let resultsEmpty = true
        for (const category of categories.value) {
          results[category.code] = {
            name: category.name,
            results: []
          }

          if (category.code === 'federation' && id) {
            resultsEmpty = false
            results[category.code]?.results.push({
              title: t('components.audio.SearchBar.link.fediverse'),
              routerUrl: {
                name: 'search',
                query: { id }
              }
            })
          }

          if (category.code === 'podcasts' && id) {
            resultsEmpty = false
            results[category.code]?.results.push({
              title: t('components.audio.SearchBar.link.rss'),
              routerUrl: {
                name: 'search',
                query: { id, type: 'rss' }
              }
            })
          }

          if (category.code === 'more') {
            results[category.code]?.results.push({
              title: t('components.audio.SearchBar.link.more'),
              routerUrl: {
                name: 'search',
                query: { type: 'artists', q: query.value }
              }
            })
          }

          if (isCategoryGuard(category)) {
            for (const result of initialResponse[category.code]) {
              resultsEmpty = false
              const id = category.getId(result)
              results[category.code]?.results.push({
                title: category.getTitle(result),
                id,
                routerUrl: {
                  name: category.route,
                  params: { id }
                },
                description: category.getDescription(result)
              })
            }
          }
        }

        return {
          results: resultsEmpty
            ? {}
            : results
        }
      }
    }
  })
})
</script>

<template>
  <div
    class="ui fluid category search"
    @keypress.enter="enter"
  >
    <slot />
    <div class="ui icon input">
      <input
        ref="search"
        v-model="query"
        :aria-label="labels.searchContent"
        type="search"
        class="prompt"
        name="search"
        :placeholder="labels.placeholder"
        @keydown.esc="blur"
      >
      <i class="search icon" />
    </div>
    <div class="results" />
    <slot name="after" />
  </div>
</template>
