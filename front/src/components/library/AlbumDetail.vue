<script setup lang="ts">
import type { Artist, Album, Library, Track } from '~/types'

import LibraryWidget from '~/components/federation/LibraryWidget.vue'
import ChannelEntries from '~/components/audio/ChannelEntries.vue'
import TrackTable from '~/components/audio/track/Table.vue'
import PlayButton from '~/components/audio/PlayButton.vue'

interface Emits {
  (e: 'page-changed', page: number): void
  (e: 'libraries-loaded', libraries: Library[]): void
}

interface Props {
  object: Album

  discs: Track[][]

  isSerie: boolean
  artist: Artist
  page: number
  paginateBy: number
  totalTracks: number
}

const emit = defineEmits<Emits>()
defineProps<Props>()

const getDiscKey = (disc: Track[]) => disc.map(track => track.id).join('|')
</script>

<template>
  <div v-if="object">
    <h2 class="ui header">
      <translate
        v-if="isSerie"
        translate-context="Content/Channels/*"
      >
        Episodes
      </translate>
      <translate
        v-else
        translate-context="*/*/*"
      >
        Tracks
      </translate>
    </h2>
    <channel-entries
      v-if="artist.channel && isSerie"
      :is-podcast="isSerie"
      :limit="50"
      :filters="{channel: artist.channel.uuid, album: object.id, ordering: '-creation_date'}"
    />
    <template v-else-if="discs.length > 1">
      <div
        v-for="tracks in discs"
        :key="getDiscKey(tracks)"
      >
        <div class="ui hidden divider" />
        <play-button
          class="right floated mini inverted vibrant"
          :tracks="tracks"
        />
        <translate
          tag="h3"
          :translate-params="{number: tracks[0].disc_number}"
          translate-context="Content/Album/"
        >
          Volume %{ number }
        </translate>
        <track-table
          :is-album="true"
          :tracks="tracks"
          :show-position="true"
          :show-art="false"
          :show-album="false"
          :show-artist="false"
          :paginate-results="true"
          :total="totalTracks"
          :paginate-by="paginateBy"
          :page="page"
          @page-changed="emit('page-changed', page)"
        />
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
        @page-changed="emit('page-changed', page)"
      />
    </template>
    <template v-if="!artist.channel && !isSerie">
      <h2>
        <translate translate-context="Content/*/Title/Noun">
          User libraries
        </translate>
      </h2>
      <library-widget
        :url="'albums/' + object.id + '/libraries/'"
        @loaded="emit('libraries-loaded', $event)"
      >
        <translate translate-context="Content/Album/Paragraph">
          This album is present in the following libraries:
        </translate>
      </library-widget>
    </template>
  </div>
</template>
