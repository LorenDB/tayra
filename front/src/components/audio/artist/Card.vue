<script setup lang="ts">
import type { Artist } from '~/types'

import PlayButton from '~/components/audio/PlayButton.vue'
import TagsList from '~/components/tags/List.vue'
import { computed } from 'vue'
import { useStore } from '~/store'
import { truncate } from '~/utils/filters'

interface Props {
  artist: Artist
}

const props = defineProps<Props>()

const cover = computed(() => !props.artist.cover?.urls.original
  ? props.artist.albums.find(album => !!album.cover?.urls.original)?.cover
  : props.artist.cover
)

const store = useStore()
const imageUrl = computed(() => cover.value?.urls.original
  ? store.getters['instance/absoluteUrl'](cover.value.urls.medium_square_crop)
  : null
)
</script>

<template>
  <div class="app-card card">
    <router-link
      class="discrete link"
      :to="{name: 'library.artists.detail', params: {id: artist.id}}"
    >
      <div
        v-lazy:background-image="imageUrl"
        :class="['ui', 'head-image', 'circular', 'image', {'default-cover': !cover || !cover.urls.original}]"
      >
        <play-button
          :icon-only="true"
          :is-playable="artist.is_playable"
          :button-classes="['ui', 'circular', 'large', 'vibrant', 'icon', 'button']"
          :artist="artist"
        />
      </div>
    </router-link>
    <div class="content">
      <strong>
        <router-link
          class="discrete link"
          :to="{name: 'library.artists.detail', params: {id: artist.id}}"
        >
          {{ truncate(artist.name, 30) }}
        </router-link>
      </strong>

      <tags-list
        label-classes="tiny"
        :truncate-size="20"
        :limit="2"
        :show-more="false"
        :tags="artist.tags"
      />
    </div>
    <div class="extra content">
      <translate
        v-if="artist.content_category === 'music'"
        translate-context="*/*/*"
        :translate-params="{count: artist.tracks_count}"
        :translate-n="artist.tracks_count"
        translate-plural="%{ count } tracks"
      >
        %{ count } track
      </translate>
      <translate
        v-else
        translate-context="*/*/*"
        :translate-params="{count: artist.tracks_count}"
        :translate-n="artist.tracks_count"
        translate-plural="%{ count } episodes"
      >
        %{ count } episode
      </translate>
      <play-button
        class="right floated basic icon"
        :dropdown-only="true"
        :is-playable="artist.is_playable"
        :dropdown-icon-classes="['ellipsis', 'horizontal', 'large really discrete']"
        :artist="artist"
      />
    </div>
  </div>
</template>
