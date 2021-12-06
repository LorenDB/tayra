<template>
  <button
    v-if="button"
    :class="['ui', 'icon', 'labeled', 'button']"
    @click.stop="$store.commit('playlists/chooseTrack', track)"
  >
    <i class="list icon" />
    <translate translate-context="Sidebar/Player/Icon.Tooltip/Verb">
      Add to playlist…
    </translate>
  </button>
  <button
    v-else
    :class="['ui', 'basic', 'circular', 'icon', {'really': !border}, 'button']"
    :aria-label="labels.addToPlaylist"
    :title="labels.addToPlaylist"
    @click.stop="$store.commit('playlists/chooseTrack', track)"
  >
    <i :class="['list', 'basic', 'icon']" />
  </button>
</template>

<script>

export default {
  props: {
    track: { type: Object, default: function () { return {} } },
    button: { type: Boolean, default: false },
    border: { type: Boolean, default: false }
  },
  data () {
    return {
      showModal: false
    }
  },
  computed: {
    labels () {
      return {
        addToPlaylist: this.$pgettext('Sidebar/Player/Icon.Tooltip/Verb', 'Add to playlist…')
      }
    }
  }
}
</script>
