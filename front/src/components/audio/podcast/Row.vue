<script setup lang="ts">
import { Track, Artist, Album, Playlist, Library, Channel, Actor } from '~/types'
import { /* Track, */ Cover } from '~/types'
import axios from 'axios'
import PlayButton from '~/components/audio/PlayButton.vue'
import usePlayOptions, { PlayOptionsProps } from '~/composables/audio/usePlayOptions'
import { ref } from 'vue'
import useQueue from '~/composables/audio/useQueue'

interface Props extends PlayOptionsProps {
  tracks: Track[]
  track: Track
  index: number

  showArt?: boolean
  displayActions?: boolean
  defaultCover?: Cover | null

  // TODO(wvffle): Remove after https://github.com/vuejs/core/pull/4512 is merged
  isPlayable?: boolean
  artist?: Artist | null
  album?: Album | null
  playlist?: Playlist | null
  library?: Library | null
  channel?: Channel | null
  account?: Actor | null
}

const props = withDefaults(defineProps<Props>(), {
  showArt: true,
  displayActions: true,
  defaultCover: () => null
})

const description = ref('')

const { currentTrack } = useQueue()
const { activateTrack } = usePlayOptions(props)

const fetchData = async () => {
  try {
    const response = await axios.get(`tracks/${props.track.id}/`)
    description.value = response.data.description.text
  } catch (error) {
    // TODO (wvffle): Handle error
  }
}

// NOTE: Let the <Suspense> take care of showing the loader
await fetchData()
</script>

<template>
  <div
    :class="[
      { active: currentTrack && track.id === currentTrack.id },
      'track-row podcast row',
    ]"
    @dblclick="activateTrack(track, index)"
  >
    <div
      v-if="showArt"
      class="image left floated column"
      role="button"
      @click.prevent.exact="activateTrack(track, index)"
    >
      <img
        v-if="track.cover?.urls.original "
        v-lazy="$store.getters['instance/absoluteUrl'](track.cover.urls.medium_square_crop)"
        alt=""
        class="ui artist-track mini image"
      >
      <img
        v-else-if="defaultCover"
        v-lazy="$store.getters['instance/absoluteUrl'](defaultCover.urls.medium_square_crop)"
        alt=""
        class="ui artist-track mini image"
      >
      <img
        v-else
        alt=""
        class="ui artist-track mini image"
        src="../../../assets/audio/default-cover.png"
      >
    </div>
    <div
      tabindex="0"
      class="content left floated column"
    >
      <a
        class="podcast-episode-title ellipsis"
        @click.prevent.exact="activateTrack(track, index)"
      >{{ track.title }}</a>
      <p
        v-if="description"
        class="podcast-episode-meta"
      >
        {{ description }}
      </p>
    </div>
    <div
      v-if="displayActions"
      class="meta right floated column"
    >
      <play-button
        id="playmenu"
        class="play-button basic icon"
        :dropdown-only="true"
        :is-playable="track.is_playable"
        :dropdown-icon-classes="[
          'ellipsis',
          'vertical',
          'large really discrete',
        ]"
        :track="track"
      />
    </div>
  </div>
</template>
