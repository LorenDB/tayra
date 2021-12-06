<template>
  <button
    class="circular control button"
    :class="['component-volume-control', {'expanded': expanded}]"
    @click.prevent.stop=""
    @mouseover="handleOver"
    @mouseleave="handleLeave"
  >
    <span
      v-if="sliderVolume === 0"
      role="button"
      :title="labels.unmute"
      :aria-label="labels.unmute"
      @click.prevent.stop="unmute"
    >
      <i class="volume off icon" />
    </span>
    <span
      v-else-if="sliderVolume < 0.5"
      role="button"
      :title="labels.mute"
      :aria-label="labels.mute"
      @click.prevent.stop="mute"
    >
      <i class="volume down icon" />
    </span>
    <span
      v-else
      role="button"
      :title="labels.mute"
      :aria-label="labels.mute"
      @click.prevent.stop="mute"
    >
      <i class="volume up icon" />
    </span>
    <div class="popup">
      <label
        for="volume-slider"
        class="visually-hidden"
      >{{ labels.slider }}</label>
      <input
        id="volume-slider"
        v-model="sliderVolume"
        type="range"
        step="any"
        min="0"
        :max="volumeSteps"
      >
    </div>
  </button>
</template>
<script>
import mapActions from 'vuex'

export default {
  data () {
    return {
      expanded: false,
      timeout: null,
      volumeSteps: 100
    }
  },
  computed: {
    sliderVolume: {
      get () {
        return this.$store.state.player.volume * this.volumeSteps
      },
      set (v) {
        this.$store.commit('player/volume', v / this.volumeSteps)
      }
    },
    labels () {
      return {
        unmute: this.$pgettext('Sidebar/Player/Icon.Tooltip/Verb', 'Unmute'),
        mute: this.$pgettext('Sidebar/Player/Icon.Tooltip/Verb', 'Mute'),
        slider: this.$pgettext('Sidebar/Player/Icon.Tooltip/Verb', 'Adjust volume')
      }
    }
  },
  methods: {
    ...mapActions({
      mute: 'player/mute',
      unmute: 'player/unmute',
      toggleMute: 'player/toggleMute'
    }),
    handleOver () {
      if (this.timeout) {
        clearTimeout(this.timeout)
      }
      this.expanded = true
    },
    handleLeave () {
      if (this.timeout) {
        clearTimeout(this.timeout)
      }
      this.timeout = setTimeout(() => { this.expanded = false }, 500)
    }
  }
}
</script>
