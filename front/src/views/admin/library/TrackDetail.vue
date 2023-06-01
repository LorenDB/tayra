<script setup lang="ts">
import { humanSize, truncate } from '~/utils/filters'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import { ref, computed } from 'vue'

import axios from 'axios'

import FetchButton from '~/components/federation/FetchButton.vue'
import TagsList from '~/components/tags/List.vue'

import useErrorHandler from '~/composables/useErrorHandler'

interface Props {
  id: number
}

const props = defineProps<Props>()

const { t } = useI18n()
const labels = computed(() => ({
  statsWarning: t('views.admin.library.TrackDetail.warning.stats')
}))

const track = ref()
const isLoading = ref(false)
const fetchData = async () => {
  isLoading.value = true

  try {
    const response = await axios.get(`manage/library/tracks/${props.id}/`)
    track.value = response.data
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoading.value = false
}

const stats = ref()
const isLoadingStats = ref(false)
const fetchStats = async () => {
  isLoadingStats.value = true

  try {
    const response = await axios.get(`manage/library/tracks/${props.id}/stats/`)
    stats.value = response.data
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoadingStats.value = false
}

fetchData()
fetchStats()

const router = useRouter()
const remove = async () => {
  isLoading.value = true

  try {
    await axios.delete(`manage/library/tracks/${props.id}/`)
    await router.push({ name: 'manage.library.tracks' })
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoading.value = false
}

const getQuery = (field: string, value: string) => `${field}:"${value}"`
</script>

<template>
  <main>
    <div
      v-if="isLoading"
      class="ui vertical segment"
    >
      <div :class="['ui', 'centered', 'active', 'inline', 'loader']" />
    </div>
    <template v-if="track">
      <section
        v-title="track.title"
        :class="['ui', 'head', 'vertical', 'stripe', 'segment']"
      >
        <div class="ui stackable one column grid">
          <div class="ui column">
            <div class="segment-content">
              <h2 class="ui header">
                <img
                  v-if="track.cover && track.cover.urls.medium_square_crop"
                  v-lazy="$store.getters['instance/absoluteUrl'](track.cover.urls.medium_square_crop)"
                  alt=""
                >
                <img
                  v-else
                  alt=""
                  src="../../../assets/audio/default-cover.png"
                >
                <div class="content">
                  {{ truncate(track.title) }}
                  <div class="sub header">
                    <template v-if="track.is_local">
                      <span class="ui tiny accent label">
                        <i class="home icon" />
                        {{ $t('views.admin.library.TrackDetail.header.local') }}
                      </span>
                      &nbsp;
                    </template>
                  </div>
                </div>
              </h2>

              <template v-if="track.tags && track.tags.length > 0">
                <tags-list
                  :limit="5"
                  detail-route="manage.library.tags.detail"
                  :tags="track.tags"
                />
                <div class="ui hidden divider" />
              </template>

              <div class="header-buttons">
                <div class="ui icon buttons">
                  <router-link
                    class="ui icon labeled button"
                    :to="{name: 'library.tracks.detail', params: {id: track.id }}"
                  >
                    <i class="info icon" />
                    {{ $t('views.admin.library.TrackDetail.link.localProfile') }}
                  </router-link>
                  <button
                    v-dropdown
                    class="ui floating dropdown icon button"
                  >
                    <i class="dropdown icon" />
                    <div class="menu">
                      <a
                        v-if="$store.state.auth.profile && $store.state.auth.profile.is_superuser"
                        class="basic item"
                        :href="$store.getters['instance/absoluteUrl'](`/api/admin/music/track/${track.id}`)"
                        target="_blank"
                        rel="noopener noreferrer"
                      >
                        <i class="wrench icon" />
                        {{ $t('views.admin.library.TrackDetail.link.django') }}
                      </a>
                      <a
                        v-if="track.mbid"
                        class="basic item"
                        :href="`https://musicbrainz.org/recording/${track.mbid}`"
                        target="_blank"
                        rel="noopener noreferrer"
                      >
                        <i class="external icon" />
                        {{ $t('views.admin.library.TrackDetail.link.musicbrainz') }}
                      </a>
                      <fetch-button
                        v-if="!track.is_local"
                        class="basic item"
                        :url="`tracks/${track.id}/fetches/`"
                        @refresh="fetchData"
                      >
                        <i class="refresh icon" />&nbsp;
                        {{ $t('views.admin.library.TrackDetail.button.remoteRefresh') }}
                      </fetch-button>
                      <a
                        class="basic item"
                        :href="track.url || track.fid"
                        target="_blank"
                        rel="noopener noreferrer"
                      >
                        <i class="external icon" />
                        {{ $t('views.admin.library.TrackDetail.link.remoteProfile') }}
                      </a>
                    </div>
                  </button>
                </div>
                <div class="ui buttons">
                  <router-link
                    v-if="track.is_local"
                    :to="{name: 'library.tracks.edit', params: {id: track.id }}"
                    class="ui labeled icon button"
                  >
                    <i class="edit icon" />
                    {{ $t('views.admin.library.TrackDetail.button.edit') }}
                  </router-link>
                </div>
                <div class="ui buttons">
                  <dangerous-button
                    :class="['ui', {loading: isLoading}, 'basic danger button']"
                    :action="remove"
                  >
                    {{ $t('views.admin.library.TrackDetail.button.delete') }}
                    <template #modal-header>
                      <p>
                        {{ $t('views.admin.library.TrackDetail.modal.delete.header') }}
                      </p>
                    </template>
                    <template #modal-content>
                      <div>
                        <p>
                          {{ $t('views.admin.library.TrackDetail.modal.delete.content.warning') }}
                        </p>
                      </div>
                    </template>
                    <template #modal-confirm>
                      <p>
                        {{ $t('views.admin.library.TrackDetail.button.delete') }}
                      </p>
                    </template>
                  </dangerous-button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>
      <div class="ui vertical stripe segment">
        <div class="ui stackable three column grid">
          <div class="column">
            <section>
              <h3 class="ui header">
                <i class="info icon" />
                <div class="content">
                  {{ $t('views.admin.library.TrackDetail.header.trackData') }}
                </div>
              </h3>
              <table class="ui very basic table">
                <tbody>
                  <tr>
                    <td>
                      {{ $t('views.admin.library.TrackDetail.table.track.title') }}
                    </td>
                    <td>
                      {{ track.title }}
                    </td>
                  </tr>
                  <tr v-if="track.album">
                    <td>
                      <router-link :to="{name: 'manage.library.albums.detail', params: {id: track.album.id }}">
                        {{ $t('views.admin.library.TrackDetail.link.album') }}
                      </router-link>
                    </td>
                    <td>
                      {{ track.album.title }}
                    </td>
                  </tr>

                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.artists.detail', params: {id: track.artist.id }}">
                        {{ $t('views.admin.library.TrackDetail.link.artist') }}
                      </router-link>
                    </td>
                    <td>
                      {{ track.artist.name }}
                    </td>
                  </tr>
                  <tr v-if="track.album">
                    <td>
                      <router-link :to="{name: 'manage.library.artists.detail', params: {id: track.album.artist.id }}">
                        {{ $t('views.admin.library.TrackDetail.link.albumArtist') }}
                      </router-link>
                    </td>
                    <td>
                      {{ track.album.artist.name }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      {{ $t('views.admin.library.TrackDetail.table.track.position') }}
                    </td>
                    <td>
                      {{ track.position }}
                    </td>
                  </tr>
                  <tr v-if="track.disc_number">
                    <td>
                      {{ $t('views.admin.library.TrackDetail.table.track.discNumber') }}
                    </td>
                    <td>
                      {{ track.disc_number }}
                    </td>
                  </tr>
                  <tr v-if="track.copyright">
                    <td>
                      {{ $t('views.admin.library.TrackDetail.table.track.copyright') }}
                    </td>
                    <td>{{ track.copyright }}</td>
                  </tr>
                  <tr v-if="track.license">
                    <td>
                      {{ $t('views.admin.library.TrackDetail.table.track.license') }}
                    </td>
                    <td>
                      <router-link :to="{name: 'manage.library.tracks', query: {q: getQuery('license', track.license)}}">
                        {{ track.license }}
                      </router-link>
                    </td>
                  </tr>
                  <tr v-if="!track.is_local">
                    <td>
                      <router-link :to="{name: 'manage.moderation.domains.detail', params: {id: track.domain }}">
                        {{ $t('views.admin.library.TrackDetail.link.domain') }}
                      </router-link>
                    </td>
                    <td>
                      {{ track.domain }}
                    </td>
                  </tr>
                  <tr v-if="track.description">
                    <td>
                      {{ $t('views.admin.library.TrackDetail.table.track.description') }}
                    </td>
                    <sanitized-html
                      tag="td"
                      :html="track.description.html"
                    />
                  </tr>
                </tbody>
              </table>
            </section>
          </div>
          <div class="column">
            <section>
              <h3 class="ui header">
                <i class="feed icon" />
                <div class="content">
                  {{ $t('views.admin.library.TrackDetail.header.activity') }}&nbsp;
                  <span :data-tooltip="labels.statsWarning"><i class="question circle icon" /></span>
                </div>
              </h3>
              <div
                v-if="isLoadingStats"
                class="ui placeholder"
              >
                <div class="full line" />
                <div class="short line" />
                <div class="medium line" />
                <div class="long line" />
              </div>
              <table
                v-else
                class="ui very basic table"
              >
                <tbody>
                  <tr>
                    <td>
                      {{ $t('views.admin.library.TrackDetail.table.activity.firstSeen') }}
                    </td>
                    <td>
                      <human-date :date="track.creation_date" />
                    </td>
                  </tr>
                  <tr>
                    <td>
                      {{ $t('views.admin.library.TrackDetail.table.activity.listenings') }}
                    </td>
                    <td>
                      {{ stats.listenings }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      {{ $t('views.admin.library.TrackDetail.table.activity.favorited') }}
                    </td>
                    <td>
                      {{ stats.track_favorites }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      {{ $t('views.admin.library.TrackDetail.table.activity.playlists') }}
                    </td>
                    <td>
                      {{ stats.playlists }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.moderation.reports.list', query: {q: getQuery('target', `track:${track.id}`) }}">
                        {{ $t('views.admin.library.TrackDetail.link.reports') }}
                      </router-link>
                    </td>
                    <td>
                      {{ stats.reports }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.edits', query: {q: getQuery('target', 'track ' + track.id)}}">
                        {{ $t('views.admin.library.TrackDetail.link.edits') }}
                      </router-link>
                    </td>
                    <td>
                      {{ stats.mutations }}
                    </td>
                  </tr>
                </tbody>
              </table>
            </section>
          </div>
          <div class="column">
            <section>
              <h3 class="ui header">
                <i class="music icon" />
                <div class="content">
                  {{ $t('views.admin.library.TrackDetail.header.trackData') }}&nbsp;
                  <span :data-tooltip="labels.statsWarning"><i class="question circle icon" /></span>
                </div>
              </h3>
              <div
                v-if="isLoadingStats"
                class="ui placeholder"
              >
                <div class="full line" />
                <div class="short line" />
                <div class="medium line" />
                <div class="long line" />
              </div>
              <table
                v-else
                class="ui very basic table"
              >
                <tbody>
                  <tr>
                    <td>
                      {{ $t('views.admin.library.TrackDetail.table.trackData.cachedSize') }}
                    </td>
                    <td>
                      {{ humanSize(stats.media_downloaded_size) }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      {{ $t('views.admin.library.TrackDetail.table.trackData.totalSize') }}
                    </td>
                    <td>
                      {{ humanSize(stats.media_total_size) }}
                    </td>
                  </tr>

                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.libraries', query: {q: getQuery('track_id', track.id) }}">
                        {{ $t('views.admin.library.TrackDetail.link.libraries') }}
                      </router-link>
                    </td>
                    <td>
                      {{ stats.libraries }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.uploads', query: {q: getQuery('track_id', track.id) }}">
                        {{ $t('views.admin.library.TrackDetail.link.uploads') }}
                      </router-link>
                    </td>
                    <td>
                      {{ stats.uploads }}
                    </td>
                  </tr>
                </tbody>
              </table>
            </section>
          </div>
        </div>
      </div>
    </template>
  </main>
</template>
