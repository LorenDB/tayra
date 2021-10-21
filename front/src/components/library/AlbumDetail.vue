<template>
  <div v-if="object">
    <h2 class="ui header">
      <translate key="1" v-if="isSerie" translate-context="Content/Channels/*">Episodes</translate>
      <translate key="2" v-else translate-context="*/*/*">Tracks</translate>
    </h2>
    <channel-entries v-if="artist.channel && isSerie" :is-podcast="isSerie" :limit="50" :filters="{channel: artist.channel.uuid, album: object.id, ordering: '-creation_date'}">
    </channel-entries>
    <template v-else-if="discs && discs.length > 1">
      <div v-for="tracks in discs" :key="tracks.disc_number">
        <div class="ui hidden divider"></div>
        <play-button class="right floated mini inverted vibrant" :tracks="tracks"></play-button>
        <translate
          tag="h3"
          :translate-params="{number: tracks[0].disc_number}"
          translate-context="Content/Album/"
        >Volume %{ number }</translate>
        <track-table 
          :is-album="true"
          :tracks="object.tracks"
          :show-position="true"
          :show-art="false"
          :show-album="false"
          :show-artist="false"
          :paginate-results="true"
          :total="totalTracks"
          :paginate-by="paginateBy"
          :page="page"
          @page-changed="updatePage">
        </track-table>
      </div>
    </template>
    <template v-else>
      <track-table 
        :is-album="true"
        :tracks="object.tracks"
        :show-position="true"
        :show-art="false"
        :show-album="false"
        :show-artist="false"
        :paginate-results="true"
        :total="totalTracks"
        :paginate-by="paginateBy"
        :page="page"
        @page-changed="updatePage">
      </track-table>
    </template>
    <template v-if="!artist.channel && !isSerie">
      <h2>
        <translate translate-context="Content/*/Title/Noun">User libraries</translate>
      </h2>
      <library-widget @loaded="$emit('libraries-loaded', $event)" :url="'albums/' + object.id + '/libraries/'">
        <translate slot="subtitle" translate-context="Content/Album/Paragraph">This album is present in the following libraries:</translate>
      </library-widget>
    </template>
  </div>
</template>

<script>

import time from "@/utils/time"
import LibraryWidget from "@/components/federation/LibraryWidget"
import ChannelEntries from '@/components/audio/ChannelEntries'
import TrackTable from '@/components/audio/track/Table'
import PlayButton from "@/components/audio/PlayButton"

export default {
  props: ["object", "libraries", "discs", "isSerie", "artist", "page", "paginateBy", "totalTracks"],
  components: {
    LibraryWidget,
    TrackTable,
    ChannelEntries,
    PlayButton
  },
  data() {
    return {
      time,
      id: this.object.id,
    }
  },
  methods: {
    updatePage: function(page) {
      this.$emit('page-changed', page)
    }
  },
}
</script>
