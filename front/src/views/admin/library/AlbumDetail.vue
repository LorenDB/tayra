<script setup lang="ts">
import { humanSize, truncate } from '~/utils/filters'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import { computed, ref } from 'vue'

import axios from 'axios'

import FetchButton from '~/components/federation/FetchButton.vue'
import TagsList from '~/components/tags/List.vue'

import useErrorHandler from '~/composables/useErrorHandler'

interface Props {
  id: number
}

const props = defineProps<Props>()

const { t } = useI18n()
const router = useRouter()

const labels = computed(() => ({
  statsWarning: t('views.admin.library.AlbumDetail.warning.stats')
}))

const isLoading = ref(false)
const object = ref()
const fetchData = async () => {
  isLoading.value = true

  try {
    const response = await axios.get(`manage/library/albums/${props.id}/`)
    object.value = response.data
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoading.value = false
}

const isLoadingStats = ref(false)
const stats = ref()
const fetchStats = async () => {
  isLoadingStats.value = true

  try {
    const response = await axios.get(`manage/library/albums/${props.id}/stats/`)
    stats.value = response.data
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoadingStats.value = false
}

fetchStats()
fetchData()

const remove = async () => {
  isLoading.value = true

  try {
    await axios.delete(`manage/library/albums/${props.id}/`)
    router.push({ name: 'manage.library.albums' })
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
    <template v-if="object">
      <section
        v-title="object.title"
        :class="['ui', 'head', 'vertical', 'stripe', 'segment']"
      >
        <div class="ui stackable one column grid">
          <div class="ui column">
            <div class="segment-content">
              <h2 class="ui header">
                <img
                  v-if="object.cover?.urls.original"
                  v-lazy="$store.getters['instance/absoluteUrl'](object.cover.urls.medium_square_crop)"
                  alt=""
                >
                <img
                  v-else
                  alt=""
                  src="../../../assets/audio/default-cover.png"
                >
                <div class="content">
                  {{ truncate(object.title) }}
                  <div class="sub header">
                    <template v-if="object.is_local">
                      <span class="ui tiny accent label">
                        <i class="home icon" />
                        {{ $t('views.admin.library.AlbumDetail.header.local') }}
                      </span>
                      &nbsp;
                    </template>
                  </div>
                </div>
              </h2>

              <template v-if="object.tags && object.tags.length > 0">
                <tags-list
                  :limit="5"
                  detail-route="manage.library.tags.detail"
                  :tags="object.tags"
                />
                <div class="ui hidden divider" />
              </template>

              <div class="header-buttons">
                <div class="ui icon buttons">
                  <router-link
                    class="ui labeled icon button"
                    :to="{name: 'library.albums.detail', params: {id: object.id }}"
                  >
                    <i class="info icon" />
                    {{ $t('views.admin.library.AlbumDetail.link.localProfile') }}
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
                        :href="$store.getters['instance/absoluteUrl'](`/api/admin/music/album/${object.id}`)"
                        target="_blank"
                        rel="noopener noreferrer"
                      >
                        <i class="wrench icon" />
                        {{ $t('views.admin.library.AlbumDetail.link.django') }}
                      </a>
                      <a
                        v-if="object.mbid"
                        class="basic item"
                        :href="`https://musicbrainz.org/release/${object.mbid}`"
                        target="_blank"
                        rel="noopener noreferrer"
                      >
                        <i class="external icon" />
                        {{ $t('views.admin.library.AlbumDetail.link.musicbrainz') }}
                      </a>
                      <fetch-button
                        v-if="!object.is_local"
                        class="basic item"
                        :url="`albums/${object.id}/fetches/`"
                        @refresh="fetchData"
                      >
                        <i class="refresh icon" />&nbsp;
                        {{ $t('views.admin.library.AlbumDetail.button.remoteRefresh') }}
                      </fetch-button>
                      <a
                        class="basic item"
                        :href="object.url || object.fid"
                        target="_blank"
                        rel="noopener noreferrer"
                      >
                        <i class="external icon" />
                        {{ $t('views.admin.library.AlbumDetail.link.remoteProfile') }}
                      </a>
                    </div>
                  </button>
                </div>
                <div class="ui buttons">
                  <router-link
                    v-if="object.is_local"
                    :to="{name: 'library.albums.edit', params: {id: object.id }}"
                    class="ui labeled icon button"
                  >
                    <i class="edit icon" />
                    {{ $t('views.admin.library.AlbumDetail.button.edit') }}
                  </router-link>
                </div>
                <div class="ui buttons">
                  <dangerous-button
                    :class="['ui', {loading: isLoading}, 'basic danger button']"
                    :action="remove"
                  >
                    {{ $t('views.admin.library.AlbumDetail.button.delete') }}
                    <template #modal-header>
                      <p>
                        {{ $t('views.admin.library.AlbumDetail.modal.delete.header') }}
                      </p>
                    </template>
                    <template #modal-content>
                      <div>
                        <p>
                          {{ $t('views.admin.library.AlbumDetail.modal.delete.content.warning') }}
                        </p>
                      </div>
                    </template>
                    <template #modal-confirm>
                      <p>
                        {{ $t('views.admin.library.AlbumDetail.button.delete') }}
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
                  {{ $t('views.admin.library.AlbumDetail.header.albumData') }}
                </div>
              </h3>
              <table class="ui very basic table">
                <tbody>
                  <tr>
                    <td>
                      {{ $t('views.admin.library.AlbumDetail.table.album.title') }}
                    </td>
                    <td>
                      {{ object.title }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.artists.detail', params: {id: object.artist.id }}">
                        {{ $t('views.admin.library.AlbumDetail.link.artist') }}
                      </router-link>
                    </td>
                    <td>
                      {{ object.artist.name }}
                    </td>
                  </tr>
                  <tr v-if="!object.is_local">
                    <td>
                      <router-link :to="{name: 'manage.moderation.domains.detail', params: {id: object.domain }}">
                        {{ $t('views.admin.library.AlbumDetail.link.domain') }}
                      </router-link>
                    </td>
                    <td>
                      {{ object.domain }}
                    </td>
                  </tr>
                  <tr v-if="object.description">
                    <td>
                      {{ $t('views.admin.library.AlbumDetail.table.album.description') }}
                    </td>
                    <sanitized-html
                      tag="td"
                      :html="object.description.html"
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
                  {{ $t('views.admin.library.AlbumDetail.header.activity') }}&nbsp;
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
                      {{ $t('views.admin.library.AlbumDetail.table.activity.firstSeen') }}
                    </td>
                    <td>
                      <human-date :date="object.creation_date" />
                    </td>
                  </tr>
                  <tr>
                    <td>
                      {{ $t('views.admin.library.AlbumDetail.table.activity.listenings') }}
                    </td>
                    <td>
                      {{ stats.listenings }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      {{ $t('views.admin.library.AlbumDetail.table.activity.favorited') }}
                    </td>
                    <td>
                      {{ stats.track_favorites }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      {{ $t('views.admin.library.AlbumDetail.table.activity.playlists') }}
                    </td>
                    <td>
                      {{ stats.playlists }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.moderation.reports.list', query: {q: getQuery('target', `album:${object.id}`) }}">
                        {{ $t('views.admin.library.AlbumDetail.link.reports') }}
                      </router-link>
                    </td>
                    <td>
                      {{ stats.reports }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.edits', query: {q: getQuery('target', 'album ' + object.id)}}">
                        {{ $t('views.admin.library.AlbumDetail.link.edits') }}
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
                  {{ $t('views.admin.library.AlbumDetail.header.audioContent') }}&nbsp;
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
                      {{ $t('views.admin.library.AlbumDetail.table.audioContent.cachedSize') }}
                    </td>
                    <td>
                      {{ humanSize(stats.media_downloaded_size) }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      {{ $t('views.admin.library.AlbumDetail.table.audioContent.totalSize') }}
                    </td>
                    <td>
                      {{ humanSize(stats.media_total_size) }}
                    </td>
                  </tr>

                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.libraries', query: {q: getQuery('album_id', object.id) }}">
                        {{ $t('views.admin.library.AlbumDetail.link.libraries') }}
                      </router-link>
                    </td>
                    <td>
                      {{ stats.libraries }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.uploads', query: {q: getQuery('album_id', object.id) }}">
                        {{ $t('views.admin.library.AlbumDetail.link.uploads') }}
                      </router-link>
                    </td>
                    <td>
                      {{ stats.uploads }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.tracks', query: {q: getQuery('album_id', object.id) }}">
                        {{ $t('views.admin.library.AlbumDetail.link.tracks') }}
                      </router-link>
                    </td>
                    <td>
                      {{ object.tracks_count }}
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
