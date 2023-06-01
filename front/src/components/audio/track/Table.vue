<script setup lang="ts">
import type { Track } from '~/types'

import { useI18n } from 'vue-i18n'
import { clone, uniqBy } from 'lodash-es'
import { ref, computed } from 'vue'

import axios from 'axios'

import TrackMobileRow from '~/components/audio/track/MobileRow.vue'
import Pagination from '~/components/vui/Pagination.vue'
import TrackRow from '~/components/audio/track/Row.vue'

import useErrorHandler from '~/composables/useErrorHandler'

interface Events {
  (e: 'fetched'): void
  (e: 'page-changed', page: number): void
}

interface Props {
  tracks?: undefined | Track[]

  showAlbum?: boolean
  showArtist?: boolean
  showPosition?: boolean
  showArt?: boolean
  showDuration?: boolean
  search?: boolean
  displayActions?: boolean
  isArtist?: boolean
  isAlbum?: boolean
  isPodcast?: boolean

  filters?: object

  nextUrl?: string | null

  paginateResults?: boolean
  total?: number
  page?: number
  paginateBy?: number,

  unique?: boolean
}

const emit = defineEmits<Events>()
const props = withDefaults(defineProps<Props>(), {
  tracks: undefined,

  showAlbum: true,
  showArtist: true,
  showPosition: false,
  showArt: true,
  showDuration: true,
  search: false,
  displayActions: true,
  isArtist: false,
  isAlbum: false,
  isPodcast: false,

  filters: () => ({}),
  nextUrl: null,

  paginateResults: true,
  total: 0,
  page: 1,
  paginateBy: 25,

  unique: true
})

const currentPage = ref(props.page)
const totalTracks = ref(props.total)
const fetchDataUrl = ref(props.nextUrl)
const additionalTracks = ref([] as Track[])
const query = ref('')

const allTracks = computed(() => {
  const tracks = [...(props.tracks ?? []), ...additionalTracks.value]
  return props.unique
    ? uniqBy(tracks, 'id')
    : tracks
})

const { t } = useI18n()
const labels = computed(() => ({
  title: t('components.audio.track.Table.table.header.title'),
  album: t('components.audio.track.Table.table.header.album'),
  artist: t('components.audio.track.Table.table.header.artist')
}))

const isLoading = ref(false)
const fetchData = async () => {
  isLoading.value = true

  const params = {
    ...clone(props.filters),
    page_size: props.paginateBy,
    page: currentPage.value,
    include_channels: true,
    q: query.value
  }

  try {
    const response = await axios.get('tracks/', { params })

    // TODO (wvffle): Fetch continuously?
    fetchDataUrl.value = response.data.next
    additionalTracks.value = response.data.results
    totalTracks.value = response.data.count
    emit('fetched')
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoading.value = false
}

const performSearch = () => {
  currentPage.value = 1
  additionalTracks.value = []
  fetchData()
}

if (props.tracks === undefined) {
  fetchData()
}

const updatePage = (page: number) => {
  if (props.tracks === undefined) {
    currentPage.value = page
    fetchData()
  } else {
    emit('page-changed', page)
  }
}
</script>

<template>
  <div>
    <!-- Show the search bar if search is true -->
    <inline-search-bar
      v-if="search"
      v-model="query"
      @search="performSearch"
    />

    <!-- Add a header if needed -->

    <slot name="header" />

    <!-- Show a message if no tracks are available -->

    <slot
      v-if="!isLoading && allTracks.length === 0"
      name="empty-state"
    >
      <empty-state
        :refresh="true"
        @refresh="fetchData()"
      />
    </slot>
    <div v-else>
      <div
        :class="['track-table', 'ui', 'unstackable', 'grid', 'tablet-and-up']"
      >
        <div
          v-if="isLoading"
          class="ui inverted active dimmer"
        >
          <div class="ui loader" />
        </div>
        <div class="track-table row">
          <div
            v-if="showPosition"
            class="actions left floated column"
          >
            <i class="hashtag icon" />
          </div>
          <div
            v-else
            class="actions left floated column"
          />
          <div
            v-if="showArt"
            class="image left floated column"
          />
          <div class="content ellipsis left floated column">
            <b>{{ labels.title }}</b>
          </div>
          <div
            v-if="showAlbum"
            class="content ellipsisleft floated column"
          >
            <b>{{ labels.album }}</b>
          </div>
          <div
            v-if="showArtist"
            class="content ellipsis left floated column"
          >
            <b>{{ labels.artist }}</b>
          </div>
          <div
            v-if="$store.state.auth.authenticated"
            class="meta right floated column"
          />
          <div
            v-if="showDuration"
            class="meta right floated column"
          >
            <i
              class="clock outline icon"
              style="padding: 0.5rem"
            />
          </div>
          <div
            v-if="displayActions"
            class="meta right floated column"
          />
        </div>

        <!-- For each item, build a row -->

        <track-row
          v-for="(track, index) in allTracks"
          :key="`${track.id} ${track.position}`"
          :track="track"
          :index="index"
          :tracks="allTracks"
          :show-album="showAlbum"
          :show-artist="showArtist"
          :show-position="showPosition"
          :show-art="showArt"
          :display-actions="displayActions"
          :show-duration="showDuration"
          :is-podcast="isPodcast"
        />
      </div>
      <div
        v-if="tracks && paginateResults"
        class="ui center aligned basic segment desktop-and-up"
      >
        <pagination
          :total="totalTracks"
          :current="tracks !== undefined ? page : currentPage"
          :paginate-by="paginateBy"
          @update:current="updatePage"
        />
      </div>
    </div>

    <div
      :class="['track-table', 'ui', 'unstackable', 'grid', 'tablet-and-below']"
    >
      <div
        v-if="isLoading"
        class="ui inverted active dimmer"
      >
        <div class="ui loader" />
      </div>

      <!-- For each item, build a row -->

      <track-mobile-row
        v-for="(track, index) in allTracks"
        :key="track.id"
        :track="track"
        :index="index"
        :tracks="allTracks"
        :show-position="showPosition"
        :show-art="showArt"
        :show-duration="showDuration"
        :is-artist="isArtist"
        :is-album="isAlbum"
        :is-podcast="isPodcast"
      />
      <div
        v-if="tracks && paginateResults && totalTracks > paginateBy"
        class="ui center aligned basic segment tablet-and-below"
      >
        <pagination
          v-if="paginateResults && totalTracks > paginateBy"
          :paginate-by="paginateBy"
          :total="totalTracks"
          :current="tracks !== undefined ? page : currentPage"
          :compact="true"
          @update:current="updatePage"
        />
      </div>
    </div>
  </div>
</template>
