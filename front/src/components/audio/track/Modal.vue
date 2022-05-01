<template>
  <modal
    ref="modal"
    v-model:show="showRef"
    :scrolling="true"
    :additional-classes="['scrolling-track-options']"
  >
    <div class="header">
      <div class="ui large centered rounded image">
        <img
          v-if="
            track.album && track.album.cover && track.album.cover.urls.original
          "
          v-lazy="
            $store.getters['instance/absoluteUrl'](
              track.album.cover.urls.medium_square_crop
            )
          "
          alt=""
          class="ui centered image"
        >
        <img
          v-else-if="track.cover"
          v-lazy="
            $store.getters['instance/absoluteUrl'](
              track.cover.urls.medium_square_crop
            )
          "
          alt=""
          class="ui centered image"
        >
        <img
          v-else-if="track.artist.cover"
          v-lazy="
            $store.getters['instance/absoluteUrl'](
              track.artist.cover.urls.medium_square_crop
            )
          "
          alt=""
          class="ui centered image"
        >
        <img
          v-else
          alt=""
          class="ui centered image"
          src="../../../assets/audio/default-cover.png"
        >
      </div>
      <h3 class="track-modal-title">
        {{ track.title }}
      </h3>
      <h4 class="track-modal-subtitle">
        {{ track.artist.name }}
      </h4>
    </div>
    <div class="ui hidden divider" />
    <div class="content">
      <div class="ui one column unstackable grid">
        <div
          v-if="$store.state.auth.authenticated && track.artist.content_category !== 'podcast'"
          class="row"
        >
          <div
            tabindex="0"
            class="column"
            role="button"
            :aria-label="favoriteButton"
            @click.stop="$store.dispatch('favorites/toggle', track.id)"
          >
            <i
              :class="[
                'heart',
                'favorite-icon',
                { favorited: isFavorite },
                { pink: isFavorite },
                'icon',
                'track-modal',
                'list-icon',
              ]"
            />
            <span class="track-modal list-item">{{ favoriteButton }}</span>
          </div>
        </div>
        <div class="row">
          <div
            class="column"
            role="button"
            :aria-label="labels.addToQueue"
            @click.stop.prevent="
              add();
              $refs.modal.closeModal();
            "
          >
            <i class="plus icon track-modal list-icon" />
            <span class="track-modal list-item">{{ labels.addToQueue }}</span>
          </div>
        </div>
        <div class="row">
          <div
            class="column"
            role="button"
            :aria-label="labels.playNext"
            @click.stop.prevent="
              addNext(true);
              $refs.modal.closeModal();
            "
          >
            <i class="step forward icon track-modal list-icon" />
            <span class="track-modal list-item">{{ labels.playNext }}</span>
          </div>
        </div>
        <div class="row">
          <div
            class="column"
            role="button"
            :aria-label="labels.startRadio"
            @click.stop.prevent="
              $store.dispatch('radios/start', {
                type: 'similar',
                objectId: track.id,
              });
              $refs.modal.closeModal();
            "
          >
            <i class="rss icon track-modal list-icon" />
            <span class="track-modal list-item">{{ labels.startRadio }}</span>
          </div>
        </div>
        <div class="row">
          <div
            class="column"
            role="button"
            :aria-label="labels.addToPlaylist"
            @click.stop="$store.commit('playlists/chooseTrack', track)"
          >
            <i class="list icon track-modal list-icon" />
            <span class="track-modal list-item">{{
              labels.addToPlaylist
            }}</span>
          </div>
        </div>
        <div class="ui divider" />
        <div
          v-if="!isAlbum && track.album"
          class="row"
        >
          <div
            class="column"
            role="button"
            :aria-label="albumDetailsButton"
            @click.prevent.exact="
              $router.push({
                name: 'library.albums.detail',
                params: { id: track.album.id },
              })
            "
          >
            <i class="compact disc icon track-modal list-icon" />
            <span class="track-modal list-item">{{
              albumDetailsButton
            }}</span>
          </div>
        </div>
        <div
          v-if="!isArtist"
          class="row"
        >
          <div
            class="column"
            role="button"
            :aria-label="artistDetailsButton"
            @click.prevent.exact="
              $router.push({
                name: 'library.artists.detail',
                params: { id: track.artist.id },
              })
            "
          >
            <i class="user icon track-modal list-icon" />
            <span class="track-modal list-item">{{
              artistDetailsButton
            }}</span>
          </div>
        </div>
        <div class="row">
          <div
            class="column"
            role="button"
            :aria-label="trackDetailsButton"
            @click.prevent.exact="
              $router.push({
                name: 'library.tracks.detail',
                params: { id: track.id },
              })
            "
          >
            <i class="info icon track-modal list-icon" />
            <span class="track-modal list-item">{{
              trackDetailsButton
            }}</span>
          </div>
        </div>
        <div class="ui divider" />
        <div
          v-for="obj in getReportableObjs({
            track,
            album,
            artist,
          })"
          :key="obj.target.type + obj.target.id"
          :ref="`report${obj.target.type}${obj.target.id}`"
          class="row"
          :data-ref="`report${obj.target.type}${obj.target.id}`"
          @click.stop.prevent="$store.dispatch('moderation/report', obj.target)"
        >
          <div class="column">
            <i class="share icon track-modal list-icon" /><span
              class="track-modal list-item"
            >{{ obj.label }}</span>
          </div>
        </div>
      </div>
    </div>
  </modal>
