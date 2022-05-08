<script setup lang="ts">
import qs from 'qs'
import axios from 'axios'
import $ from 'jquery'
import { onBeforeRouteUpdate, useRouter } from 'vue-router'
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { useGettext } from 'vue3-gettext'
import { OrderingField, RouteWithPreferences } from '~/store/ui'

import AlbumCard from '~/components/audio/album/Card.vue'
import Pagination from '~/components/vui/Pagination.vue'
import TagsSelector from '~/components/library/TagsSelector.vue'
import useLogger from '~/composables/useLogger'
import useSharedLabels from '~/composables/locale/useSharedLabels'
import useOrdering from '~/composables/useOrdering'
import { useStore } from '~/store'

interface Props {
  orderingConfigName: RouteWithPreferences | null
  defaultPage?: number
  defaultPaginateBy?: number
  defaultQuery?: string
  defaultTags?: string[]
  scope?: string
}

const props = withDefaults(defineProps<Props>(), {
  defaultPage: 1,
  defaultPaginateBy: 1,
  defaultQuery: '',
  defaultTags: () => [],
  scope: 'all'
})

// TODO (wvffle): Make sure everything is it's own type
const page = ref(+props.defaultPage)
type ResponseType = { count: number, results: any[] }
const result = ref<null | ResponseType>(null)
const query = ref('')
const tags = reactive(props.defaultTags.slice())

const orderingOptions: [OrderingField, keyof typeof sharedLabels.filters][] = [
  ['creation_date', 'creation_date'],
  ['title', 'album_title'],
  ['release_date', 'release_date']
]

const logger = useLogger()

const sharedLabels = useSharedLabels()

const { onOrderingUpdate, orderingString, paginateBy, ordering, orderingDirection } = useOrdering(props.orderingConfigName)

const router = useRouter()
const updateQueryString = () => router.replace({
  query: {
    query: query.value,
    page: page.value,
    tag: tags,
    paginateBy: paginateBy.value,
    ordering: orderingString.value
  }
})

const search = () => {
  page.value = 1
  updateQueryString()
}

watch(page, updateQueryString)
onOrderingUpdate(updateQueryString)

const isLoading = ref(false)
const fetchData = async () => {
  isLoading.value = true
  const params = {
    scope: props.scope,
    page: page.value,
    page_size: paginateBy.value,
    q: query.value,
    ordering: orderingString.value,
    playable: 'true',
    tag: tags,
    include_channels: 'true',
    content_category: 'music'
  }

  logger.time('Fetching albums')
  try {
    const response = await axios.get('albums/', {
      params,
      paramsSerializer: function (params) {
        return qs.stringify(params, { indices: false })
      }
    })

    result.value = response.data
  } catch (error) {
    // TODO (wvffle): Handle error
    result.value = null
  } finally {
    logger.timeEnd('Fetching albums')
    isLoading.value = false
  }
}

const store = useStore()
watch(store.state.moderation.lastUpdate, fetchData)
onBeforeRouteUpdate(fetchData)
fetchData()

// @ts-expect-error semantic ui
onMounted(() => $('.ui.dropdown').dropdown())

const { $pgettext } = useGettext()
const labels = computed(() => ({
  searchPlaceholder: $pgettext('Content/Search/Input.Placeholder', 'Enter album title…'),
  title: $pgettext('*/*/*', 'Albums')
}))
</script>

<template>
  <main v-title="labels.title">
    <section class="ui vertical stripe segment">
      <h2 class="ui header">
        <translate translate-context="Content/Album/Title">
          Browsing albums
        </translate>
      </h2>
      <form
        :class="['ui', {'loading': isLoading}, 'form']"
        @submit.prevent="search"
      >
        <div class="fields">
          <div class="field">
            <label for="albums-search">
              <translate translate-context="Content/Search/Input.Label/Noun">Search</translate>
            </label>
            <div class="ui action input">
              <input
                id="albums-search"
                v-model="query"
                type="text"
                name="search"
                :placeholder="labels.searchPlaceholder"
              >
              <button
                class="ui icon button"
                type="submit"
                :aria-label="$pgettext('Content/Search/Input.Label/Noun', 'Search')"
              >
                <i class="search icon" />
              </button>
            </div>
          </div>
          <div class="field">
            <label for="tags-search"><translate translate-context="*/*/*/Noun">Tags</translate></label>
            <tags-selector v-model="tags" />
          </div>
          <div class="field">
            <label for="album-ordering"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering</translate></label>
            <select
              id="album-ordering"
              v-model="ordering"
              class="ui dropdown"
            >
              <option
                v-for="(option, key) in orderingOptions"
                :key="key"
                :value="option[0]"
              >
                {{ sharedLabels.filters[option[1]] }}
              </option>
            </select>
          </div>
          <div class="field">
            <label for="album-ordering-direction"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering direction</translate></label>
            <select
              id="album-ordering-direction"
              v-model="orderingDirection"
              class="ui dropdown"
            >
              <option value="+">
                <translate translate-context="Content/Search/Dropdown">
                  Ascending
                </translate>
              </option>
              <option value="-">
                <translate translate-context="Content/Search/Dropdown">
                  Descending
                </translate>
              </option>
            </select>
          </div>
          <div class="field">
            <label for="album-results"><translate translate-context="Content/Search/Dropdown.Label/Noun">Results per page</translate></label>
            <select
              id="album-results"
              v-model="paginateBy"
              class="ui dropdown"
            >
              <option :value="12">
                12
              </option>
              <option :value="25">
                25
              </option>
              <option :value="50">
                50
              </option>
            </select>
          </div>
        </div>
      </form>
      <div class="ui hidden divider" />
      <div
        v-if="result"
        transition-duration="0"
        item-selector=".column"
        percent-position="true"
        stagger="0"
        class=""
      >
        <div
          v-if="result.results.length > 0"
          class="ui app-cards cards"
        >
          <album-card
            v-for="album in result.results"
            :key="album.id"
            :album="album"
          />
        </div>
        <div
          v-else
          class="ui placeholder segment sixteen wide column"
          style="text-align: center; display: flex; align-items: center"
        >
          <div class="ui icon header">
            <i class="compact disc icon" />
            <translate translate-context="Content/Albums/Placeholder">
              No results matching your query
            </translate>
          </div>
          <router-link
            v-if="$store.state.auth.authenticated"
            :to="{name: 'content.index'}"
            class="ui success button labeled icon"
          >
            <i class="upload icon" />
            <translate translate-context="Content/*/Verb">
              Add some music
            </translate>
          </router-link>
        </div>
      </div>
      <div class="ui center aligned basic segment">
        <pagination
          v-if="result && result.count > paginateBy"
          v-model:current="page"
          :paginate-by="paginateBy"
          :total="result.count"
        />
      </div>
    </section>
  </main>
</template>
