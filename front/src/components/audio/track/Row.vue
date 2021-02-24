<template>
  <tr>
    <td>
      <play-button :class="['basic', {vibrant: currentTrack && isPlaying && track.id === currentTrack.id}, 'icon']"
        :discrete="true"
        :is-playable="playable"
        :track="track"
        :track-index="trackIndex"
        :tracks="tracks"></play-button>
    </td>
    <td>
      <img alt="" class="ui mini image" v-if="track.album && track.album.cover && track.album.cover.urls.original" v-lazy="$store.getters['instance/absoluteUrl'](track.album.cover.urls.medium_square_crop)">
      <img alt="" class="ui mini image" v-else src="../../../assets/audio/default-cover.png">
    </td>
    <td colspan="6">
      <button class="track" @click.stop="playSong()">
        <template v-if="displayPosition && track.position">
          {{ track.position }}.
        </template>
        {{ track.title|truncate(40) }}
      </button>
    </td>
    <td colspan="4">
      <router-link class="artist discrete link" :to="{name: 'library.artists.detail', params: {id: track.artist.id }}">
        {{ track.artist.name|truncate(40) }}
      </router-link>
    </td>
    <td colspan="4">
      <router-link v-if="track.album" class="album discrete link" :to="{name: 'library.albums.detail', params: {id: track.album.id }}">
        {{ track.album.title|truncate(40) }}
      </router-link>
    </td>
    <td colspan="4" v-if="track.uploads && track.uploads.length > 0">
      <human-duration :duration="track.uploads[0].duration"></human-duration>
    </td>
    <td colspan="4" v-else>
      <translate translate-context="*/*/*">N/A</translate>
    </td>
    <td colspan="2" v-if="displayActions" class="align right">
      <track-favorite-icon class="favorite-icon" :track="track"></track-favorite-icon>
      <track-playlist-icon
        v-if="$store.state.auth.authenticated"
        :track="track"></track-playlist-icon>
      <play-button
        class="play-button basic icon"
        :dropdown-only="true"
        :is-playable="track.is_playable"
        :dropdown-icon-classes="['ellipsis', 'vertical', 'large really discrete']"
        :track="track"
      ></play-button>
    </td>
  </tr>
</template>

<script>
import { mapGetters } from "vuex"
import TrackFavoriteIcon from '@/components/favorites/TrackFavoriteIcon'
import TrackPlaylistIcon from '@/components/playlists/TrackPlaylistIcon'
import PlayButton from '@/components/audio/PlayButton'

export default {
  props: {
    track: {type: Object, required: true},
    trackIndex: {type: Number, required: true},
    tracks: {type: Array, required: false},
    artist: {type: Object, required: false},
    displayPosition: {type: Boolean, default: false},
    displayActions: {type: Boolean, default: true},
    playable: {type: Boolean, required: false, default: false},
  },
  components: {
    TrackFavoriteIcon,
    TrackPlaylistIcon,
    PlayButton
  },
  computed: {
    ...mapGetters({
      currentTrack: "queue/currentTrack",
    }),
    isPlaying () {
      return this.$store.state.player.playing
    },
    albumArtist () {
      if (this.artist) {
        return this.artist
      } else {
        return this.track.album.artist
      }
    },
  },
  methods: {
    playSong () {
      this.$store.dispatch('queue/clean')
      this.$store.dispatch('queue/appendMany', {
        tracks: this.tracks
      }).then(() => {
        this.$store.dispatch('queue/currentIndex', this.trackIndex)
      })
    },
  }
}
</script>
