<script setup lang="ts">
import type { Cover, Track } from '~/types'

import PlayButton from '~/components/audio/PlayButton.vue'
import TrackFavoriteIcon from '~/components/favorites/TrackFavoriteIcon.vue'
import useQueue from '~/composables/audio/useQueue'
import useWebAudioPlayer from '~/composables/audio/useWebAudioPlayer'
import { computed } from 'vue'

interface Props {
  // TODO (wvffle): Is it correct type?
  entry: Track
  defaultCover: Cover
}

const props = defineProps<Props>()

const { currentTrack } = useQueue()
const { playing } = useWebAudioPlayer()

const cover = computed(() => props.entry.cover ?? null)
const duration = computed(() => props.entry.uploads.find(upload => upload.duration)?.duration ?? null)
</script>

<template>
  <div :class="[{active: currentTrack && playing && entry.id === currentTrack.id}, 'channel-entry-card']">
    <div class="controls">
      <play-button
        class="basic circular icon"
        :discrete="true"
        :icon-only="true"
        :is-playable="true"
        :button-classes="['ui', 'circular', 'inverted vibrant', 'icon', 'button']"
        :track="entry"
      />
    </div>
    <img
      v-if="cover && cover.urls.original"
      v-lazy="$store.getters['instance/absoluteUrl'](cover.urls.medium_square_crop)"
      alt=""
      class="channel-image image"
      @click="$router.push({name: 'library.tracks.detail', params: {id: entry.id}})"
    >
    <img
      v-else-if="entry.artist.content_category === 'podcast' && defaultCover != undefined"
      v-lazy="$store.getters['instance/absoluteUrl'](defaultCover.urls.medium_square_crop)"
      class="channel-image image"
      @click="$router.push({name: 'library.tracks.detail', params: {id: entry.id}})"
    >
    <img
      v-else-if="entry.album && entry.album.cover && entry.album.cover.urls.original"
      v-lazy="$store.getters['instance/absoluteUrl'](entry.album.cover.urls.medium_square_crop)"
      alt=""
      class="channel-image image"
      @click="$router.push({name: 'library.tracks.detail', params: {id: entry.id}})"
    >
    <img
      v-else
      alt=""
      class="channel-image image"
      src="../../assets/audio/default-cover.png"
      @click="$router.push({name: 'library.tracks.detail', params: {id: entry.id}})"
    >
    <div class="ellipsis content">
      <strong>
        <router-link
          class="discrete link"
          :to="{name: 'library.tracks.detail', params: {id: entry.id}}"
        >
          {{ entry.title }}
        </router-link>
      </strong>
      <br>
      <human-date
        class="really discrete"
        :date="entry.creation_date"
      />
    </div>
    <div class="meta">
      <template v-if="$store.state.auth.authenticated && $store.getters['favorites/isFavorite'](entry.id)">
        <track-favorite-icon
          class="tiny"
          :track="entry"
        />
      </template>
      <human-duration
        v-if="duration"
        :duration="duration"
      />
    </div>
    <div class="controls">
      <play-button
        class="play-button basic icon"
        :dropdown-only="true"
        :is-playable="entry.is_playable"
        :dropdown-icon-classes="['ellipsis', 'vertical', 'large really discrete']"
        :track="entry"
      />
    </div>
  </div>
</template>
