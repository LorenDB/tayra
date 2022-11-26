<script setup lang="ts">
import type { Track, Library } from '~/types'

import { humanSize, momentFormat, truncate } from '~/utils/filters'
import { computed, ref, watchEffect } from 'vue'

import time from '~/utils/time'
import axios from 'axios'

import LibraryWidget from '~/components/federation/LibraryWidget.vue'
import PlaylistWidget from '~/components/playlists/Widget.vue'
import TagsList from '~/components/tags/List.vue'

import useErrorHandler from '~/composables/useErrorHandler'

interface Events {
  (e: 'libraries-loaded', libraries: Library[]): void
}

interface Props {
  track: Track
}

const emit = defineEmits<Events>()
const props = defineProps<Props>()

const musicbrainzUrl = computed(() => props.track.mbid
  ? `https://musicbrainz.org/recording/${props.track.mbid}`
  : null
)

const upload = computed(() => props.track.uploads?.[0] ?? null)

const license = ref()
const fetchLicense = async (licenseId: string) => {
  license.value = undefined

  try {
    const response = await axios.get(`licenses/${licenseId}`)
    license.value = response.data
  } catch (error) {
    useErrorHandler(error as Error)
  }
}

watchEffect(() => {
  if (props.track.license) {
    // @ts-expect-error For some reason, track.license is id instead of License here
    fetchLicense(props.track.license)
  }
})
</script>

