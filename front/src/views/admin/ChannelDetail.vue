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
    const response = await axios.get(`manage/channels/${props.id}/`)
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
    const response = await axios.get(`manage/channels/${props.id}/stats/`)
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
    await axios.delete(`manage/channels/${props.id}/`)
    router.push({ name: 'manage.channels' })
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
        v-title="object.artist.name"
        :class="['ui', 'head', 'vertical', 'stripe', 'segment']"
      >
        <div class="ui stackable one column grid">
          <div class="ui column">
            <div class="segment-content">
              <h2 class="ui header">
                <img
                  v-if="object.artist.cover && object.artist.cover.urls.medium_square_crop"
                  v-lazy="$store.getters['instance/absoluteUrl'](object.artist.cover.urls.medium_square_crop)"
                  alt=""
                >
                <img
                  v-else
                  alt=""
                  src="../../assets/audio/default-cover.png"
                >
                <div class="content">
                  {{ truncate(object.artist.name) }}
                  <div class="sub header">
                    <template v-if="object.artist.is_local">
                      <span class="ui tiny accent label">
                        <i class="home icon" />
                        Local
                      </span>
                      &nbsp;
                    </template>
                  </div>
                </div>
              </h2>
              <template v-if="object.artist.tags && object.artist.tags.length > 0">
                <tags-list
                  :limit="5"
                  detail-route="manage.library.tags.detail"
                  :tags="object.artist.tags"
                />
                <div class="ui hidden divider" />
              </template>

              <div class="header-buttons">
                <div class="ui icon buttons">
                  <router-link
                    class="ui labeled icon button"
                    :to="{name: 'channels.detail', params: {id: object.uuid }}"
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
                        :href="$store.getters['instance/absoluteUrl'](`/api/admin/audio/channel/${object.id}`)"
                        target="_blank"
                        rel="noopener noreferrer"
                      >
                        <i class="wrench icon" />
                        View in Django's admin&nbsp;
                      </a>
                      <fetch-button
                        v-if="!object.actor.is_local"
                        class="basic item"
                        :url="`channels/${object.uuid}/fetches/`"
                        @refresh="fetchData"
                      >
                        <i class="refresh icon" />&nbsp;
                        Refresh from remote server&nbsp;
                      </fetch-button>
                      <a
                        class="basic item"
                        :href="object.actor.url || object.actor.fid"
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
                  <dangerous-button
                    :class="['ui', {loading: isLoading}, 'basic danger button']"
                    :action="remove"
                  >
                    Delete
                    <template #modal-header>
                      <p>
                        Delete this channel?
                      </p>
                    </template>
                    <template #modal-content>
                      <div>
                        <p>
                          The channel will be removed, as well as associated uploads, tracks, and albums. This action is irreversible.
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
                  Channel data
                </div>
              </h3>
              <table class="ui very basic table">
                <tbody>
                  <tr>
                    <td>
                      Name
                    </td>
                    <td>
                      {{ object.artist.name }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.channels', query: {q: getQuery('category', object.artist.content_category) }}">
                        Category
                      </router-link>
                    </td>
                    <td>
                      {{ object.artist.content_category }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.moderation.accounts.detail', params: {id: object.attributed_to.full_username }}">
                        Account
                      </router-link>
                    </td>
                    <td>
                      {{ object.attributed_to.preferred_username }}
                    </td>
                  </tr>
                  <tr v-if="!object.actor.is_local">
                    <td>
                      <router-link :to="{name: 'manage.moderation.domains.detail', params: {id: object.actor.domain }}">
                        Domain
                      </router-link>
                    </td>
                    <td>
                      {{ object.actor.domain }}
                    </td>
                  </tr>
                  <tr v-if="object.artist.description">
                    <td>
                      Description
                    </td>
                    <sanitized-html
                      tag="td"
                      :html="object.artist.description.html"
                    />
                  </tr>
                  <tr v-if="object.actor.url">
                    <td>
                      URL
                    </td>
                    <td>
                      <a
                        :href="object.actor.url"
                        rel="noreferrer noopener"
                        target="_blank"
                      >{{ object.actor.url }}</a>
                    </td>
                  </tr>
                  <tr v-if="object.rss_url">
                    <td>
                      RSS Feed
                    </td>
                    <td>
                      <a
                        :href="object.rss_url"
                        rel="noreferrer noopener"
                        target="_blank"
                      >{{ object.rss_url }}</a>
                    </td>
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
                      <router-link :to="{name: 'manage.moderation.reports.list', query: {q: getQuery('target', `channel:${object.uuid}`) }}">
                        Linked reports
                      </router-link>
                    </td>
                    <td>
                      {{ stats.reports }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.edits', query: {q: getQuery('target', 'artist ' + object.artist.id)}}">
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
                      <router-link :to="{name: 'manage.library.uploads', query: {q: getQuery('channel_id', object.uuid) }}">
                        Uploads
                      </router-link>
                    </td>
                    <td>
                      {{ stats.uploads }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.albums', query: {q: getQuery('channel_id', object.uuid) }}">
                        Albums
                      </router-link>
                    </td>
                    <td>
                      {{ object.artist.albums_count }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.tracks', query: {q: getQuery('channel_id', object.uuid) }}">
                        Tracks
                      </router-link>
                    </td>
                    <td>
                      {{ object.artist.tracks_count }}
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
