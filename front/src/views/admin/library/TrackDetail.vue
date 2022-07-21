<script setup lang="ts">
import { humanSize, truncate } from '~/utils/filters'
import { ref, computed } from 'vue'
import { useGettext } from 'vue3-gettext'
import { useRouter } from 'vue-router'

import axios from 'axios'
import FetchButton from '~/components/federation/FetchButton.vue'
import TagsList from '~/components/tags/List.vue'

interface Props {
  id: number
}

const props = defineProps<Props>()

const { $pgettext } = useGettext()
const labels = computed(() => ({
  statsWarning: $pgettext('Content/Moderation/Help text', 'Statistics are computed from known activity and content on your instance, and do not reflect general activity for this object')
}))

const track = ref()
const isLoading = ref(false)
const fetchData = async () => {
  isLoading.value = true

  try {
    const response = await axios.get(`manage/library/tracks/${props.id}/`)
    track.value = response.data
  } catch (error) {
    // TODO (wvffle): Handle error
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
    // TODO (wvffle): Handle error
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
    // TODO (wvffle): Handle error
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
                        <translate translate-context="Content/Moderation/*/Short, Noun">Local</translate>
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
                    <translate translate-context="Content/Moderation/Link/Verb">
                      Open local profile
                    </translate>&nbsp;
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
                        <translate translate-context="Content/Moderation/Link/Verb">View in Django's admin</translate>&nbsp;
                      </a>
                      <a
                        v-if="track.mbid"
                        class="basic item"
                        :href="`https://musicbrainz.org/recording/${track.mbid}`"
                        target="_blank"
                        rel="noopener noreferrer"
                      >
                        <i class="external icon" />
                        <translate translate-context="Content/Moderation/Link/Verb">Open on MusicBrainz</translate>&nbsp;
                      </a>
                      <fetch-button
                        v-if="!track.is_local"
                        class="basic item"
                        :url="`tracks/${track.id}/fetches/`"
                        @refresh="fetchData"
                      >
                        <i class="refresh icon" />&nbsp;
                        <translate translate-context="Content/Moderation/Button/Verb">
                          Refresh from remote server
                        </translate>&nbsp;
                      </fetch-button>
                      <a
                        class="basic item"
                        :href="track.url || track.fid"
                        target="_blank"
                        rel="noopener noreferrer"
                      >
                        <i class="external icon" />
                        <translate translate-context="Content/Moderation/Link/Verb">Open remote profile</translate>&nbsp;
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
                    <translate translate-context="Content/*/Button.Label/Verb">
                      Edit
                    </translate>
                  </router-link>
                </div>
                <div class="ui buttons">
                  <dangerous-button
                    :class="['ui', {loading: isLoading}, 'basic danger button']"
                    :action="remove"
                  >
                    <translate translate-context="*/*/*/Verb">
                      Delete
                    </translate>
                    <template #modal-header>
                      <p>
                        <translate translate-context="Popup/Library/Title">
                          Delete this track?
                        </translate>
                      </p>
                    </template>
                    <template #modal-content>
                      <div>
                        <p>
                          <translate translate-context="Content/Moderation/Paragraph">
                            The track will be removed, as well as associated uploads, favorites and listening history. This action is irreversible.
                          </translate>
                        </p>
                      </div>
                    </template>
                    <template #modal-confirm>
                      <p>
                        <translate translate-context="*/*/*/Verb">
                          Delete
                        </translate>
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
                  <translate translate-context="Content/Moderation/Title">
                    Track data
                  </translate>
                </div>
              </h3>
              <table class="ui very basic table">
                <tbody>
                  <tr>
                    <td>
                      <translate translate-context="*/*/*/Noun">
                        Title
                      </translate>
                    </td>
                    <td>
                      {{ track.title }}
                    </td>
                  </tr>
                  <tr v-if="track.album">
                    <td>
                      <router-link :to="{name: 'manage.library.albums.detail', params: {id: track.album.id }}">
                        <translate translate-context="*/*/*">
                          Album
                        </translate>
                      </router-link>
                    </td>
                    <td>
                      {{ track.album.title }}
                    </td>
                  </tr>

                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.artists.detail', params: {id: track.artist.id }}">
                        <translate translate-context="*/*/*/Noun">
                          Artist
                        </translate>
                      </router-link>
                    </td>
                    <td>
                      {{ track.artist.name }}
                    </td>
                  </tr>
                  <tr v-if="track.album">
                    <td>
                      <router-link :to="{name: 'manage.library.artists.detail', params: {id: track.album.artist.id }}">
                        <translate translate-context="*/*/*/Noun">
                          Album artist
                        </translate>
                      </router-link>
                    </td>
                    <td>
                      {{ track.album.artist.name }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <translate translate-context="*/*/*/Short, Noun">
                        Position
                      </translate>
                    </td>
                    <td>
                      {{ track.position }}
                    </td>
                  </tr>
                  <tr v-if="track.disc_number">
                    <td>
                      <translate translate-context="*/*/*/Noun">
                        Disc number
                      </translate>
                    </td>
                    <td>
                      {{ track.disc_number }}
                    </td>
                  </tr>
                  <tr v-if="track.copyright">
                    <td>
                      <translate translate-context="Content/Track/*/Noun">
                        Copyright
                      </translate>
                    </td>
                    <td>{{ track.copyright }}</td>
                  </tr>
                  <tr v-if="track.license">
                    <td>
                      <translate translate-context="Content/*/*/Noun">
                        License
                      </translate>
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
                        <translate translate-context="Content/Moderation/*/Noun">
                          Domain
                        </translate>
                      </router-link>
                    </td>
                    <td>
                      {{ track.domain }}
                    </td>
                  </tr>
                  <tr v-if="track.description">
                    <td>
                      <translate translate-context="'*/*/*/Noun">
                        Description
                      </translate>
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
                  <translate translate-context="Content/Moderation/Title">
                    Activity
                  </translate>&nbsp;
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
                      <translate translate-context="Content/Moderation/Table.Label/Short (Value is a date)">
                        First seen
                      </translate>
                    </td>
                    <td>
                      <human-date :date="track.creation_date" />
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <translate translate-context="*/*/*/Noun">
                        Listenings
                      </translate>
                    </td>
                    <td>
                      {{ stats.listenings }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <translate translate-context="*/*/*">
                        Favorited tracks
                      </translate>
                    </td>
                    <td>
                      {{ stats.track_favorites }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <translate translate-context="*/*/*">
                        Playlists
                      </translate>
                    </td>
                    <td>
                      {{ stats.playlists }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.moderation.reports.list', query: {q: getQuery('target', `track:${track.id}`) }}">
                        <translate translate-context="Content/Moderation/Table.Label/Noun">
                          Linked reports
                        </translate>
                      </router-link>
                    </td>
                    <td>
                      {{ stats.reports }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.edits', query: {q: getQuery('target', 'track ' + track.id)}}">
                        <translate translate-context="*/Admin/*/Noun">
                          Edits
                        </translate>
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
                  <translate translate-context="Content/Moderation/Title">
                    Audio content
                  </translate>&nbsp;
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
                      <translate translate-context="Content/Moderation/Table.Label/Noun">
                        Cached size
                      </translate>
                    </td>
                    <td>
                      {{ humanSize(stats.media_downloaded_size) }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <translate translate-context="Content/Moderation/Table.Label">
                        Total size
                      </translate>
                    </td>
                    <td>
                      {{ humanSize(stats.media_total_size) }}
                    </td>
                  </tr>

                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.libraries', query: {q: getQuery('track_id', track.id) }}">
                        <translate translate-context="*/*/*/Noun">
                          Libraries
                        </translate>
                      </router-link>
                    </td>
                    <td>
                      {{ stats.libraries }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.uploads', query: {q: getQuery('track_id', track.id) }}">
                        <translate translate-context="*/*/*">
                          Uploads
                        </translate>
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
