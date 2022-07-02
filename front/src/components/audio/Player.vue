<template>
  <section
    v-if="currentTrack"
    role="complementary"
    class="player-wrapper ui bottom-player component-player"
    aria-labelledby="player-label"
  >
    <h1
      id="player-label"
      class="visually-hidden"
    >
      <translate translate-context="*/*/*">
        Audio player and controls
      </translate>
    </h1>
    <div
      class="ui inverted segment fixed-controls"
      @click.prevent.stop="toggleMobilePlayer"
    >
      <div
        :class="['ui', 'top attached', 'small', 'inverted', {'indicating': isLoadingAudio}, 'progress']"
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
      <div class="controls-row">
        <div class="controls track-controls queue-not-focused desktop-and-up">
          <div
            class="ui tiny image"
            @click.stop.prevent="$router.push({name: 'library.tracks.detail', params: {id: currentTrack.id }})"
          >
            <img
              v-if="currentTrack.cover && currentTrack.cover.urls.original"
              ref="cover"
              alt=""
              :src="$store.getters['instance/absoluteUrl'](currentTrack.cover.urls.medium_square_crop)"
            >
            <img
              v-else-if="currentTrack.album && currentTrack.album.cover && currentTrack.album.cover.urls && currentTrack.album.cover.urls.original"
              ref="cover"
              alt=""
              :src="$store.getters['instance/absoluteUrl'](currentTrack.album.cover.urls.medium_square_crop)"
            >
            <img
              v-else
              alt=""
              src="../../assets/audio/default-cover.png"
            >
          </div>
          <div
            class="middle aligned content ellipsis"
            @click.stop.prevent=""
          >
            <strong>
              <router-link
                class="small header discrete link track"
                :to="{name: 'library.tracks.detail', params: {id: currentTrack.id }}"
                @click.stop.prevent=""
              >
                {{ currentTrack.title }}
              </router-link>
            </strong>
            <div class="meta">
              <router-link
                class="discrete link"
                :to="{name: 'library.artists.detail', params: {id: currentTrack.artist.id }}"
                @click.stop.prevent=""
              >
                {{ currentTrack.artist.name }}
              </router-link>
              <template v-if="currentTrack.album">
                /
                <router-link
                  class="discrete link"
                  :to="{name: 'library.albums.detail', params: {id: currentTrack.album.id }}"
                  @click.stop.prevent=""
                >
                  {{ currentTrack.album.title }}
                </router-link>
              </template>
            </div>
          </div>
        </div>
        <div class="controls track-controls queue-not-focused tablet-and-below">
          <div class="ui tiny image">
            <img
              v-if="currentTrack.cover && currentTrack.cover.urls.original"
              ref="cover"
              alt=""
              :src="$store.getters['instance/absoluteUrl'](currentTrack.cover.urls.medium_square_crop)"
            >
            <img
              v-else-if="currentTrack.album && currentTrack.album.cover && currentTrack.album.cover.urls.original"
              ref="cover"
              alt=""
              :src="$store.getters['instance/absoluteUrl'](currentTrack.album.cover.urls.medium_square_crop)"
            >
            <img
              v-else
              alt=""
              src="../../assets/audio/default-cover.png"
            >
          </div>
          <div class="middle aligned content ellipsis">
            <strong>
              {{ currentTrack.title }}
            </strong>
            <div class="meta">
              {{ currentTrack.artist.name }}<template v-if="currentTrack.album">
                / {{ currentTrack.album.title }}
              </template>
            </div>
          </div>
        </div>
        <div
          v-if="$store.state.auth.authenticated"
          class="controls desktop-and-up fluid align-right"
        >
          <track-favorite-icon
            class="control white"
            :track="currentTrack"
          />
          <track-playlist-icon
            class="control white"
            :track="currentTrack"
          />
          <button
            :class="['ui', 'really', 'basic', 'circular', 'icon', 'button', 'control']"
            :aria-label="labels.addArtistContentFilter"
            :title="labels.addArtistContentFilter"
            @click="$store.dispatch('moderation/hide', {type: 'artist', target: currentTrack.artist})"
          >
            <i :class="['eye slash outline', 'basic', 'icon']" />
          </button>
        </div>
        <div class="player-controls controls queue-not-focused">
          <button
            :title="labels.previous"
            :aria-label="labels.previous"
            class="circular button control tablet-and-up"
            :disabled="!hasPrevious || null"
            @click.prevent.stop="$store.dispatch('queue/previous')"
          >
            <i :class="['ui', 'large', {'disabled': !hasPrevious}, 'backward step', 'icon']" />
          </button>
          <button
            v-if="!playing"
            :title="labels.play"
            :aria-label="labels.play"
            class="circular button control"
            @click.prevent.stop="playback = true"
          >
            <i :class="['ui', 'big', 'play', {'disabled': !currentTrack}, 'icon']" />
          </button>
          <button
            v-else
            :title="labels.pause"
            :aria-label="labels.pause"
            class="circular button control"
            @click.prevent.stop="playback = false"
          >
            <i :class="['ui', 'big', 'pause', {'disabled': !currentTrack}, 'icon']" />
          </button>
          <button
            :title="labels.next"
            :aria-label="labels.next"
            class="circular button control"
            :disabled="!hasNext || null"
            @click.prevent.stop="$store.dispatch('queue/next')"
          >
            <i :class="['ui', 'large', {'disabled': !hasNext}, 'forward step', 'icon']" />
          </button>
        </div>

        <div class="controls progress-controls queue-not-focused tablet-and-up small align-left">
          <div class="timer">
            <template v-if="!isLoadingAudio">
              <span
                class="start"
                @click.stop.prevent="setCurrentTime(0)"
              >{{ currentTimeFormatted }}</span>
              | <span class="total">{{ durationFormatted }}</span>
            </template>
          </div>
        </div>
        <div class="controls queue-controls when-queue-focused align-right">
          <div class="group">
            <volume-control class="expandable" />
            <button
              v-if="looping === 0"
              class="circular control button"
              :title="labels.loopingDisabled"
              :aria-label="labels.loopingDisabled"
              :disabled="!currentTrack || null"
              @click.prevent.stop="$store.commit('player/looping', 1)"
            >
              <i :class="['ui', {'disabled': !currentTrack}, 'step', 'repeat', 'icon']" />
            </button>
            <button
              v-if="looping === 1"
              class="looping circular control button"
              :title="labels.loopingSingle"
              :aria-label="labels.loopingSingle"
              :disabled="!currentTrack || null"
              @click.prevent.stop="$store.commit('player/looping', 2)"
            >
              <i
                class="repeat icon"
              >
                <span class="ui circular tiny vibrant label">1</span>
              </i>
            </button>
            <button
              v-if="looping === 2"
              class="looping circular control button"
              :title="labels.loopingWhole"
              :aria-label="labels.loopingWhole"
              :disabled="!currentTrack || null"
              @click.prevent.stop="$store.commit('player/looping', 0)"
            >
              <i
                class="repeat icon"
              >
                <span class="ui circular tiny vibrant label">&infin;</span>
              </i>
            </button>
            <button
              class="circular control button"
              :disabled="queueIsEmpty || null"
              :title="labels.shuffle"
              :aria-label="labels.shuffle"
              @click.prevent.stop="shuffle()"
            >
              <div
                v-if="isShuffling"
                class="ui inline shuffling inverted tiny active loader"
              />
              <i
                v-else
                :class="['ui', 'random', {'disabled': queueIsEmpty}, 'icon']"
              />
            </button>
          </div>
          <div class="group">
            <div class="fake-dropdown">
              <button
                class="position circular control button desktop-and-up"
                aria-expanded="true"
                @click.stop="toggleMobilePlayer"
              >
                <i class="stream icon" />
                <translate
                  translate-context="Sidebar/Queue/Text"
                  :translate-params="{index: queue.currentIndex + 1, length: queue.tracks.length}"
                >
                  %{ index } of %{ length }
                </translate>
              </button>
              <button
                class="position circular control button tablet-and-below"
                @click.stop="switchTab"
              >
                <i class="stream icon" />
                <translate
                  translate-context="Sidebar/Queue/Text"
                  :translate-params="{index: queue.currentIndex + 1, length: queue.tracks.length}"
                >
                  %{ index } of %{ length }
                </translate>
              </button>

              <button
                v-if="$store.state.ui.queueFocused"
                class="circular control button close-control desktop-and-up"
                @click.stop="toggleMobilePlayer"
              >
                <i class="large down angle icon" />
              </button>
              <button
                v-else
                class="circular control button desktop-and-up"
                @click.stop="toggleMobilePlayer"
              >
                <i class="large up angle icon" />
              </button>
              <button
                v-if="$store.state.ui.queueFocused === 'player'"
                class="circular control button close-control tablet-and-below"
                @click.stop="switchTab"
              >
                <i class="large up angle icon" />
              </button>
              <button
                v-if="$store.state.ui.queueFocused === 'queue'"
                class="circular control button tablet-and-below"
                @click.stop="switchTab"
              >
                <i class="large down angle icon" />
              </button>
            </div>
            <button
              class="circular control button close-control tablet-and-below"
              @click.stop="$store.commit('ui/queueFocused', null)"
            >
              <i class="x icon" />
            </button>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>

