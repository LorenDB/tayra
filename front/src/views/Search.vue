<script setup lang="ts">
import type { RadioConfig } from '~/store/radios'

import { ref, reactive, computed, watch } from 'vue'
import { useRouteQuery } from '@vueuse/router'
import { useGettext } from 'vue3-gettext'
import { syncRef } from '@vueuse/core'

import axios from 'axios'

import PlaylistCardList from '~/components/playlists/CardList.vue'
import RemoteSearchForm from '~/components/RemoteSearchForm.vue'
import ArtistCard from '~/components/audio/artist/Card.vue'
import TrackTable from '~/components/audio/track/Table.vue'
import AlbumCard from '~/components/audio/album/Card.vue'
import Pagination from '~/components/vui/Pagination.vue'
import RadioButton from '~/components/radios/Button.vue'
import RadioCard from '~/components/radios/Card.vue'
import TagsList from '~/components/tags/List.vue'

import useErrorHandler from '~/composables/useErrorHandler'

type QueryType = 'artists' | 'albums' | 'tracks' | 'playlists' | 'tags' | 'radios' | 'podcasts' | 'series' | 'rss'

const type = useRouteQuery<QueryType>('type', 'artists')
const id = useRouteQuery<string>('id')

const pageQuery = useRouteQuery<string>('page', '1')
const page = ref(+pageQuery.value)
syncRef(pageQuery, page, {
  transform: {
    ltr: (left) => +left,
    rtl: (right) => right.toString()
  }
})

const q = useRouteQuery('q', '')
const query = ref(q.value)
syncRef(q, query, { direction: 'ltr' })

type ResponseType = { count: number, results: any[] }
const results = reactive({
  artists: null,
  albums: null,
  tracks: null,
  playlists: null,
  radios: null,
  tags: null,
  podcasts: null,
  series: null
} as Record<QueryType, null | ResponseType>)

const paginateBy = ref(25)

const { $pgettext } = useGettext()

interface SearchType {
  id: QueryType
  label: string
  includeChannels?: boolean
  contentCategory?: string
  endpoint?: string
}

const types = computed(() => [
  {
    id: 'artists',
    label: $pgettext('*/*/*/Noun', 'Artists'),
    includeChannels: true,
    contentCategory: 'music'
  },
  {
    id: 'albums',
    label: $pgettext('*/*/*', 'Albums'),
    includeChannels: true,
    contentCategory: 'music'
  },
  {
    id: 'tracks',
    label: $pgettext('*/*/*', 'Tracks')
  },
  {
    id: 'playlists',
    label: $pgettext('*/*/*', 'Playlists')
  },
  {
    id: 'radios',
    label: $pgettext('*/*/*', 'Radios'),
    endpoint: 'radios/radios'
  },
  {
    id: 'tags',
    label: $pgettext('*/*/*', 'Tags')
  },
  {
    id: 'podcasts',
    label: $pgettext('*/*/*', 'Podcasts'),
    endpoint: '/artists',
    contentCategory: 'podcast',
    includeChannels: true
  },
  {
    id: 'series',
    label: $pgettext('*/*/*', 'Series'),
    endpoint: '/albums',
    includeChannels: true,
    contentCategory: 'podcast'
  }
] as SearchType[])

const currentType = computed(() => types.value.find(({ id }) => id === type.value))

const axiosParams = computed(() => {
  const params = new URLSearchParams({
    q: query.value,
    page: page.value as unknown as string,
    page_size: paginateBy.value as unknown as string
  })

  if (currentType.value?.contentCategory) params.append('content_category', currentType.value.contentCategory)
  if (currentType.value?.includeChannels) params.append('include_channels', currentType.value.includeChannels as unknown as string)

  return params
})

const currentResults = computed(() => results[currentType.value?.id ?? 'artists'])

