<script setup lang="ts">
import type { Artist, Track, Album } from '~/types'
import type { ContentFilter } from '~/store/moderation'

import { ref, computed, reactive } from 'vue'
import { useStore } from '~/store'

import axios from 'axios'

import AlbumCard from '~/components/audio/album/Card.vue'
import TrackTable from '~/components/audio/track/Table.vue'
import LibraryWidget from '~/components/federation/LibraryWidget.vue'

interface Props {
  object: Artist
  tracks: Track[]
  albums: Album[]
  isLoadingAlbums: boolean
  nextTracksUrl?: string | null
  nextAlbumsUrl?: string | null
}

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
    // TODO (wvffle): Handle error
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
          <translate translate-context="Content/Artist/Paragraph">
            You are currently hiding content related to this artist.
          </translate>
        </p>
        <router-link
          class="right floated"
          :to="{name: 'settings'}"
        >
          <translate translate-context="Content/Moderation/Link">
            Review my filters
          </translate>
        </router-link>
        <button
          class="ui basic tiny button"
          @click="$store.dispatch('moderation/deleteContentFilter', contentFilter.uuid)"
        >
          <translate translate-context="Content/Moderation/Button.Label">
            Remove filter
          </translate>
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
        <translate translate-context="Content/Artist/Title">
          Albums by this artist
        </translate>
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
        <translate translate-context="Content/*/Button.Label">
          Load more…
        </translate>
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
            <translate translate-context="Content/Artist/Title">
              New tracks by this artist
            </translate>
          </h2>
          <div class="ui hidden divider" />
        </template>
      </track-table>
    </section>
    <section class="ui vertical stripe segment">
      <h2>
        <translate translate-context="Content/*/Title/Noun">
          User libraries
        </translate>
      </h2>
      <library-widget
        :url="'artists/' + object.id + '/libraries/'"
        @loaded="$emit('libraries-loaded', $event)"
      >
        <translate translate-context="Content/Artist/Paragraph">
          This artist is present in the following libraries:
        </translate>
      </library-widget>
    </section>
  </div>
</template>
