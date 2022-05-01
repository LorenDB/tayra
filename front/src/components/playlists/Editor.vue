<template>
  <div class="ui text container component-playlist-editor">
    <playlist-form
      :title="false"
      :playlist="playlist"
      @updated="$emit('playlist-updated', $event)"
    />
    <h3 class="ui top attached header">
      <translate translate-context="Content/Playlist/Title">
        Playlist editor
      </translate>
    </h3>
    <div class="ui attached segment">
      <template v-if="status === 'loading'">
        <div class="ui active tiny inline loader" />
        <translate translate-context="Content/Playlist/Paragraph">
          Syncing changes to server…
        </translate>
      </template>
      <template v-else-if="status === 'errored'">
        <i class="dangerclose icon" />
        <translate translate-context="Content/Playlist/Error message.Title">
          An error occurred while saving your changes
        </translate>
        <div
          v-if="errors.length > 0"
          role="alert"
          class="ui negative message"
        >
          <ul class="list">
            <li
              v-for="(error, key) in errors"
              :key="key"
            >
              {{ error }}
            </li>
          </ul>
        </div>
      </template>
      <div
        v-else-if="status === 'confirmDuplicateAdd'"
        role="alert"
        class="ui warning message"
      >
        <p
          v-translate="{playlist: playlist.name}"
          translate-context="Content/Playlist/Paragraph"
        >
          Some tracks in your queue are already in this playlist:
        </p>
        <ul class="ui relaxed divided list duplicate-tracks-list">
          <li
            v-for="(track, key) in duplicateTrackAddInfo.tracks"
            :key="key"
            class="ui item"
          >
            {{ track }}
          </li>
        </ul>
        <button
          class="ui small success button"
          @click="insertMany(queueTracks, true)"
        >
          <translate translate-context="*/Playlist/Button.Label/Verb">
            Add anyways
          </translate>
        </button>
      </div>
      <template v-else-if="status === 'saved'">
        <i class="success check icon" /> <translate translate-context="Content/Playlist/Paragraph">
          Changes synced with server
        </translate>
      </template>
    </div>
    <div class="ui bottom attached segment">
      <button
        :disabled="queueTracks.length === 0"
        :class="['ui', {disabled: queueTracks.length === 0}, 'labeled', 'icon', 'button']"
        :title="labels.copyTitle"
        @click="insertMany(queueTracks, false)"
      >
        <i class="plus icon" />
        <translate
          translate-context="Content/Playlist/Button.Label/Verb"
          translate-plural="Insert from queue (%{ count } tracks)"
          :translate-n="queueTracks.length"
          :translate-params="{count: queueTracks.length}"
        >
          Insert from queue (%{ count } track)
        </translate>
      </button>

      <dangerous-button
        :disabled="plts.length === 0"
        class="ui labeled right floated danger icon button"
        :action="clearPlaylist"
      >
        <i class="eraser icon" /> <translate translate-context="*/Playlist/Button.Label/Verb">
          Clear playlist
        </translate>
        <p
          slot="modal-header"
          v-translate="{playlist: playlist.name}"
          translate-context="Popup/Playlist/Title"
          :translate-params="{playlist: playlist.name}"
        >
          Do you want to clear the playlist "%{ playlist }"?
        </p>
        <p slot="modal-content">
          <translate translate-context="Popup/Playlist/Paragraph">
            This will remove all tracks from this playlist and cannot be undone.
          </translate>
        </p>
        <div slot="modal-confirm">
          <translate translate-context="*/Playlist/Button.Label/Verb">
            Clear playlist
          </translate>
        </div>
      </dangerous-button>
      <div class="ui hidden divider" />
      <template v-if="plts.length > 0">
        <p>
          <translate translate-context="Content/Playlist/Paragraph/Call to action">
            Drag and drop rows to reorder tracks in the playlist
          </translate>
        </p>
        <div class="table-wrapper">
          <table class="ui compact very basic unstackable table">
            <draggable
              v-model:list="plts"
              tag="tbody"
              @update="reorder"
              item-key="_id"
            >
              <template #item="{ element: plt, index }">
                <tr>
                  <td class="left aligned">
                    {{ plt.index + 1 }}
                  </td>
                  <td class="center aligned">
                    <img
                      v-if="plt.track.album && plt.track.album.cover && plt.track.album.cover.urls.original"
                      v-lazy="$store.getters['instance/absoluteUrl'](plt.track.album.cover.urls.medium_square_crop)"
                      alt=""
                      class="ui mini image"
                    >
                    <img
                      v-else
                      alt=""
                      class="ui mini image"
                      src="../../assets/audio/default-cover.png"
                    >
                  </td>
                  <td colspan="4">
                    <strong>{{ plt.track.title }}</strong><br>
                    {{ plt.track.artist.name }}
                  </td>
                  <td class="right aligned">
                    <button
                      class="ui circular danger basic icon button"
                      @click.stop="removePlt(index)"
                    >
                      <i
                        class="trash icon"
                      />
                    </button>
                  </td>
                </tr>
              </template>
            </draggable>
          </table>
        </div>
      </template>
    </div>
  </div>