</template>

<script>
import Modal from '~/components/semantic/Modal.vue'
import ReportMixin from '~/components/mixins/Report.vue'
import PlayOptionsMixin from '~/components/mixins/PlayOptions.vue'
import { useVModel } from '@vueuse/core/index'

export default {
  components: {
    Modal
  },
  mixins: [ReportMixin, PlayOptionsMixin],
  props: {
    show: { type: Boolean, required: true, default: false },
    track: { type: Object, required: true },
    index: { type: Number, required: true },
    isArtist: { type: Boolean, required: false, default: false },
    isAlbum: { type: Boolean, required: false, default: false }
  },
  setup (props) {
    // TODO (wvffle): Add defineEmits when rewriting to <script setup>
    const showRef = useVModel(props, 'show'/*, emit*/)
    return { showRef }
  },
  data () {
    return {
      isShowing: this.show,
      tracks: [this.track],
      album: this.track.album,
      artist: this.track.artist
    }
  },
  computed: {
    isFavorite () {
      return this.$store.getters['favorites/isFavorite'](this.track.id)
    },
    favoriteButton () {
      if (this.isFavorite) {
        return this.$pgettext(
          'Content/Track/Icon.Tooltip/Verb',
          'Remove from favorites'
        )
      } else {
        return this.$pgettext('Content/Track/*/Verb', 'Add to favorites')
      }
    },
    trackDetailsButton () {
      if (this.track.artist.content_category === 'podcast') {
        return this.$pgettext('*/Queue/Dropdown/Button/Label/Short', 'Episode details')
      } else {
        return this.$pgettext('*/Queue/Dropdown/Button/Label/Short', 'Track details')
      }
    },
    albumDetailsButton () {
      if (this.track.artist.content_category === 'podcast') {
        return this.$pgettext('*/Queue/Dropdown/Button/Label/Short', 'View series')
      } else {
        return this.$pgettext('*/Queue/Dropdown/Button/Label/Short', 'View album')
      }
    },
    artistDetailsButton () {
      if (this.track.artist.content_category === 'podcast') {
        return this.$pgettext('*/Queue/Dropdown/Button/Label/Short', 'View channel')
      } else {
        return this.$pgettext('*/Queue/Dropdown/Button/Label/Short', 'View artist')
      }
    },
    labels () {
      return {
        startRadio: this.$pgettext(
          '*/Queue/Dropdown/Button/Title',
          'Play radio'
        ),
        playNow: this.$pgettext('*/Queue/Dropdown/Button/Title', 'Play now'),
        addToQueue: this.$pgettext(
          '*/Queue/Dropdown/Button/Title',
          'Add to queue'
        ),
        playNext: this.$pgettext('*/Queue/Dropdown/Button/Title', 'Play next'),
        addToPlaylist: this.$pgettext(
          'Sidebar/Player/Icon.Tooltip/Verb',
          'Add to playlist…'
        )
      }
    }
  }
}
</script>
