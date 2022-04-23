<template>
  <section
    class="main with-background component-queue"
    :aria-label="labels.queue"
  >
    <div :class="['ui vertical stripe queue segment', playerFocused ? 'player-focused' : '']">
      <div class="ui fluid container">
        <div
          id="queue-grid"
          class="ui stackable grid"
        >
          <div class="ui six wide column current-track">
            <div
              id="player"
              class="ui basic segment"
            >
              <template v-if="currentTrack">
                <img
                  v-if="currentTrack.cover && currentTrack.cover.urls.large_square_crop"
                  ref="cover"
                  alt=""
                  :src="$store.getters['instance/absoluteUrl'](currentTrack.cover.urls.large_square_crop)"
                >
                <img
                  v-else-if="currentTrack.album && currentTrack.album.cover && currentTrack.album.cover.urls.large_square_crop"
                  ref="cover"
                  alt=""
                  :src="$store.getters['instance/absoluteUrl'](currentTrack.album.cover.urls.large_square_crop)"
                >
                <img
                  v-else
                  class="ui image"
                  alt=""
                  src="../assets/audio/default-cover.png"
                >
                <h1 class="ui header">
                  <div class="content ellipsis">
                    <router-link
                      class="small header discrete link track"
                      :to="{name: 'library.tracks.detail', params: {id: currentTrack.id }}"
                    >
                      {{ currentTrack.title }}
                    </router-link>
                    <div class="sub header ellipsis">
                      <router-link
                        class="discrete link artist"
                        :to="{name: 'library.artists.detail', params: {id: currentTrack.artist.id }}"
                      >
                        {{ currentTrack.artist.name }}
                      </router-link>
                      <template v-if="currentTrack.album">
                        /
                        <router-link
                          class="discrete link album"
                          :to="{name: 'library.albums.detail', params: {id: currentTrack.album.id }}"
                        >
                          {{ currentTrack.album.title }}
                        </router-link>
                      </template>
                    </div>
                  </div>
                </h1>
                <div
                  v-if="currentTrack && errored"
                  class="ui small warning message"
                >
                  <h3 class="header">
                    <translate translate-context="Sidebar/Player/Error message.Title">
                      The track cannot be loaded
                    </translate>
                  </h3>
                  <p v-if="hasNext && playing && $store.state.player.errorCount < $store.state.player.maxConsecutiveErrors">
                    <translate translate-context="Sidebar/Player/Error message.Paragraph">
                      The next track will play automatically in a few seconds…
                    </translate>
                    <i class="loading spinner icon" />
                  </p>
                  <p>
                    <translate translate-context="Sidebar/Player/Error message.Paragraph">
                      You may have a connectivity issue.
                    </translate>
                  </p>
                </div>
                <div class="additional-controls tablet-and-below">
                  <track-favorite-icon
                    v-if="$store.state.auth.authenticated"
                    :track="currentTrack"
                  />
                  <track-playlist-icon
                    v-if="$store.state.auth.authenticated"
                    :track="currentTrack"
                  />
                  <button
                    v-if="$store.state.auth.authenticated"
                    :class="['ui', 'really', 'basic', 'circular', 'icon', 'button']"
                    :aria-label="labels.addArtistContentFilter"
                    :title="labels.addArtistContentFilter"
                    @click="$store.dispatch('moderation/hide', {type: 'artist', target: currentTrack.artist})"
                  >
                    <i :class="['eye slash outline', 'basic', 'icon']" />
                  </button>
                </div>
                <div class="progress-wrapper">
                  <div
                    v-if="currentTrack && !errored"
                    class="progress-area"
                  >
                    <div
                      ref="progress"
                      :class="['ui', 'small', 'vibrant', {'indicating': isLoadingAudio}, 'progress']"
                      @click="touchProgress"
                    >
                      <div
                        class="buffer bar"
                        :data-percent="bufferProgress"
                        :style="{ 'width': bufferProgress + '%' }"
                      />
                      <div
                        class="position bar"
                        :data-percent="progress"
                        :style="{ 'width': progress + '%' }"
                      />
                    </div>
                  </div>
                  <div
                    v-else
                    class="progress-area"
                  >
                    <div
                      ref="progress"
                      :class="['ui', 'small', 'vibrant', 'progress']"
                    >
                      <div class="buffer bar" />
                      <div class="position bar" />
                    </div>
                  </div>
                  <div class="progress">
                    <template v-if="!isLoadingAudio">
                      <a
                        href=""
                        :aria-label="labels.restart"
                        class="left floated timer discrete start"
                        @click.prevent="setCurrentTime(0)"
                      >{{ currentTimeFormatted }}</a>
                      <span class="right floated timer total">{{ durationFormatted }}</span>
                    </template>
                    <template v-else>
                      <span class="left floated timer">00:00</span>
                      <span class="right floated timer">00:00</span>
                    </template>
                  </div>
                </div>
                <div class="player-controls tablet-and-below">
                  <span
                    role="button"
                    :title="labels.previousTrack"
                    :aria-label="labels.previousTrack"
                    class="control"
                    :disabled="emptyQueue"
                    @click.prevent.stop="$store.dispatch('queue/previous')"
                  >
                    <i :class="['ui', 'backward step', {'disabled': emptyQueue}, 'icon']" />
                  </span>

                  <span
                    v-if="!playing"
                    role="button"
                    :title="labels.play"
                    :aria-label="labels.play"
                    class="control"
                    @click.prevent.stop="resumePlayback"
                  >
                    <i :class="['ui', 'play', {'disabled': !currentTrack}, 'icon']" />
                  </span>
                  <span
                    v-else
                    role="button"
                    :title="labels.pause"
                    :aria-label="labels.pause"
                    class="control"
                    @click.prevent.stop="pausePlayback"
                  >
                    <i :class="['ui', 'pause', {'disabled': !currentTrack}, 'icon']" />
                  </span>
                  <span
                    role="button"
                    :title="labels.next"
                    :aria-label="labels.next"
                    class="control"
                    :disabled="!hasNext"
                    @click.prevent.stop="$store.dispatch('queue/next')"
                  >
                    <i :class="['ui', {'disabled': !hasNext}, 'forward step', 'icon']" />
                  </span>
                </div>
              </template>
            </div>
          </div>
          <div class="ui ten wide column queue-column">
            <div class="ui basic clearing fixed-header segment">
              <h2 class="ui header">
                <div class="content">
                  <button
                    class="ui right floated basic button"
                    @click="$store.commit('ui/queueFocused', null)"
                  >
                    <translate translate-context="*/Queue/*/Verb">
                      Close
                    </translate>
                  </button>
                  <button
                    class="ui right floated basic button danger"
                    @click="$store.dispatch('queue/clean')"
                  >
                    <translate translate-context="*/Queue/*/Verb">
                      Clear
                    </translate>
                  </button>
                  {{ labels.queue }}
                  <div class="sub header">
                    <div>
                      <translate
                        translate-context="Sidebar/Queue/Text"
                        :translate-params="{index: queue.currentIndex + 1, length: queue.tracks.length}"
                      >
                        Track %{ index } of %{ length }
                      </translate><template v-if="!$store.state.radios.running">
                        -
                        <span :title="labels.duration">
                          {{ timeLeft }}
                        </span>
                      </template>
                    </div>
                  </div>
                </div>
              </h2>
            </div>
            <table class="ui compact very basic fixed single line selectable unstackable table">
              <draggable
                v-model="tracks"
                tag="tbody"
                handle=".handle"
                @update="reorder"
              >
                <tr
                  v-for="(track, index) in tracks"
                  :key="index"
                  :class="['queue-item', {'active': index === queue.currentIndex}]"
                >
                  <td class="handle">
                    <i class="grip lines icon" />
                  </td>
                  <td
                    class="image-cell"
                    @click="$store.dispatch('queue/currentIndex', index)"
                  >
                    <img
                      v-if="track.cover && track.cover.urls.original"
                      class="ui mini image"
                      alt=""
                      :src="$store.getters['instance/absoluteUrl'](track.cover.urls.medium_square_crop)"
                    >
                    <img
                      v-else-if="track.album && track.album.cover && track.album.cover.urls.original"
                      class="ui mini image"
                      alt=""
                      :src="$store.getters['instance/absoluteUrl'](track.album.cover.urls.medium_square_crop)"
                    >
                    <img
                      v-else
                      class="ui mini image"
                      alt=""
                      src="../assets/audio/default-cover.png"
                    >
                  </td>
                  <td
                    colspan="3"
                    @click="$store.dispatch('queue/currentIndex', index)"
                  >
                    <button
                      class="title reset ellipsis"
                      :title="track.title"
                      :aria-label="labels.selectTrack"
                    >
                      <strong>{{ track.title }}</strong><br>
                      <span>
                        {{ track.artist.name }}
                      </span>
                    </button>
                  </td>
                  <td class="duration-cell">
                    <template v-if="track.uploads.length > 0">
                      {{ time.durationFormatted(track.uploads[0].duration) }}
                    </template>
                  </td>
                  <td class="controls">
                    <template v-if="$store.getters['favorites/isFavorite'](track.id)">
                      <i class="pink heart icon" />
                    </template>
                    <button
                      :aria-label="labels.removeFromQueue"
                      :title="labels.removeFromQueue"
                      :class="['ui', 'really', 'tiny', 'basic', 'circular', 'icon', 'button']"
                      @click.stop="cleanTrack(index)"
                    >
                      <i class="x icon" />
                    </button>
                  </td>
                </tr>
              </draggable>
            </table>

            <div
              v-if="$store.state.radios.running"
              class="ui info message"
            >
              <div class="content">
                <h3 class="header">
                  <i class="feed icon" /> <translate translate-context="Sidebar/Player/Title">
                    You have a radio playing
                  </translate>
                </h3>
                <p>
                  <translate translate-context="Sidebar/Player/Paragraph">
                    New tracks will be appended here automatically.
                  </translate>
                </p>
                <button
                  class="ui basic primary button"
                  @click="$store.dispatch('radios/stop')"
                >
                  <translate translate-context="*/Player/Button.Label/Short, Verb">
                    Stop radio
                  </translate>
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>
<script>
import { mapState, mapGetters, mapActions } from 'vuex'
import $ from 'jquery'
import moment from 'moment'
import { sum } from 'lodash-es'
import time from '~/utils/time'
import { createFocusTrap } from 'focus-trap'
import TrackFavoriteIcon from '~/components/favorites/TrackFavoriteIcon.vue'
import TrackPlaylistIcon from '~/components/playlists/TrackPlaylistIcon.vue'
import draggable from 'vuedraggable'

