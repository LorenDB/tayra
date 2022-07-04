<script setup lang="ts">
import { Track, Artist, Album, Playlist, Library, Channel, Actor } from '~/types'
import { ref, computed, watch, nextTick } from 'vue'
import { useGettext } from 'vue3-gettext'
import usePlayOptions, { PlayOptionsProps } from '~/composables/audio/usePlayOptions'
import useReport from '~/composables/moderation/useReport'
import { useCurrentElement } from '@vueuse/core'
import jQuery from 'jquery'

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
  track: () => null,
  artist: () => null,
  playlist: () => null,
  album: () => null,
  library: () => null,
  channel: () => null,
  account: () => null,
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

const clicked = ref(false)

const { $pgettext } = useGettext()
const labels = computed(() => ({
  playNow: $pgettext('*/Queue/Dropdown/Button/Title', 'Play now'),
  addToQueue: $pgettext('*/Queue/Dropdown/Button/Title', 'Add to current queue'),
  playNext: $pgettext('*/Queue/Dropdown/Button/Title', 'Play next'),
  startRadio: $pgettext('*/Queue/Dropdown/Button/Title', 'Play similar songs'),
  report: $pgettext('*/Moderation/*/Button/Label,Verb', 'Report…'),
  addToPlaylist: $pgettext('Sidebar/Player/Icon.Tooltip/Verb', 'Add to playlist…'),
  hideArtist: $pgettext('*/Queue/Dropdown/Button/Label/Short', 'Hide content from this artist'),
  replacePlay: props.track
  ? $pgettext('*/Queue/Dropdown/Button/Title', 'Play track')
  : props.album
    ? $pgettext('*/Queue/Dropdown/Button/Title', 'Play album')
    : props.artist
      ? $pgettext('*/Queue/Dropdown/Button/Title', 'Play artist')
      : props.playlist
        ? $pgettext('*/Queue/Dropdown/Button/Title', 'Play playlist')
        : $pgettext('*/Queue/Dropdown/Button/Title', 'Play tracks')
}))

const title = computed(() => {
  if (playable.value) {
    return $pgettext('*/*/Button.Label/Noun', 'More…')
  }

  if (props.track) {
    return $pgettext('*/Queue/Button/Title', 'This track is not available in any library you have access to')
  }
})

const el = useCurrentElement()
watch(clicked, async () => {
  await nextTick()
  // @ts-expect-error dropdown is from semantic ui
  jQuery(el.value).find('.ui.dropdown').dropdown({
    selectOnKeydown: false,
    action (text: unknown, value: unknown, $el: JQuery) {
      // used to ensure focusing the dropdown and clicking via keyboard
      // works as expected
      $el[0].click()

      // @ts-expect-error dropdown is from semantic ui
      jQuery(el.value).find('.ui.dropdown').dropdown('hide')
    }
  })

  // @ts-expect-error dropdown is from semantic ui
  jQuery(el.value).find('.ui.dropdown').dropdown('show', function () {
    // little magic to ensure the menu is always visible in the viewport
    // By default, try to diplay it on the right if there is enough room
    const menu = jQuery(el.value).find('.ui.dropdown').find('.menu')
    const viewportOffset = menu.get(0)?.getBoundingClientRect() ?? { right: 0, left: 0 }
    const viewportWidth = document.documentElement.clientWidth
    const rightOverflow = viewportOffset.right - viewportWidth
    const leftOverflow = -viewportOffset.left
    let offset = 0
    if (rightOverflow > 0) {
      offset = -rightOverflow - 5
      menu.css({ cssText: `left: ${offset}px !important;` })
    } else if (leftOverflow > 0) {
      offset = leftOverflow + 5
      menu.css({ cssText: `right: -${offset}px !important;` })
    }
  })
})
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
      @click.stop.prevent="replacePlay"
    >
      <i
        v-if="playing"
        class="pause icon"
      />
      <i
        v-else
        :class="[playIconClass, 'icon']"
      />
      <template v-if="!discrete && !iconOnly">&nbsp;<slot><translate translate-context="*/Queue/Button.Label/Short, Verb">Play</translate></slot></template>
    </button>
    <button
      v-if="!discrete && !iconOnly"
      :class="['ui', {disabled: !playable && !filterableArtist}, 'floating', 'dropdown', {'icon': !dropdownOnly}, {'button': !dropdownOnly}]"
      @click.stop.prevent="clicked = true"
    >
      <i
        :class="dropdownIconClasses.concat(['icon'])"
        :title="title"
      />
      <div
        v-if="clicked"
        class="menu"
      >
        <button
          class="item basic"
          data-ref="enqueue"
          :disabled="!playable"
          :title="labels.addToQueue"
          @click.stop.prevent="enqueue"
        >
          <i class="plus icon" /><translate translate-context="*/Queue/Dropdown/Button/Label/Short">Add to queue</translate>
        </button>
        <button
          class="item basic"
          data-ref="enqueueNext"
          :disabled="!playable"
          :title="labels.playNext"
          @click.stop.prevent="enqueueNext()"
        >
          <i class="step forward icon" />{{ labels.playNext }}
        </button>
        <button
          class="item basic"
          data-ref="playNow"
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
          <i class="feed icon" /><translate translate-context="*/Queue/Button.Label/Short, Verb">Play radio</translate>
        </button>
        <button
          v-if="track"
          class="item basic"
          :disabled="!playable"
          @click.stop="$store.commit('playlists/chooseTrack', track)"
        >
          <i class="list icon" />
          <translate translate-context="Sidebar/Player/Icon.Tooltip/Verb">Add to playlist…</translate>
        </button>
        <button
          v-if="track && $route.name !== 'library.tracks.detail'"
          class="item basic"
          @click.stop.prevent="$router.push(`/library/tracks/${track?.id}/`)"
        >
          <i class="info icon" />
          <translate
            v-if="track.artist?.content_category === 'podcast'"
            translate-context="*/Queue/Dropdown/Button/Label/Short"
          >Episode details</translate>
          <translate
            v-else
            translate-context="*/Queue/Dropdown/Button/Label/Short"
          >Track details</translate>
        </button>
        <div class="divider" />
        <button
          v-if="filterableArtist"
          data-ref="filterArtist"
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
          :data-ref="`report${obj.target.type}${obj.target.id}`"
          @click.stop.prevent="report(obj)"
        >
          <i class="share icon" /> {{ obj.label }}
        </button>
      </div>
    </button>
  </span>
</template>