</template>

<script>
import { mapState } from 'vuex'
import { computed } from 'vue'
import axios from 'axios'
import PlaylistForm from '~/components/playlists/Form.vue'

import draggable from 'vuedraggable'

export default {
  components: {
    draggable,
    PlaylistForm
  },
  props: {
    playlist: { type: Object, required: true },
    playlistTracks: { type: Array, required: true }
  },
  setup (props) {
    const plts = computed(() => {
      return props.playlistTracks.map((plt, index) => ({ ...plt, _id: `${index}-${plt.track.id}` }))
    })

    return { plts }
  },
  data () {
    return {
      isLoading: false,
      errors: [],
      duplicateTrackAddInfo: {},
      showDuplicateTrackAddConfirmation: false
    }
  },
  computed: {
    ...mapState({
      queueTracks: state => state.queue.tracks
    }),
    labels () {
      return {
        copyTitle: this.$pgettext('Content/Playlist/Button.Tooltip/Verb', 'Copy the current queue to this playlist')
      }
    },
    status () {
      if (this.isLoading) {
        return 'loading'
      }
      if (this.errors.length > 0) {
        return 'errored'
      }
      if (this.showDuplicateTrackAddConfirmation) {
        return 'confirmDuplicateAdd'
      }
      return 'saved'
    }
  },
  watch: {
    plts: {
      handler (newValue) {
        newValue.forEach((e, i) => {
          e.index = i
        })
        this.$emit('tracks-updated', newValue)
      },
      deep: true
    }
  },
  methods: {
    success () {
      this.isLoading = false
      this.errors = []
      this.showDuplicateTrackAddConfirmation = false
    },
    errored (errors) {
      this.isLoading = false
      if (errors.length === 1 && errors[0].code === 'tracks_already_exist_in_playlist') {
        this.duplicateTrackAddInfo = errors[0]
        this.showDuplicateTrackAddConfirmation = true
      } else {
        this.errors = errors
      }
    },
    reorder ({ oldIndex, newIndex }) {
      const self = this
      self.isLoading = true
      const url = `playlists/${this.playlist.id}/move`
      axios.post(url, { from: oldIndex, to: newIndex }).then((response) => {
        self.success()
      }, error => {
        self.errored(error.backendErrors)
      })
    },
    removePlt (index) {
      this.plts.splice(index, 1)
      const self = this
      self.isLoading = true
      const url = `playlists/${this.playlist.id}/remove`
      axios.post(url, { index }).then((response) => {
        self.success()
        self.$store.dispatch('playlists/fetchOwn')
      }, error => {
        self.errored(error.backendErrors)
      })
    },
    clearPlaylist () {
      this.plts = []
      const self = this
      self.isLoading = true
      const url = 'playlists/' + this.playlist.id + '/clear'
      axios.delete(url).then((response) => {
        self.success()
        self.$store.dispatch('playlists/fetchOwn')
      }, error => {
        self.errored(error.backendErrors)
      })
    },
    insertMany (tracks, allowDuplicates) {
      const self = this
      const ids = tracks.map(t => {
        return t.id
      })
      const payload = {
        tracks: ids,
        allow_duplicates: allowDuplicates
      }
      self.isLoading = true
      const url = 'playlists/' + this.playlist.id + '/add/'
      axios.post(url, payload).then((response) => {
        response.data.results.forEach(r => {
          self.plts.push(r)
        })
        self.success()
        self.$store.dispatch('playlists/fetchOwn')
      }, error => {
        // if backendErrors isn't populated (e.g. duplicate track exceptions raised by
        // the playlist model), read directly from the response
        if (error.rawPayload.playlist) {
          self.errored(error.rawPayload.playlist)
        } else {
          self.errored(error.backendErrors)
        }
      })
    }
  }
}
</script>
