<script setup lang="ts">
import type { Track, Artist, Album, Playlist, Library, Channel, Actor } from '~/types'
import type { PlayOptionsProps } from '~/composables/audio/usePlayOptions'

import { ref, computed, onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import usePlayOptions from '~/composables/audio/usePlayOptions'
import useReport from '~/composables/moderation/useReport'
import { useCurrentElement } from '@vueuse/core'
import { setupDropdown } from '~/utils/fomantic'

interface Props extends PlayOptionsProps {
  dropdownIconClasses?: string[]
  playIconClass?: string
  buttonClasses?: string[]
  discrete?: boolean
  dropdownOnly?: boolean
  iconOnly?: boolean
  playing?: boolean
  paused?: boolean

  // TODO(wvffle): Remove after https://github.com/vuejs/core/pull/4512 is merged
  isPlayable?: boolean
  tracks?: Track[]
  track?: Track | null
  artist?: Artist | null
  album?: Album | null
  playlist?: Playlist | null
  library?: Library | null
  channel?: Channel | null
  account?: Actor | null
}

const props = withDefaults(defineProps<Props>(), {
  tracks: () => [],
  track: null,
  artist: null,
  playlist: null,
  album: null,
  library: null,
  channel: null,
  account: null,
  dropdownIconClasses: () => ['dropdown'],
  playIconClass: () => 'play icon',
  buttonClasses: () => ['button'],
  discrete: () => false,
  dropdownOnly: () => false,
  iconOnly: () => false,
  isPlayable: () => false,
  playing: () => false,
  paused: () => false
})

const {
  playable,
  filterableArtist,
  filterArtist,
  enqueue,
  enqueueNext,
  replacePlay,
  isLoading
} = usePlayOptions(props)

const { report, getReportableObjects } = useReport()

const { t } = useI18n()
const labels = computed(() => ({
  playNow: t('Play now'),
  addToQueue: t('Add to current queue'),
  playNext: t('Play next'),
  startRadio: t('Play similar songs'),
  report: t('Report…'),
  addToPlaylist: t('Add to playlist…'),
  hideArtist: t('Hide content from this artist'),
  replacePlay: props.track
    ? t('Play track')
    : props.album
      ? t('Play album')
      : props.artist
        ? t('Play artist')
        : props.playlist
          ? t('Play playlist')
          : t('Play tracks')
}))

const title = computed(() => {
  if (playable.value) {
    return t('More…')
  }

  if (props.track) {
    return t('This track is not available in any library you have access to')
  }

  return ''
})

const el = useCurrentElement()
const dropdown = ref()
onMounted(() => {
  dropdown.value = setupDropdown('.ui.dropdown', el.value)
})

const openMenu = () => {
  // little magic to ensure the menu is always visible in the viewport
  // By default, try to display it on the right if there is enough room
  const menu = dropdown.value.find('.menu')
  const viewportOffset = menu.get(0)?.getBoundingClientRect() ?? { right: 0, left: 0 }
  const viewportWidth = document.documentElement.clientWidth
  const rightOverflow = viewportOffset.right - viewportWidth
  const leftOverflow = -viewportOffset.left

  if (rightOverflow > 0) {
    menu.css({ cssText: `left: ${-rightOverflow - 5}px !important;` })
  } else if (leftOverflow > 0) {
    menu.css({ cssText: `right: -${leftOverflow + 5}px !important;` })
  }
}
</script>

<template>
  <span
    :title="title"
    :class="['ui', {'tiny': discrete, 'icon': !discrete, 'buttons': !dropdownOnly && !iconOnly}, 'play-button component-play-button']"
  >
    <button
      v-if="!dropdownOnly"
      :disabled="!playable"
      :aria-label="labels.replacePlay"
      :class="[...buttonClasses, 'ui', {loading: isLoading, 'mini': discrete, disabled: !playable}]"
      @click.stop.prevent="replacePlay()"
    >
      <i
        v-if="playing"
        class="pause icon"
      />
      <i
        v-else
        :class="[playIconClass, 'icon']"
      />
      <template v-if="!discrete && !iconOnly">&nbsp;<slot>Play</slot></template>
    </button>
    <button
      v-if="!discrete && !iconOnly"
      :class="['ui', {disabled: !playable && !filterableArtist}, 'floating', 'dropdown', {'icon': !dropdownOnly}, {'button': !dropdownOnly}]"
      @click.stop.prevent="openMenu"
    >
      <i
        :class="dropdownIconClasses.concat(['icon'])"
        :title="title"
      />
      <div class="menu">
        <button
          class="item basic"
          :disabled="!playable"
          :title="labels.addToQueue"
          @click.stop.prevent="enqueue"
        >
          <i class="plus icon" />Add to queue
        </button>
        <button
          class="item basic"
          :disabled="!playable"
          :title="labels.playNext"
          @click.stop.prevent="enqueueNext()"
        >
          <i class="step forward icon" />{{ labels.playNext }}
        </button>
        <button
          class="item basic"
          :disabled="!playable"
          :title="labels.playNow"
          @click.stop.prevent="enqueueNext(true)"
        >
          <i class="play icon" />{{ labels.playNow }}
        </button>
        <button
          v-if="track"
          class="item basic"
          :disabled="!playable"
          :title="labels.startRadio"
          @click.stop.prevent="$store.dispatch('radios/start', {type: 'similar', objectId: track?.id})"
        >
          <i class="feed icon" />Play radio
        </button>
        <button
          v-if="track"
          class="item basic"
          :disabled="!playable"
          @click.stop="$store.commit('playlists/chooseTrack', track)"
        >
          <i class="list icon" />
          Add to playlist…
        </button>
        <button
          v-if="track && $route.name !== 'library.tracks.detail'"
          class="item basic"
          @click.stop.prevent="$router.push(`/library/tracks/${track?.id}/`)"
        >
          <i class="info icon" />
          <translate
            v-if="track.artist?.content_category === 'podcast'"
          >Episode details</translate>
          <translate
            v-else
          >Track details</translate>
        </button>
        <div class="divider" />
        <button
          v-if="filterableArtist"
          class="item basic"
          :disabled="!filterableArtist"
          :title="labels.hideArtist"
          @click.stop.prevent="filterArtist"
        >
          <i class="eye slash outline icon" />
          {{ labels.hideArtist }}
        </button>
        <button
          v-for="obj in getReportableObjects({track, album, artist, playlist, account, channel})"
          :key="obj.target.type + obj.target.id"
          class="item basic"
          @click.stop.prevent="report(obj)"
        >
          <i class="share icon" /> {{ obj.label }}
        </button>
      </div>
    </button>
  </span>
</template>
