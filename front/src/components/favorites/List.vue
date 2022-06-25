<script setup lang="ts">
import axios from 'axios'
import $ from 'jquery'
import RadioButton from '~/components/radios/Button.vue'
import Pagination from '~/components/vui/Pagination.vue'
import { checkRedirectToLogin } from '~/utils'
import TrackTable from '~/components/audio/track/Table.vue'
import useLogger from '~/composables/useLogger'
import useSharedLabels from '~/composables/locale/useSharedLabels'
import useOrdering, { OrderingProps } from '~/composables/useOrdering'
import { onBeforeRouteUpdate, useRouter } from 'vue-router'
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { useStore } from '~/store'
import { Track } from '~/types'
import { useGettext } from 'vue3-gettext'
import { OrderingField } from '~/store/ui'

interface Props extends OrderingProps {
  defaultPage?: number
  defaultPaginateBy?: number
}

const props = withDefaults(defineProps<Props>(), {
  defaultPage: 1,
  defaultPaginateBy: 1
})

const store = useStore()
await checkRedirectToLogin(store, useRouter())

// TODO (wvffle): Make sure everything is it's own type
const page = ref(+props.defaultPage)

const orderingOptions: [OrderingField, keyof typeof sharedLabels.filters][] = [
  ['creation_date', 'creation_date'],
  ['title', 'track_title'],
  ['album__title', 'album_title'],
  ['artist__name', 'artist_name']
]

const logger = useLogger()
const sharedLabels = useSharedLabels()

const router = useRouter()
const { onOrderingUpdate, orderingString, paginateBy, ordering, orderingDirection } = useOrdering(props.orderingConfigName, props.defaultPaginateBy)

const updateQueryString = () => router.replace({
  query: {
    page: page.value,
    paginateBy: paginateBy.value,
    ordering: orderingString.value
  }
})

watch(page, updateQueryString)
onOrderingUpdate(updateQueryString)

const results = reactive<Track[]>([])
const nextLink = ref()
const previousLink = ref()
const count = ref(0)

const isLoading = ref(false)
const fetchFavorites = async () => {
  isLoading.value = true

  const params = {
    favorites: 'true',
    page: page.value,
    page_size: paginateBy.value,
    ordering: orderingString.value
  }

  try {
    logger.time('Loading user favorites')
    const response = await axios.get('tracks/', { params: params })

    results.length = 0
    results.push(...response.data.results)

    for (const track of results) {
      store.commit('favorites/track', { id: track.id, value: true })
    }

    count.value = response.data.count
    nextLink.value = response.data.next
    previousLink.value = response.data.previous
  } catch (error) {
    // TODO (wvffle): Handle error
  } finally {
    logger.timeEnd('Loading user favorites')
    isLoading.value = false
  }
}

onBeforeRouteUpdate(fetchFavorites)
fetchFavorites()

// @ts-expect-error semantic ui
onMounted(() => $('.ui.dropdown').dropdown())

const { $pgettext } = useGettext()
const labels = computed(() => ({
  title: $pgettext('Head/Favorites/Title', 'Your Favorites')
}))
</script>

<template>
  <main
    v-title="labels.title"
    class="main pusher"
  >
    <section class="ui vertical center aligned stripe segment">
      <div :class="['ui', { 'active': isLoading }, 'inverted', 'dimmer']">
        <div class="ui text loader">
          <translate translate-context="Content/Favorites/Message">
            Loading your favorites…
          </translate>
        </div>
      </div>
      <h2
        v-if="results"
        class="ui center aligned icon header"
      >
        <i class="circular inverted heart pink icon" />
        <translate
          translate-plural="%{ count } favorites"
          :translate-n="$store.state.favorites.count"
          :translate-params="{ count }"
          translate-context="Content/Favorites/Title"
        >
          %{ count } favorite
        </translate>
      </h2>
      <radio-button
        v-if="$store.state.favorites.count > 0"
        type="favorites"
      />
    </section>
    <section
      v-if="$store.state.favorites.count > 0"
      class="ui vertical stripe segment"
    >
      <div :class="['ui', { 'loading': isLoading }, 'form']">
        <div class="fields">
          <div class="field">
            <label for="favorites-ordering">
              <translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering</translate>
            </label>
            <select
              id="favorites-ordering"
              v-model="ordering"
              class="ui dropdown"
            >
              <option
                v-for="option in orderingOptions"
                :key="option[0]"
                :value="option[0]"
              >
                {{ sharedLabels.filters[option[1]] }}
              </option>
            </select>
          </div>
          <div class="field">
            <label for="favorites-ordering-direction">
              <translate translate-context="Content/Search/Dropdown.Label/Noun">Order</translate>
            </label>
            <select
              id="favorites-ordering-direction"
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
            <label for="favorites-results">
              <translate translate-context="Content/Search/Dropdown.Label/Noun">Results per page</translate>
            </label>
            <select
              id="favorites-results"
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
      </div>
      <track-table
        v-if="results"
        :show-artist="true"
        :show-album="true"
        :tracks="results"
      />
      <div class="ui center aligned basic segment">
        <pagination
          v-if="results && count > paginateBy"
          v-model:current="page"
          :paginate-by="paginateBy"
          :total="count"
        />
      </div>
    </section>
    <div
      v-else
      class="ui placeholder segment"
    >
      <div class="ui icon header">
        <i class="broken heart icon" />
        <translate
          translate-context="Content/Home/Placeholder"
        >
          No tracks have been added to your favorites yet
        </translate>
      </div>
      <router-link
        :to="'/library'"
        class="ui success labeled icon button"
      >
        <i class="headphones icon" />
        <translate translate-context="Content/*/Verb">
          Browse the library
        </translate>
      </router-link>
    </div>
  </main>
</template>
