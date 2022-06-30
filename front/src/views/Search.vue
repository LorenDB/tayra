<script setup lang="ts">
import type { RadioConfig } from '~/store/radios'

import RemoteSearchForm from '~/components/RemoteSearchForm.vue'
import ArtistCard from '~/components/audio/artist/Card.vue'
import AlbumCard from '~/components/audio/album/Card.vue'
import TrackTable from '~/components/audio/track/Table.vue'
import Pagination from '~/components/vui/Pagination.vue'
import PlaylistCardList from '~/components/playlists/CardList.vue'
import RadioCard from '~/components/radios/Card.vue'
import TagsList from '~/components/tags/List.vue'
import { ref, reactive, computed, watch } from 'vue'
import { useRouter, onBeforeRouteUpdate } from 'vue-router'
import { useGettext } from 'vue3-gettext'
import axios from 'axios'

type QueryType = 'artists' | 'albums' | 'tracks' | 'playlists' | 'tags' | 'radios' | 'podcasts' | 'series' | 'rss'

interface Props {
  initialId?: string
  initialType?: QueryType
  initialQuery?: string
  initialPage?: number
}

const props = withDefaults(defineProps<Props>(), {
  initialId: '',
  initialType: 'artists',
  initialQuery: '',
  initialPage: 1
})

const query = ref(props.initialQuery)
const type = ref(props.initialType)
const page = ref(props.initialPage)

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

// TODO (wvffle): Check if can rename to Category
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

const currentType = computed(() => types.value.find(({ id }) => id === type.value)!)

const axiosParams = computed(() => {
  const params = new URLSearchParams({
    q: query.value,
    page: page.value as unknown as string,
    page_size: paginateBy.value as unknown as string
  })

  if (currentType.value.contentCategory) params.append('content_category', currentType.value.contentCategory)
  if (currentType.value.includeChannels) params.append('include_channels', currentType.value.includeChannels as unknown as string)

  return params
})

const currentResults = computed(() => results[currentType.value.id ?? 'artists'])

const router = useRouter()
const updateQueryString = () => router.replace({
  query: {
    q: query.value,
    page: page.value,
    type: type.value
  }
})

// TODO (wvffle): Debounce all `fetchData` functions
const isLoading = ref(false)
const search = async () => {
  if (!query.value) {
    for (const type of types.value) {
      results[type.id] = null
    }

    return
  }

  isLoading.value = true
  const response = await axios.get(currentType.value.endpoint ?? currentType.value.id, {
    params: axiosParams.value
  })

  results[currentType.value.id] = response.data

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
      })
    }
  }
}

watch(type, () => (page.value = 1))
watch(page, updateQueryString)

onBeforeRouteUpdate(search)

// TODO: (wvffle): Check if it's needed
// watch: {
//   '$route.query.q': async function (v) {
//     this.query = v
//   }
// },

const labels = computed(() => ({
  title: props.initialId
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
    if (currentType.value.id === 'tags') {
      return {
        type: 'tag',
        names: results.map(({ name }) => name)
      } as RadioConfig
    }

    if (currentType.value.id === 'artists') {
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
        v-if="initialId"
        class="ui small text container"
      >
        <h2>{{ labels.title }}</h2>
        <remote-search-form
          :initial-id="initialId"
          :type="initialType"
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
              {{ results[t.id].count }}</span>
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
          :current="page"
          :paginate-by="paginateBy"
          :total="currentResults.count"
          @page-changed="page = $event"
        />
      </div>
    </section>
  </main>
</template>