<template>
  <div v-if="track">
    <section class="ui vertical stripe segment">
      <div class="ui stackable grid row container">
        <div class="six wide column">
          <template v-if="upload">
            <img
              v-if="track.cover && track.cover.urls.large_square_crop"
              v-lazy="$store.getters['instance/absoluteUrl'](track.cover.urls.large_square_crop)"
              alt="Cover Image"
              class="ui fluid image track-cover-image"
            >
            <img
              v-else-if="track.album && track.album.cover && track.album.cover.urls.large_square_crop"
              v-lazy="$store.getters['instance/absoluteUrl'](track.album.cover.urls.large_square_crop)"
              alt="Cover Image"
              class="ui fluid image track-cover-image"
            >
            <img
              v-else
              src="../../assets/audio/default-cover.png"
              alt="Cover Image"
              class="ui fluid image track-cover-image"
            >
            <h3 class="ui header">
              <span v-if="track.artist?.content_category === 'music'">
                {{ $t('components.library.TrackDetail.header.track') }}
              </span>
              <span v-else>
                {{ $t('components.library.TrackDetail.header.episode') }}
              </span>
            </h3>
            <table class="ui basic table">
              <tbody>
                <tr>
                  <td>
                    {{ $t('components.library.TrackDetail.table.track.duration') }}
                  </td>
                  <td class="right aligned">
                    <template v-if="upload.duration">
                      {{ time.parse(upload.duration) }}
                    </template>
                    <span v-else>
                      {{ $t('components.library.TrackDetail.notApplicable') }}
                    </span>
                  </td>
                </tr>
                <tr>
                  <td>
                    {{ $t('components.library.TrackDetail.table.track.size') }}
                  </td>
                  <td class="right aligned">
                    <template v-if="upload.size">
                      {{ humanSize(upload.size) }}
                    </template>
                    <span v-else>
                      {{ $t('components.library.TrackDetail.notApplicable') }}
                    </span>
                  </td>
                </tr>
                <tr>
                  <td>
                    {{ $t('components.library.TrackDetail.table.track.codec') }}
                  </td>
                  <td class="right aligned">
                    <template v-if="upload.extension">
                      {{ upload.extension }}
                    </template>
                    <span v-else>
                      {{ $t('components.library.TrackDetail.notApplicable') }}
                    </span>
                  </td>
                </tr>
                <tr>
                  <td>
                    {{ $t('components.library.TrackDetail.table.track.bitrate.label') }}
                  </td>
                  <td class="right aligned">
                    <template v-if="upload.bitrate">
                      {{ $t('components.library.TrackDetail.table.track.bitrate.value', {bitrate: humanSize(upload.bitrate)}) }}
                    </template>
                    <span v-else>
                      {{ $t('components.library.TrackDetail.notApplicable') }}
                    </span>
                  </td>
                </tr>
                <tr>
                  <td>
                    {{ $t('components.library.TrackDetail.table.track.downloads') }}
                  </td>
                  <td class="right aligned">
                    {{ track.downloads_count }}
                  </td>
                </tr>
              </tbody>
            </table>
          </template>
        </div>
        <div class="ten wide column">
          <template v-if="track.tags && track.tags.length > 0">
            <tags-list :tags="track.tags" />
            <div class="ui hidden divider" />
          </template>

          <rendered-description
            :content="track.description"
            :can-update="false"
          />
          <h2 class="ui header">
            {{ $t('components.library.TrackDetail.header.release') }}
          </h2>
          <table class="ui basic table ellipsis-rows">
            <tbody>
              <tr>
                <td>
                  {{ $t('components.library.TrackDetail.table.release.artist') }}
                </td>
                <td class="right aligned">
                  <router-link :to="{name: 'library.artists.detail', params: {id: track.artist?.id}}">
                    {{ track.artist?.name }}
                  </router-link>
                </td>
              </tr>
              <tr v-if="track.album">
                <td>
                  <span v-if="track.album.artist.content_category === 'music'">
                    {{ $t('components.library.TrackDetail.table.release.album') }}
                  </span>
                  <span v-else>
                    {{ $t('components.library.TrackDetail.table.release.series') }}
                  </span>
                </td>
                <td class="right aligned">
                  <router-link :to="{name: 'library.albums.detail', params: {id: track.album.id}}">
                    {{ track.album.title }}
                  </router-link>
                </td>
              </tr>
              <tr>
                <td>
                  {{ $t('components.library.TrackDetail.table.release.year') }}
                </td>
                <td class="right aligned">
                  <template v-if="track.album && track.album.release_date">
                    {{ momentFormat(new Date(track.album.release_date), 'Y') }}
                  </template>
                  <template v-else>
                    {{ $t('components.library.TrackDetail.notApplicable') }}
                  </template>
                </td>
              </tr>
              <tr>
                <td>
                  {{ $t('components.library.TrackDetail.table.release.copyright') }}
                </td>
                <td class="right aligned">
                  <span
                    v-if="track.copyright"
                    :title="track.copyright"
                  >{{ truncate(track.copyright, 50) }}</span>
                  <template v-else>
                    {{ $t('components.library.TrackDetail.notApplicable') }}
                  </template>
                </td>
              </tr>
              <tr>
                <td>
                  {{ $t('components.library.TrackDetail.table.release.license') }}
                </td>
                <td class="right aligned">
                  <a
                    v-if="license"
                    :href="license.url"
                    target="_blank"
                    rel="noopener noreferrer"
                  >{{ license.name }}</a>
                  <span v-else>
                    {{ $t('components.library.TrackDetail.notApplicable') }}
                  </span>
                </td>
              </tr>
              <tr v-if="!track.is_local">
                <td>
                  {{ $t('components.library.TrackDetail.table.release.url') }}
                </td>
                <td :title="track.fid">
                  <a
                    :href="track.fid"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    {{ truncate(track.fid, 65) }}
                  </a>
                </td>
              </tr>
            </tbody>
          </table>
          <a
            v-if="musicbrainzUrl"
            :href="musicbrainzUrl"
            target="_blank"
            rel="noreferrer noopener"
          >
            <i class="external icon" />
            {{ $t('components.library.TrackDetail.link.musicbrainz') }}
          </a>
          <h2 class="ui header">
            {{ $t('components.library.TrackDetail.header.playlists') }}
          </h2>
          <playlist-widget
            :url="'playlists/'"
            :filters="{track: track.id, playable: true, ordering: '-modification_date'}"
          />

          <h2 class="ui header">
            {{ $t('components.library.TrackDetail.header.library') }}
          </h2>
          <library-widget
            :url="`tracks/${track.id}/libraries/`"
            @loaded="emit('libraries-loaded', $event)"
          >
            {{ $t('components.library.TrackDetail.description.library') }}
          </library-widget>
        </div>
      </div>
    </section>
  </div>
</template>
