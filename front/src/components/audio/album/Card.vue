<script setup lang="ts">
import type { Album } from '~/types'

import PlayButton from '~/components/audio/PlayButton.vue'
import { momentFormat } from '~/utils/filters'
import { computed } from 'vue'
import { useStore } from '~/store'

interface Props {
  album: Album
}

const props = defineProps<Props>()
const store = useStore()

const imageUrl = computed(() => props.album.cover?.urls.original
  ? store.getters['instance/absoluteUrl'](props.album.cover.urls.medium_square_crop)
  : null
)
</script>

<template>
  <div class="card app-card component-album-card">
    <router-link
      class="discrete link"
      :to="{name: 'library.albums.detail', params: {id: album.id}}"
    >
      <div
        v-lazy:background-image="imageUrl"
        :class="['ui', 'head-image', 'image', {'default-cover': !album.cover || !album.cover.urls.original}]"
      >
        <play-button
          :icon-only="true"
          :is-playable="album.is_playable"
          :button-classes="['ui', 'circular', 'large', 'vibrant', 'icon', 'button']"
          :album="album"
        />
      </div>
    </router-link>
    <div class="content">
      <strong>
        <router-link
          class="discrete link"
          :to="{name: 'library.albums.detail', params: {id: album.id}}"
        >
          {{ album.title }}
        </router-link>
      </strong>
      <div class="description">
        <span>
          <router-link
            class="discrete link"
            :to="{name: 'library.artists.detail', params: {id: album.artist.id}}"
          >
            {{ album.artist.name }}
          </router-link>
        </span>
      </div>
    </div>
    <div class="extra content">
      <span v-if="album.release_date">{{ momentFormat(new Date(album.release_date), 'Y') }} · </span>
      <translate
        translate-context="*/*/*"
        :translate-params="{count: album.tracks_count}"
        :translate-n="album.tracks_count"
        translate-plural="%{ count } tracks"
      >
        %{ count } track
      </translate>
      <play-button
        class="right floated basic icon"
        :dropdown-only="true"
        :is-playable="album.is_playable"
        :dropdown-icon-classes="['ellipsis', 'horizontal', 'large really discrete']"
        :album="album"
      />
    </div>
  </div>
</template>
