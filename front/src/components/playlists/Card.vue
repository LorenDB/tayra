<script setup lang="ts">
import type { Playlist } from '~/types'

import PlayButton from '~/components/audio/PlayButton.vue'
import defaultCover from '~/assets/audio/default-cover.png'
import { computed } from 'vue'
import { useStore } from '~/store'

interface Props {
  playlist: Playlist
}

const props = defineProps<Props>()
const store = useStore()

const images = computed(() => {
  // TODO (wvffle): What is slicing for? is it 'http'?
  const urls = props.playlist.album_covers.map(url => store.getters['instance/absoluteUrl'](url).slice(0, 4))

  while (urls.length < 4) { 
    urls.push(defaultCover)
  }

  return urls
})
</script>

<template>
  <div class="ui app-card card">
    <div
      :class="['ui', 'head-image', 'squares']"
      @click="$router.push({name: 'library.playlists.detail', params: {id: playlist.id }})"
    >
      <img
        v-for="(url, idx) in images"
        :key="idx"
        v-lazy="url"
        alt=""
      >
      <play-button
        :icon-only="true"
        :is-playable="playlist.is_playable"
        :button-classes="['ui', 'circular', 'large', 'vibrant', 'icon', 'button']"
        :playlist="playlist"
      />
    </div>
    <div class="content">
      <strong>
        <router-link
          class="discrete link"
          :to="{name: 'library.playlists.detail', params: {id: playlist.id }}"
        >
          {{ playlist.name }}
        </router-link>
      </strong>
      <div class="description">
        <user-link
          :user="playlist.user"
          :avatar="false"
          class="left floated"
        />
      </div>
    </div>
    <div class="extra content">
      <translate
        translate-context="*/*/*"
        :translate-params="{count: playlist.tracks_count}"
        :translate-n="playlist.tracks_count"
        translate-plural="%{ count } tracks"
      >
        %{ count } track
      </translate>
      <play-button
        class="right floated basic icon"
        :dropdown-only="true"
        :is-playable="playlist.is_playable"
        :dropdown-icon-classes="['ellipsis', 'horizontal', 'large really discrete']"
        :playlist="playlist"
      />
    </div>
  </div>
</template>