<script>
import { useStore } from '~/store'
import { mapState, mapGetters, mapActions } from 'vuex'
import toLinearVolumeScale from '~/composables/audio/toLinearVolumeScale'
import { Howl, Howler } from 'howler'
import { throttle, reverse } from 'lodash-es'
import axios from 'axios'
import VolumeControl from './VolumeControl.vue'
import TrackFavoriteIcon from '~/components/favorites/TrackFavoriteIcon.vue'
import TrackPlaylistIcon from '~/components/playlists/TrackPlaylistIcon.vue'
import updateQueryString from '~/composables/updateQueryString'
import onKeyboardShortcut from '~/composables/onKeyboardShortcut'
import { useThrottleFn, useTimeoutFn, useToggle } from '@vueuse/core'
import { computed, watch } from 'vue'
import { useGettext } from 'vue3-gettext'
import useQueue from '~/composables/useQueue'

export default {
  components: {
    VolumeControl,
    TrackFavoriteIcon,
    TrackPlaylistIcon
  },
  setup (props, { emit }) {
    // TODO (wvffle): When migrating to <script setup> use  defineEmits
    // const emit = defineEmits(['next', 'previous'])

    const store = useStore()
    const { $pgettext } = useGettext()

    const queue = computed(() => store.state.queue)
    const queueIsEmpty = computed(() => queue.value.tracks.length === 0)
    const currentTrack = computed(() => store.getters['queue/currentTrack'])
    const currentTime = computed(() => store.state.player.currentTime)

    const toggleMobilePlayer = () => {
      store.commit('ui/queueFocused', ['queue', 'player'].indexOf(store.state.ui.queueFocused) > -1 ? null : 'player')
    }

    const { shuffle } = useQueue()

    const seek = (step) => {
      if (step > 0) {
        // seek right
        if (currentTime.value + step < this.duration) {
          store.dispatch('player/updateProgress', (currentTime.value + step))
        } else {
          this.next() // parenthesis where missing here
        }
      } else {
        // seek left
        const position = Math.max(currentTime.value + step, 0)
        store.dispatch('player/updateProgress', position)
      }
    }

    const next = async () => {
      await store.dispatch('queue/next')
      emit('next')
    }

    const previous = async () => {
      await store.dispatch('queue/previous')
      emit('previous')
    }

    // Playback
    const playing = computed(() => store.state.player.playing)
    const [playback, togglePlayback] = useToggle()
    watch(playback, isPlaying => store.dispatch(
      isPlaying
        ? 'player/resumePlayback'
        : 'player/pausePlayback'
    ))

    // Add controls for notification drawer
    if ('mediaSession' in navigator) {
      navigator.mediaSession.setActionHandler('play', () => (playback.value = true))
      navigator.mediaSession.setActionHandler('pause', () => (playback.value = false))
      navigator.mediaSession.setActionHandler('seekforward', () => seek(5))
      navigator.mediaSession.setActionHandler('seekbackward', () => seek(-5))
      navigator.mediaSession.setActionHandler('nexttrack', next)
      navigator.mediaSession.setActionHandler('previoustrack', previous)
    }

    // Key binds
    onKeyboardShortcut('e', toggleMobilePlayer)
    onKeyboardShortcut('p', togglePlayback)
    onKeyboardShortcut('s', shuffle)
    onKeyboardShortcut('q', () => store.dispatch('queue/clean'))
    onKeyboardShortcut('m', () => store.dispatch('player/toggleMute'))
    onKeyboardShortcut('l', () => store.commit('player/toggleLooping'))
    onKeyboardShortcut('f', () => store.dispatch('favorites/toggle', currentTrack.value?.id))
    onKeyboardShortcut('escape', () => store.commit('ui/queueFocused', null))

    onKeyboardShortcut(['shift', 'up'], () => store.commit('player/incrementVolume', 0.1), true)
    onKeyboardShortcut(['shift', 'down'], () => store.commit('player/incrementVolume', -0.1), true)

    onKeyboardShortcut('right', () => seek(5), true)
    onKeyboardShortcut(['shift', 'right'], () => seek(30), true)
    onKeyboardShortcut('left', () => seek(-5), true)
    onKeyboardShortcut(['shift', 'left'], () => seek(-30), true)

    onKeyboardShortcut(['ctrl', 'shift', 'left'], previous, true)
    onKeyboardShortcut(['ctrl', 'shift', 'right'], next, true)

    return {
      queue,
      queueIsEmpty,
      currentTrack,

      toggleMobilePlayer,
      shuffle,

      next,
      previous,
      playback,
      playing
    }
  },
  data () {
    return {
      isShuffling: false,
      sliderVolume: this.volume,
      showVolume: false,
      currentSound: null,
      dummyAudio: null,
      isUpdatingTime: false,
      sourceErrors: 0,
      progressInterval: null,
      maxPreloaded: 3,
      preloadDelay: 15,
      listenDelay: 15,
      listeningIsSubmitted: false,
      soundsCache: [],
      soundId: null,
      playTimeout: null,
      nextTrackPreloaded: false
    }
  },
  computed: {
    ...mapState({
      currentIndex: state => state.queue.currentIndex,
      isLoadingAudio: state => state.player.isLoadingAudio,
      volume: state => state.player.volume,
      looping: state => state.player.looping,
      duration: state => state.player.duration,
      bufferProgress: state => state.player.bufferProgress,
      errored: state => state.player.errored
    }),
    ...mapGetters({
      hasNext: 'queue/hasNext',
      hasPrevious: 'queue/hasPrevious',
      emptyQueue: 'queue/isEmpty',
      durationFormatted: 'player/durationFormatted',
      currentTimeFormatted: 'player/currentTimeFormatted',
      progress: 'player/progress'
    }),
    updateProgressThrottled () {
      return throttle(this.updateProgress, 50)
    },
    labels () {
      const audioPlayer = this.$pgettext('Sidebar/Player/Hidden text', 'Media player')
      const previous = this.$pgettext('Sidebar/Player/Icon.Tooltip', 'Previous track')
      const play = this.$pgettext('Sidebar/Player/Icon.Tooltip/Verb', 'Play')
      const pause = this.$pgettext('Sidebar/Player/Icon.Tooltip/Verb', 'Pause')
      const next = this.$pgettext('Sidebar/Player/Icon.Tooltip', 'Next track')
      const unmute = this.$pgettext('Sidebar/Player/Icon.Tooltip/Verb', 'Unmute')
      const mute = this.$pgettext('Sidebar/Player/Icon.Tooltip/Verb', 'Mute')
      const expandQueue = this.$pgettext('Sidebar/Player/Icon.Tooltip/Verb', 'Expand queue')
      const loopingDisabled = this.$pgettext('Sidebar/Player/Icon.Tooltip',
        'Looping disabled. Click to switch to single-track looping.'
      )
      const loopingSingle = this.$pgettext('Sidebar/Player/Icon.Tooltip',
        'Looping on a single track. Click to switch to whole queue looping.'
      )
      const loopingWhole = this.$pgettext('Sidebar/Player/Icon.Tooltip',
        'Looping on whole queue. Click to disable looping.'
      )
      const shuffle = this.$pgettext('Sidebar/Player/Icon.Tooltip/Verb', 'Shuffle your queue')
      const clear = this.$pgettext('Sidebar/Player/Icon.Tooltip/Verb', 'Clear your queue')
      const addArtistContentFilter = this.$pgettext('Sidebar/Player/Icon.Tooltip/Verb', 'Hide content from this artist…')
      return {
        audioPlayer,
        previous,
        play,
        pause,
        next,
        unmute,
        mute,
        loopingDisabled,
        loopingSingle,
        loopingWhole,
        shuffle,
        clear,
        expandQueue,
        addArtistContentFilter
      }
    }
  },
  watch: {
    currentTrack: {
      async handler (newValue, oldValue) {
        if (newValue === oldValue) {
          return
        }
        this.nextTrackPreloaded = false
        clearTimeout(this.playTimeout)
        if (this.currentSound) {
          this.currentSound.pause()
        }
        this.$store.commit('player/isLoadingAudio', true)
        this.playTimeout = setTimeout(async () => {
          await this.loadSound(newValue, oldValue)
        }, 100)
        this.updateMetadata()
      },
      immediate: false
    },
    volume: {
      immediate: true,
      handler (newValue) {
        this.sliderVolume = newValue
        Howler.volume(toLinearVolumeScale(newValue))
      }
    },
    sliderVolume (newValue) {
      this.$store.commit('player/volume', newValue)
    },
    playing: async function (newValue) {
      if (this.currentSound) {
        if (newValue === true) {
          this.soundId = this.currentSound.play(this.soundId)
        } else {
          this.currentSound.pause(this.soundId)
        }
      } else {
        await this.loadSound(this.currentTrack, null)
      }

      this.observeProgress(newValue)
    },
    currentTime (newValue) {
      if (!this.isUpdatingTime) {
        this.setCurrentTime(newValue)
      }
      this.isUpdatingTime = false
    },
    emptyQueue (newValue) {
      if (newValue) {
        Howler.unload()
      }
    }
  },
  mounted () {
    this.$store.dispatch('player/updateProgress', 0)
    this.$store.commit('player/playing', false)
    this.$store.commit('player/isLoadingAudio', false)
    Howler.unload() // clear existing cache, if any
    this.nextTrackPreloaded = false
    // this is needed to unlock audio playing under some browsers,
    // cf https://github.com/goldfire/howler.js#mobilechrome-playback
    // but we never actually load those audio files
    this.dummyAudio = new Howl({
      preload: false,
      autoplay: false,
      src: ['noop.webm', 'noop.mp3']
    })
    if (this.currentTrack) {
      this.getSound(this.currentTrack)
      this.updateMetadata()
    }
  },
  beforeUnmount () {
    this.dummyAudio.unload()
    this.observeProgress(false)
  },
  unmounted () {
  },
  methods: {
    ...mapActions({
      mute: 'player/mute',
      unmute: 'player/unmute'
    }),
    async getTrackData (trackData) {
      // use previously fetched trackData
      if (trackData.uploads.length) return trackData

      // we don't have any information for this track, we need to fetch it
      return axios.get(`tracks/${trackData.id}/`)
        .then(
          response => response.data,
          () => null
        )
    },
    handleError ({ sound, error }) {
      this.$store.commit('player/isLoadingAudio', false)
      this.$store.dispatch('player/trackErrored')
    },
    getSound (trackData) {
      const cached = this.getSoundFromCache(trackData)
      if (cached) {
        return cached.sound
      }
      const srcs = this.getSrcs(trackData)
      const self = this
      const sound = new Howl({
        src: srcs.map((s) => { return s.url }),
        format: srcs.map((s) => { return s.type }),
        autoplay: false,
        loop: false,
        html5: true,
        preload: true,
        onend: function () {
          self.ended()
        },
        onunlock: function () {
          if (self.$store.state.player.playing && self.sound) {
            self.soundId = self.sound.play(self.soundId)
          }
        },
        onload: function () {
          const sound = this
          const node = this._sounds[0]._node
          node.addEventListener('progress', () => {
            if (sound !== self.currentSound) {
              return
            }
            self.updateBuffer(node)
          })
        },
        onplay: function () {
          if (this !== self.currentSound) {
            this.stop()
            return
          }
          const t = self.currentSound.seek()
          const d = self.currentSound.duration()
          if (t <= (d / 2)) {
            self.listeningIsSubmitted = false
          }
          self.$store.commit('player/isLoadingAudio', false)
          self.$store.commit('player/resetErrorCount')
          self.$store.commit('player/errored', false)
          self.$store.commit('player/duration', this.duration())
        },
        onloaderror: function (sound, error) {
          self.removeFromCache(this)
          if (this !== self.currentSound) {
            return
          }
          console.log('Error while playing:', sound, error)
          self.handleError({ sound, error })
        }
      })
      this.addSoundToCache(sound, trackData)
      return sound
    },
    getSrcs: function (trackData) {
      const a = document.createElement('audio')
      const allowed = ['probably', 'maybe']
      const sources = trackData.uploads.filter(u => {
        const canPlay = a.canPlayType(u.mimetype)
        return allowed.indexOf(canPlay) > -1
      }).map(u => {
        return {
          type: u.extension,
          url: this.$store.getters['instance/absoluteUrl'](u.listen_url)
        }
      })
      a.remove()
      // We always add a transcoded MP3 src at the end
      // because transcoding is expensive, but we want browsers that do
      // not support other codecs to be able to play it :)
      sources.push({
        type: 'mp3',
        url: updateQueryString(
          this.$store.getters['instance/absoluteUrl'](trackData.listen_url),
          'to',
          'mp3'
        )
      })
      if (this.$store.state.auth.authenticated) {
        // we need to send the token directly in url
        // so authentication can be checked by the backend
        // because for audio files we cannot use the regular Authentication
        // header
        return sources.map(source => {
          source.url = updateQueryString(
            source.url,
            'token',
            this.$store.state.auth.scopedTokens.listen
          )

          return source
        })
      }

      return sources
    },

    updateBuffer (node) {
      // from https://github.com/goldfire/howler.js/issues/752#issuecomment-372083163
      let range = 0
      const bf = node.buffered
      const time = node.currentTime
      try {
        while (!(bf.start(range) <= time && time <= bf.end(range))) {
          range += 1
        }
      } catch (IndexSizeError) {
        return
      }
      let loadPercentage
      const start = bf.start(range)
      const end = bf.end(range)
      if (range === 0) {
        // easy case, no user-seek
        const loadStartPercentage = start / node.duration
        const loadEndPercentage = end / node.duration
        loadPercentage = loadEndPercentage - loadStartPercentage
      } else {
        const loaded = end - start
        const remainingToLoad = node.duration - start
        // user seeked a specific position in the audio, our progress must be
        // computed based on the remaining portion of the track
        loadPercentage = loaded / remainingToLoad
      }
      if (loadPercentage * 100 === this.bufferProgress) {
        return
      }
      this.$store.commit('player/bufferProgress', loadPercentage * 100)
    },
    updateProgress: function () {
      this.isUpdatingTime = true
      if (this.currentSound && this.currentSound.state() === 'loaded') {
        const t = this.currentSound.seek()
        const d = this.currentSound.duration()
        this.$store.dispatch('player/updateProgress', t)
        this.updateBuffer(this.currentSound._sounds[0]._node)
        const toPreload = this.$store.state.queue.tracks[this.currentIndex + 1]
        if (!this.nextTrackPreloaded && toPreload && !this.getSoundFromCache(toPreload) && (t > this.preloadDelay || d - t < 30)) {
          this.getSound(toPreload)
          this.nextTrackPreloaded = true
        }
        if (t > (d / 2)) {
          if (!this.listeningIsSubmitted) {
            this.$store.dispatch('player/trackListened', this.currentTrack)
            this.listeningIsSubmitted = true
          }
        }
      }
    },
    seekForward () {
      this.seek(5)
    },
    seekBackward () {
      this.seek(-5)
    },
    observeProgress: function (enable) {
      const self = this
      if (enable) {
        if (self.progressInterval) {
          clearInterval(self.progressInterval)
        }
        self.progressInterval = setInterval(() => {
          self.updateProgress()
        }, 1000)
      } else {
        clearInterval(self.progressInterval)
      }
    },
    setCurrentTime (t) {
      if (t < 0 || t > this.duration) {
        return
      }
      if (!this.currentSound || !this.currentSound._sounds[0]) {
        return
      }
      if (t === this.currentSound.seek()) {
        return
      }
      if (t === 0) {
        this.updateProgressThrottled.cancel()
      }
      this.currentSound.seek(t)
      // If player is paused update progress immediately to ensure updated UI
      if (!this.$store.state.player.playing) {
        this.updateProgress()
      }
    },
    ended: function () {
      const onlyTrack = this.$store.state.queue.tracks.length === 1
      if (this.looping === 1 || (onlyTrack && this.looping === 2)) {
        this.currentSound.seek(0)
        this.$store.dispatch('player/updateProgress', 0)
        this.soundId = this.currentSound.play(this.soundId)
      } else {
        this.$store.dispatch('player/trackEnded', this.currentTrack)
      }
    },
    getSoundFromCache (trackData) {
      return this.soundsCache.filter((d) => {
        if (d.track.id !== trackData.id) {
          return false
        }

        return true
      })[0]
    },
    addSoundToCache (sound, trackData) {
      const data = {
        date: new Date(),
        track: trackData,
        sound: sound
      }
      this.soundsCache.push(data)
      this.checkCache()
    },
    checkCache () {
      const self = this
      const toKeep = []
      reverse(this.soundsCache).forEach((e) => {
        if (toKeep.length < self.maxPreloaded) {
          toKeep.push(e)
        } else {
          e.sound.unload()
        }
      })
      this.soundsCache = reverse(toKeep)
    },
    removeFromCache (sound) {
      const toKeep = []
      this.soundsCache.forEach((e) => {
        if (e.sound === sound) {
          e.sound.unload()
        } else {
          toKeep.push(e)
        }
      })
      this.soundsCache = toKeep
    },
    async loadSound (newValue, oldValue) {
      let trackData = newValue
      const oldSound = this.currentSound
      if (oldSound && trackData !== oldValue) {
        oldSound.stop(this.soundId)
        this.soundId = null
      }
      if (!trackData) {
        return
      }
      if (!this.isShuffling && trackData !== oldValue) {
        trackData = await this.getTrackData(trackData)
        if (trackData == null) {
          this.handleError({})
        }
        this.currentSound = this.getSound(trackData)
        this.$store.commit('player/isLoadingAudio', true)
        this.soundId = this.currentSound.play()
        this.$store.commit('player/errored', false)
        this.$store.commit('player/playing', true)
        this.$store.dispatch('player/updateProgress', 0)
        this.observeProgress(true)
      }
    },
    switchTab () {
      if (this.$store.state.ui.queueFocused === 'player') {
        this.$store.commit('ui/queueFocused', 'queue')
      } else {
        this.$store.commit('ui/queueFocused', 'player')
      }
    },
    updateMetadata () {
      // If the session is playing as a PWA, populate the notification
      // with details from the track
      if (this.currentTrack && 'mediaSession' in navigator) {
        const metadata = {
          title: this.currentTrack.title,
          artist: this.currentTrack.artist.name
        }
        if (this.currentTrack.album && this.currentTrack.album.cover) {
          metadata.album = this.currentTrack.album.title
          metadata.artwork = [
            { src: this.currentTrack.album.cover.urls.original, sizes: '96x96', type: 'image/png' },
            { src: this.currentTrack.album.cover.urls.original, sizes: '128x128', type: 'image/png' },
            { src: this.currentTrack.album.cover.urls.original, sizes: '192x192', type: 'image/png' },
            { src: this.currentTrack.album.cover.urls.original, sizes: '256x256', type: 'image/png' },
            { src: this.currentTrack.album.cover.urls.original, sizes: '384x384', type: 'image/png' },
            { src: this.currentTrack.album.cover.urls.original, sizes: '512x512', type: 'image/png' }
          ]
        }
        navigator.mediaSession.metadata = new window.MediaMetadata(metadata)
      }
    }
  }
}
</script>