export default {
  components: {
    TrackFavoriteIcon,
    TrackPlaylistIcon,
    draggable
  },
  data () {
    return {
      showVolume: false,
      isShuffling: false,
      tracksChangeBuffer: null,
      focusTrap: null,
      time
    }
  },
  computed: {
    ...mapState({
      currentIndex: state => state.queue.currentIndex,
      playing: state => state.player.playing,
      isLoadingAudio: state => state.player.isLoadingAudio,
      volume: state => state.player.volume,
      looping: state => state.player.looping,
      duration: state => state.player.duration,
      bufferProgress: state => state.player.bufferProgress,
      errored: state => state.player.errored,
      currentTime: state => state.player.currentTime,
      queue: state => state.queue
    }),
    ...mapGetters({
      currentTrack: 'queue/currentTrack',
      hasNext: 'queue/hasNext',
      emptyQueue: 'queue/isEmpty',
      durationFormatted: 'player/durationFormatted',
      currentTimeFormatted: 'player/currentTimeFormatted',
      progress: 'player/progress'
    }),
    tracks: {
      get () {
        return this.$store.state.queue.tracks
      },
      set (value) {
        this.tracksChangeBuffer = value
      }
    },
    labels () {
      return {
        queue: this.$pgettext('*/*/*', 'Queue'),
        duration: this.$pgettext('*/*/*', 'Duration'),
        addArtistContentFilter: this.$pgettext('Sidebar/Player/Icon.Tooltip/Verb', 'Hide content from this artist…'),
        restart: this.$pgettext('*/*/*', 'Restart track')
      }
    },
    timeLeft () {
      const seconds = sum(
        this.queue.tracks.slice(this.queue.currentIndex).map((t) => {
          return (t.uploads || []).map((u) => {
            return u.duration || 0
          })[0] || 0
        })
      )
      return moment(this.$store.state.ui.lastDate).add(seconds, 'seconds').fromNow(true)
    },
    sliderVolume: {
      get () {
        return this.volume
      },
      set (v) {
        this.$store.commit('player/volume', v)
      }
    },
    playerFocused () {
      return this.$store.state.ui.queueFocused === 'player'
    }
  },
  watch: {
    '$store.state.ui.queueFocused': {
      handler (v) {
        if (v === 'queue') {
          this.$nextTick(() => {
            this.scrollToCurrent()
          })
        }
      },
      immediate: true
    },
    '$store.state.queue.currentIndex': {
      handler () {
        this.$nextTick(() => {
          this.scrollToCurrent()
        })
      }
    },
    '$store.state.queue.tracks': {
      handler (v) {
        if (!v || v.length === 0) {
          this.$store.commit('ui/queueFocused', null)
        }
      },
      immediate: true
    },
    '$route.fullPath' () {
      this.$store.commit('ui/queueFocused', null)
    }
  },
  mounted () {
    this.focusTrap = createFocusTrap(this.$el, { allowOutsideClick: () => { return true } })
    this.focusTrap.activate()
    this.$nextTick(() => {
      setTimeout(() => {
        this.scrollToCurrent()
        // delay is to let transition work
      }, 400)
    })
  },
  methods: {
    ...mapActions({
      cleanTrack: 'queue/cleanTrack',
      mute: 'player/mute',
      unmute: 'player/unmute',
      clean: 'queue/clean',
      toggleMute: 'player/toggleMute',
      resumePlayback: 'player/resumePlayback',
      pausePlayback: 'player/pausePlayback'
    }),
    reorder: function (event) {
      this.$store.commit('queue/reorder', {
        tracks: this.tracksChangeBuffer,
        oldIndex: event.oldIndex,
        newIndex: event.newIndex
      })
    },
    scrollToCurrent () {
      const current = $(this.$el).find('.queue-item.active')[0]
      if (!current) {
        return
      }
      const elementRect = current.getBoundingClientRect()
      const absoluteElementTop = elementRect.top + window.pageYOffset
      const middle = absoluteElementTop - (window.innerHeight / 2)
      window.scrollTo({ top: middle, behaviour: 'smooth' })
    },
    touchProgress (e) {
      const target = this.$refs.progress
      const time = (e.layerX / target.offsetWidth) * this.duration
      this.$emit('touch-progress', time)
    },
    shuffle () {
      const disabled = this.queue.tracks.length === 0
      if (this.isShuffling || disabled) {
        return
      }
      const self = this
      const msg = this.$pgettext('Content/Queue/Message', 'Queue shuffled!')
      this.isShuffling = true
      setTimeout(() => {
        self.$store.dispatch('queue/shuffle', () => {
          self.isShuffling = false
          self.$store.commit('ui/addMessage', {
            content: msg,
            date: new Date()
          })
        })
      }, 100)
    }
  }
}
</script>
