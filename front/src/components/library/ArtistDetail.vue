<script setup lang="ts">
import type { Artist, Track, Album, Library } from '~/types'
import type { ContentFilter } from '~/store/moderation'

import { ref, computed, reactive } from 'vue'
import { useStore } from '~/store'

import axios from 'axios'

import LibraryWidget from '~/components/federation/LibraryWidget.vue'
import TrackTable from '~/components/audio/track/Table.vue'
import AlbumCard from '~/components/audio/album/Card.vue'

import useErrorHandler from '~/composables/useErrorHandler'

interface Events {
  (e: 'libraries-loaded', libraries: Library[]): void
}

interface Props {
  object: Artist
  tracks: Track[]
  albums: Album[]
  isLoadingAlbums: boolean
  nextTracksUrl?: string | null
  nextAlbumsUrl?: string | null
}

const emit = defineEmits<Events>()
const props = withDefaults(defineProps<Props>(), {
  nextTracksUrl: null,
  nextAlbumsUrl: null
})

const store = useStore()

const additionalAlbums = reactive([] as Album[])
const contentFilter = computed(() => store.getters['moderation/artistFilters']().find((filter: ContentFilter) => filter.target.id === props.object.id))
const allAlbums = computed(() => [...props.albums, ...additionalAlbums])

const isLoadingMoreAlbums = ref(false)
const loadMoreAlbumsUrl = ref(props.nextAlbumsUrl)
const loadMoreAlbums = async () => {
  if (loadMoreAlbumsUrl.value === null) return
  isLoadingMoreAlbums.value = true

  try {
    const response = await axios.get(loadMoreAlbumsUrl.value)
    additionalAlbums.push(...additionalAlbums.concat(response.data.results))
    loadMoreAlbumsUrl.value = response.data.next
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoadingMoreAlbums.value = false
}
</script>

<template>
  <div v-if="object">
    <div
      v-if="contentFilter"
      class="ui small text container"
    >
      <div class="ui hidden divider" />
      <div class="ui message">
        <p>
          {{ $t('components.library.ArtistDetail.message.filter') }}
        </p>
        <router-link
          class="right floated"
          :to="{name: 'settings'}"
        >
          {{ $t('components.library.ArtistDetail.link.filter') }}
        </router-link>
        <button
          class="ui basic tiny button"
          @click="$store.dispatch('moderation/deleteContentFilter', contentFilter.uuid)"
        >
          {{ $t('components.library.ArtistDetail.button.filter') }}
        </button>
      </div>
    </div>
    <section
      v-if="isLoadingAlbums"
      class="ui vertical stripe segment"
    >
      <div :class="['ui', 'centered', 'active', 'inline', 'loader']" />
    </section>
    <section
      v-else-if="albums && albums.length > 0"
      class="ui vertical stripe segment"
    >
      <h2>
        {{ $t('components.library.ArtistDetail.header.album') }}
      </h2>
      <div class="ui cards app-cards">
        <album-card
          v-for="album in allAlbums"
          :key="album.id"
          :album="album"
        />
      </div>
      <div class="ui hidden divider" />
      <button
        v-if="loadMoreAlbumsUrl !== null"
        :class="['ui', {loading: isLoadingMoreAlbums}, 'button']"
        @click="loadMoreAlbums()"
      >
        {{ $t('components.library.ArtistDetail.button.more') }}
      </button>
    </section>
    <section
      v-if="tracks.length > 0"
      class="ui vertical stripe segment"
    >
      <track-table
        :is-artist="true"
        :show-position="false"
        :track-only="true"
        :tracks="tracks.slice(0,5)"
      >
        <template #header>
          <h2>
            {{ $t('components.library.ArtistDetail.header.track') }}
          </h2>
          <div class="ui hidden divider" />
        </template>
      </track-table>
    </section>
    <section class="ui vertical stripe segment">
      <h2>
        {{ $t('components.library.ArtistDetail.header.library') }}
      </h2>
      <library-widget
        :url="'artists/' + object.id + '/libraries/'"
        @loaded="emit('libraries-loaded', $event)"
      >
        {{ $t('components.library.ArtistDetail.description.library') }}
      </library-widget>
    </section>
  </div>
</template>
