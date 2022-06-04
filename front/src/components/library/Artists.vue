<script setup lang="ts">
import qs from 'qs'
import axios from 'axios'
import $ from 'jquery'

import ArtistCard from '~/components/audio/artist/Card.vue'
import Pagination from '~/components/vui/Pagination.vue'
import TagsSelector from '~/components/library/TagsSelector.vue'
import useLogger from '~/composables/useLogger'
import useSharedLabels from '~/composables/locale/useSharedLabels'
import { RouteWithPreferences } from '~/store/ui'
import { computed, reactive, ref, watch } from 'vue'
import { useGettext } from 'vue3-gettext'
import { useStore } from '~/store'
import useOrdering from '~/composables/useOrdering'
import { onBeforeRouteUpdate, useRouter } from 'vue-router'

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
const query = ref(props.defaultQuery)
const tags = reactive(props.defaultTags.slice())
const excludeCompilation = ref(true)

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
    ordering: orderingString.value,
    content_category: 'music',
    include_channels: 'true'
  }
})

const search = () => { 
  page.value = props.defaultPage
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
    content_category: 'music',
    has_albums: excludeCompilation.value
  }

  logger.time('Fetching artists')
  try {
    const response = await axios.get('artists/', {
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
    logger.timeEnd('Fetching artists')
    isLoading.value = false
  }
}

const store = useStore()
watch([store.state.moderation.lastUpdate, excludeCompilation], fetchData)
onBeforeRouteUpdate(fetchData)
fetchData()

// @ts-expect-error semantic ui
onMounted(() => $('.ui.dropdown').dropdown())

const { $pgettext } = useGettext()
const labels = computed(() => ({
  searchPlaceholder: $pgettext('Content/Search/Input.Placeholder', 'Search…'),
  title: $pgettext('*/*/*/Noun', 'Artists')
}))
</script>

<template>
  <main v-title="labels.title">
    <section class="ui vertical stripe segment">
      <h2 class="ui header">
        <translate translate-context="Content/Artist/Title">
          Browsing artists
        </translate>
      </h2>
      <form
        :class="['ui', {'loading': isLoading}, 'form']"
        @submit.prevent="search"
      >
        <div class="fields">
          <div class="field">
            <label for="artist-search">
              <translate translate-context="Content/Search/Input.Label/Noun">Artist name</translate>
            </label>
            <div class="ui action input">
              <input
                id="artist-search"
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
            <label for="artist-ordering"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering</translate></label>
            <select
              id="artist-ordering"
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
            <label for="artist-ordering-direction"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering direction</translate></label>
            <select
              id="artist-ordering-direction"
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
            <label for="artist-results"><translate translate-context="Content/Search/Dropdown.Label/Noun">Results per page</translate></label>
            <select
              id="artist-results"
              v-model="paginateBy"
              class="ui dropdown"
            >
              <option :value="parseInt(12)">
                12
              </option>
              <option :value="parseInt(30)">
                30
              </option>
              <option :value="parseInt(50)">
                50
              </option>
            </select>
          </div>
          <div class="field">
            <span id="excludeHeader">Exclude Compilation Artists</span>
            <div
              id="excludeCompilation"
              class="ui toggle checkbox"
            >
              <input
                id="exclude-compilation"
                v-model="excludeCompilation"
                true-value="true"
                false-value="null"
                type="checkbox"
              >
              <label
                for="exclude-compilation"
                class="visually-hidden"
              ><translate translate-context="Content/Search/Checkbox/Noun">Exclude Compilation Artists</translate></label>
            </div>
          </div>
        </div>
      </form>
      <div class="ui hidden divider" />
      <div
        v-if="result && result.results.length > 0"
        class="ui five app-cards cards"
      >
        <div
          v-if="isLoading"
          class="ui inverted active dimmer"
        >
          <div class="ui loader" />
        </div>
        <artist-card
          v-for="artist in result.results"
          :key="artist.id"
          :artist="artist"
        />
      </div>
      <div
        v-else-if="!isLoading"
        class="ui placeholder segment sixteen wide column"
        style="text-align: center; display: flex; align-items: center"
      >
        <div class="ui icon header">
          <i class="compact disc icon" />
          <translate translate-context="Content/Artists/Placeholder">
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