const isLoading = ref(false)
const search = async () => {
  if (!currentType.value) return

  q.value = query.value

  if (!query.value) {
    for (const type of types.value) {
      results[type.id] = null
    }

    return
  }

  isLoading.value = true

  try {
    const response = await axios.get(currentType.value.endpoint ?? currentType.value.id, {
      params: axiosParams.value
    })

    results[currentType.value.id] = response.data
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoading.value = false

  // TODO (wvffle): Resolve race condition
  for (const type of types.value) {
    if (type.id !== currentType.value.id) {
      axios.get(type.endpoint ?? type.id, {
        params: {
          q: query.value,
          page_size: 1,
          content_category: type.contentCategory,
          include_channels: type.includeChannels
        }
      }).then(response => {
        results[type.id] = response.data
      }).catch(() => undefined)
    }
  }
}

watch(type, () => {
  page.value = 1
  search()
})

search()

const labels = computed(() => ({
  title: id.value
    ? (
        type.value === 'rss'
          ? $pgettext('Head/Fetch/Title', 'Subscribe to a podcast RSS feed')
          : $pgettext('Head/Fetch/Title', 'Search a remote object')
      )
    : $pgettext('Content/Search/Input.Label/Noun', 'Search'),
  submitSearch: $pgettext('Content/Search/Button.Label/Verb', 'Submit Search Query')
}))

const radioConfig = computed(() => {
  const results = Object.values(currentResults.value?.results ?? {})
  if (results.length) {
    if (currentType.value?.id === 'tags') {
      return {
        type: 'tag',
        names: results.map(({ name }) => name)
      } as RadioConfig
    }

    if (currentType.value?.id === 'artists') {
      return {
        type: 'artist',
        ids: results.map(({ id }) => id)
      } as RadioConfig
    }

    // TODO (wvffle): Use logger
    console.info('This type is not yet supported for radio')
  }

  return null
})
</script>

<template>
  <main
    v-title="labels.title"
    class="main pusher"
  >
    <section class="ui vertical stripe segment">
      <div
        v-if="id"
        class="ui small text container"
      >
        <h2>{{ labels.title }}</h2>
        <remote-search-form
          :initial-id="id"
          :type="type"
        />
      </div>
      <div
        v-else
        class="ui container"
      >
        <h2>
          <label for="query">
            <translate translate-context="Content/Search/Input.Label/Noun">Search</translate>
          </label>
        </h2>
        <div class="ui two column doubling stackable grid container">
          <div class="column">
            <form
              class="ui form"
              @submit.prevent="page = 1; search()"
            >
              <div class="ui field">
                <div class="ui action input">
                  <input
                    id="query"
                    v-model="query"
                    class="ui input"
                    name="query"
                    type="text"
                  >
                  <button
                    :aria-label="labels.submitSearch"
                    type="submit"
                    class="ui icon button"
                  >
                    <i class="search icon" />
                  </button>
                </div>
              </div>
            </form>
          </div>
          <div class="column">
            <radio-button
              v-if="radioConfig"
              class="ui right floated medium button"
              type="custom_multiple"
              :radio-config="radioConfig"
            />
          </div>
        </div>
        <div class="ui secondary pointing menu">
          <a
            v-for="t in types"
            :key="t.id"
            :class="['item', {active: type === t.id}]"
            href=""
            @click.prevent="type = t.id"
          >
            {{ t.label }}
            <span
              v-if="results[t.id]"
              class="ui circular mini right floated label"
            >
              {{ results[t.id]?.count ?? 0 }}
            </span>
          </a>
        </div>
        <div v-if="isLoading">
          <div
            v-if="isLoading"
            class="ui inverted active dimmer"
          >
            <div class="ui loader" />
          </div>
        </div>

        <empty-state
          v-else-if="!currentResults || currentResults.count === 0"
          :refresh="true"
          @refresh="search"
        />

        <div
          v-else-if="type === 'artists' || type === 'podcasts'"
          class="ui five app-cards cards"
        >
          <artist-card
            v-for="artist in currentResults.results"
            :key="artist.id"
            :artist="artist"
          />
        </div>

        <div
          v-else-if="type === 'albums' || type === 'series'"
          class="ui five app-cards cards"
        >
          <album-card
            v-for="album in currentResults.results"
            :key="album.id"
            :album="album"
          />
        </div>
        <track-table
          v-else-if="type === 'tracks'"
          :tracks="currentResults.results"
        />
        <playlist-card-list
          v-else-if="type === 'playlists'"
          :playlists="currentResults.results"
        />
        <div
          v-else-if="type === 'radios'"
          class="ui cards"
        >
          <radio-card
            v-for="radio in currentResults.results"
            :key="radio.id"
            type="custom"
            :custom-radio="radio"
          />
        </div>
        <tags-list
          v-else-if="type === 'tags'"
          :truncate-size="200"
          :limit="paginateBy"
          :tags="currentResults.results.map(t => {return t.name })"
        />

        <pagination
          v-if="currentResults && currentResults.count > paginateBy"
          v-model:current="page"
          :paginate-by="paginateBy"
          :total="currentResults.count"
        />
      </div>
    </section>
  </main>
</template>
