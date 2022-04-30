<template>
  <span
    :title="title"
    :class="['ui', {'tiny': discrete}, {'icon': !discrete}, {'buttons': !dropdownOnly && !iconOnly}, 'play-button component-play-button']"
  >
    <button
      v-if="!dropdownOnly"
      :disabled="!playable"
      :aria-label="labels.replacePlay"
      :class="buttonClasses.concat(['ui', {loading: isLoading}, {'mini': discrete}, {disabled: !playable}])"
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
          ref="add"
          class="item basic"
          data-ref="add"
          :disabled="!playable"
          :title="labels.addToQueue"
          @click.stop.prevent="add"
        >
          <i class="plus icon" /><translate translate-context="*/Queue/Dropdown/Button/Label/Short">Add to queue</translate>
        </button>
        <button
          ref="addNext"
          class="item basic"
          data-ref="addNext"
          :disabled="!playable"
          :title="labels.playNext"
          @click.stop.prevent="addNext()"
        >
          <i class="step forward icon" />{{ labels.playNext }}
        </button>
        <button
          ref="playNow"
          class="item basic"
          data-ref="playNow"
          :disabled="!playable"
          :title="labels.playNow"
          @click.stop.prevent="addNext(true)"
        >
          <i class="play icon" />{{ labels.playNow }}
        </button>
        <button
          v-if="track"
          class="item basic"
          :disabled="!playable"
          :title="labels.startRadio"
          @click.stop.prevent="$store.dispatch('radios/start', {type: 'similar', objectId: track.id})"
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
          v-if="track && !onTrackPage"
          class="item basic"
          @click.stop.prevent="$router.push(`/library/tracks/${track.id}/`)"
        >
          <i class="info icon" />
          <translate
            v-if="track.artist.content_category === 'podcast'"
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
          ref="filterArtist"
          data-ref="filterArtist"
          class="item basic"
          :disabled="!filterableArtist"
          :title="labels.hideArtist"
          @click.stop.prevent="filterArtist"
        >
          <i class="eye slash outline icon" /><translate translate-context="*/Queue/Dropdown/Button/Label/Short">Hide content from this artist</translate>
        </button>
        <button
          v-for="obj in getReportableObjs({track, album, artist, playlist, account, channel})"
          :key="obj.target.type + obj.target.id"
          :ref="`report${obj.target.type}${obj.target.id}`"
          class="item basic"
          :data-ref="`report${obj.target.type}${obj.target.id}`"
          @click.stop.prevent="$store.dispatch('moderation/report', obj.target)"
        >
          <i class="share icon" /> {{ obj.label }}
        </button>
      </div>
    </button>
  </span>
</template>

<script>
import jQuery from 'jquery'

import ReportMixin from '~/components/mixins/Report.vue'
import PlayOptionsMixin from '~/components/mixins/PlayOptions.vue'

export default {
  mixins: [ReportMixin, PlayOptionsMixin],
  props: {
    // we can either have a single or multiple tracks to play when clicked
    tracks: { type: Array, required: false, default: () => { return null } },
    track: { type: Object, required: false, default: () => { return null } },
    account: { type: Object, required: false, default: () => { return null } },
    dropdownIconClasses: { type: Array, required: false, default: () => { return ['dropdown'] } },
    playIconClass: { type: String, required: false, default: 'play icon' },
    buttonClasses: { type: Array, required: false, default: () => { return ['button'] } },
    playlist: { type: Object, required: false, default: () => { return null } },
    discrete: { type: Boolean, default: false },
    dropdownOnly: { type: Boolean, default: false },
    iconOnly: { type: Boolean, default: false },
    artist: { type: Object, required: false, default: () => { return null } },
    album: { type: Object, required: false, default: () => { return null } },
    library: { type: Object, required: false, default: () => { return null } },
    channel: { type: Object, required: false, default: () => { return null } },
    isPlayable: { type: Boolean, required: false, default: null },
    playing: { type: Boolean, required: false, default: false },
    paused: { type: Boolean, required: false, default: false }
  },
  data () {
    return {
      isLoading: false,
      clicked: false
    }
  },
  computed: {
    labels () {
      let replacePlay
      if (this.track) {
        replacePlay = this.$pgettext('*/Queue/Dropdown/Button/Title', 'Play track')
      } else if (this.album) {
        replacePlay = this.$pgettext('*/Queue/Dropdown/Button/Title', 'Play album')
      } else if (this.artist) {
        replacePlay = this.$pgettext('*/Queue/Dropdown/Button/Title', 'Play artist')
      } else if (this.playlist) {
        replacePlay = this.$pgettext('*/Queue/Dropdown/Button/Title', 'Play playlist')
      } else {
        replacePlay = this.$pgettext('*/Queue/Dropdown/Button/Title', 'Play tracks')
      }

      return {
        playNow: this.$pgettext('*/Queue/Dropdown/Button/Title', 'Play now'),
        addToQueue: this.$pgettext('*/Queue/Dropdown/Button/Title', 'Add to current queue'),
        playNext: this.$pgettext('*/Queue/Dropdown/Button/Title', 'Play next'),
        startRadio: this.$pgettext('*/Queue/Dropdown/Button/Title', 'Play similar songs'),
        report: this.$pgettext('*/Moderation/*/Button/Label,Verb', 'Report…'),
        addToPlaylist: this.$pgettext('Sidebar/Player/Icon.Tooltip/Verb', 'Add to playlist…'),
        replacePlay
      }
    },
    title () {
      if (this.playable) {
        return this.$pgettext('*/*/Button.Label/Noun', 'More…')
      } else {
        if (this.track) {
          return this.$pgettext('*/Queue/Button/Title', 'This track is not available in any library you have access to')
        }
      }
      return null
    },
    onTrackPage () {
      return this.$router.currentRoute.value.name === 'library.tracks.detail'
    }
  },
  watch: {
    clicked () {
      const self = this
      this.$nextTick(() => {
        jQuery(this.$el).find('.ui.dropdown').dropdown({
          selectOnKeydown: false,
          action: function (text, value, $el) {
            // used to ensure focusing the dropdown and clicking via keyboard
            // works as expected
            const button = self.$refs[$el.data('ref')]
            if (Array.isArray(button)) {
              button[0].click()
            } else {
              button.click()
            }
            jQuery(self.$el).find('.ui.dropdown').dropdown('hide')
          }
        })
        jQuery(this.$el).find('.ui.dropdown').dropdown('show', function () {
          // little magic to ensure the menu is always visible in the viewport
          // By default, try to diplay it on the right if there is enough room
          const menu = jQuery(self.$el).find('.ui.dropdown').find('.menu')
          const viewportOffset = menu.get(0).getBoundingClientRect()
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
    }
  }
}
</script>
