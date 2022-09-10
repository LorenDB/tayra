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
  statsWarning: t('Statistics are computed from known activity and content on your instance, and do not reflect general activity for this object')
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
                        Local
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
                    Open local profile&nbsp;
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
                        View in Django's admin&nbsp;
                      </a>
                      <a
                        v-if="object.mbid"
                        class="basic item"
                        :href="`https://musicbrainz.org/release/${object.mbid}`"
                        target="_blank"
                        rel="noopener noreferrer"
                      >
                        <i class="external icon" />
                        Open on MusicBrainz&nbsp;
                      </a>
                      <fetch-button
                        v-if="!object.is_local"
                        class="basic item"
                        :url="`albums/${object.id}/fetches/`"
                        @refresh="fetchData"
                      >
                        <i class="refresh icon" />&nbsp;
                        Refresh from remote server&nbsp;
                      </fetch-button>
                      <a
                        class="basic item"
                        :href="object.url || object.fid"
                        target="_blank"
                        rel="noopener noreferrer"
                      >
                        <i class="external icon" />
                        Open remote profile&nbsp;
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
                    Edit
                  </router-link>
                </div>
                <div class="ui buttons">
                  <dangerous-button
                    :class="['ui', {loading: isLoading}, 'basic danger button']"
                    :action="remove"
                  >
                    Delete
                    <template #modal-header>
                      <p>
                        Delete this album?
                      </p>
                    </template>
                    <template #modal-content>
                      <div>
                        <p>
                          The album will be removed, as well as associated uploads, tracks, favorites and listening history. This action is irreversible.
                        </p>
                      </div>
                    </template>
                    <template #modal-confirm>
                      <p>
                        Delete
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
                  Album data
                </div>
              </h3>
              <table class="ui very basic table">
                <tbody>
                  <tr>
                    <td>
                      Title
                    </td>
                    <td>
                      {{ object.title }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.artists.detail', params: {id: object.artist.id }}">
                        Artist
                      </router-link>
                    </td>
                    <td>
                      {{ object.artist.name }}
                    </td>
                  </tr>
                  <tr v-if="!object.is_local">
                    <td>
                      <router-link :to="{name: 'manage.moderation.domains.detail', params: {id: object.domain }}">
                        Domain
                      </router-link>
                    </td>
                    <td>
                      {{ object.domain }}
                    </td>
                  </tr>
                  <tr v-if="object.description">
                    <td>
                      Description
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
                  Activity&nbsp;
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
                      First seen
                    </td>
                    <td>
                      <human-date :date="object.creation_date" />
                    </td>
                  </tr>
                  <tr>
                    <td>
                      Listenings
                    </td>
                    <td>
                      {{ stats.listenings }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      Favorited tracks
                    </td>
                    <td>
                      {{ stats.track_favorites }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      Playlists
                    </td>
                    <td>
                      {{ stats.playlists }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.moderation.reports.list', query: {q: getQuery('target', `album:${object.id}`) }}">
                        Linked reports
                      </router-link>
                    </td>
                    <td>
                      {{ stats.reports }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.edits', query: {q: getQuery('target', 'album ' + object.id)}}">
                        Edits
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
                  Audio content&nbsp;
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
                      Cached size
                    </td>
                    <td>
                      {{ humanSize(stats.media_downloaded_size) }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      Total size
                    </td>
                    <td>
                      {{ humanSize(stats.media_total_size) }}
                    </td>
                  </tr>

                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.libraries', query: {q: getQuery('album_id', object.id) }}">
                        Libraries
                      </router-link>
                    </td>
                    <td>
                      {{ stats.libraries }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.uploads', query: {q: getQuery('album_id', object.id) }}">
                        Uploads
                      </router-link>
                    </td>
                    <td>
                      {{ stats.uploads }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.tracks', query: {q: getQuery('album_id', object.id) }}">
                        Tracks
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
