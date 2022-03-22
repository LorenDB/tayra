<template>
  <div>
    <label for="album-dropdown">
      <translate
        v-if="channel && channel.artist && channel.artist.content_category === 'podcast'"
        key="1"
        translate-context="*/*/*"
      >Series</translate>
      <translate
        v-else
        key="2"
        translate-context="*/*/*"
      >Album</translate>
    </label>
    <select
      id="album-dropdown"
      :value="value"
      class="ui search normal dropdown"
      @input="$emit('input', $event.target.value)"
    >
      <option value="">
        <translate translate-context="*/*/*">
          None
        </translate>
      </option>
      <option
        v-for="album in albums"
        :key="album.id"
        :value="album.id"
      >
        {{ album.title }} (<translate
          translate-context="*/*/*"
          :translate-params="{count: album.tracks_count}"
          :translate-n="album.tracks_count"
          translate-plural="%{ count } tracks"
        >
          %{ count } track
        </translate>)
      </option>
    </select>
  </div>
</template>
<script>
import axios from 'axios'

export default {
  props: {
    value: { type: Number, default: null },
    channel: { type: Object, default: () => ({}) }
  },
  data () {
    return {
      albums: [],
      isLoading: false
    }
  },
  watch: {
    async channel () {
      await this.fetchData()
    }
  },
  async created () {
    await this.fetchData()
  },
  methods: {
    async fetchData () {
      this.albums = []
      if (!this.channel || !this.channel.artist) {
        return
      }
      this.isLoading = true
      const response = await axios.get('albums/', { params: { artist: this.channel.artist.id, include_channels: 'true' } })
      this.albums = response.data.results
      this.isLoading = false
    }
  }
}
</script>
