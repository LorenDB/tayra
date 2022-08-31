<script setup lang="ts">
import type { PrivacyLevel } from '~/types'

import { humanSize, truncate } from '~/utils/filters'
import { useGettext } from 'vue3-gettext'
import { useRouter } from 'vue-router'
import { computed, ref } from 'vue'

import axios from 'axios'

import useSharedLabels from '~/composables/locale/useSharedLabels'
import useErrorHandler from '~/composables/useErrorHandler'
import useLogger from '~/composables/useLogger'

const PRIVACY_LEVELS = ['me', 'instance', 'everyone'] as PrivacyLevel[]

interface Props {
  id: number
}

const props = defineProps<Props>()

const { $pgettext } = useGettext()

const sharedLabels = useSharedLabels()
const router = useRouter()
const logger = useLogger()

const labels = computed(() => ({
  statsWarning: $pgettext('Content/Moderation/Help text', 'Statistics are computed from known activity and content on your instance, and do not reflect general activity for this object')
}))

const isLoading = ref(false)
const object = ref()
const fetchData = async () => {
  isLoading.value = true

  try {
    const response = await axios.get(`manage/library/libraries/${props.id}/`)
    object.value = response.data
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoading.value = true
}

const isLoadingStats = ref(false)
const stats = ref()
const fetchStats = async () => {
  isLoadingStats.value = true

  try {
    const response = await axios.get(`manage/library/libraries/${props.id}/stats/`)
    stats.value = response.data
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoadingStats.value = true
}

fetchStats()
fetchData()

const remove = async () => {
  isLoading.value = true

  try {
    await axios.delete(`manage/library/libraries/${props.id}/`)
    router.push({ name: 'manage.library.libraries' })
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoading.value = true
}

const getQuery = (field: string, value: string) => `${field}:"${value}"`

const updateObj = async (attr: string) => {
  const params = {
    [attr]: object.value[attr]
  }

  try {
    await axios.patch(`manage/library/libraries/${props.id}/`, params)
    logger.info(`${attr} was updated succcessfully to ${params[attr]}`)
  } catch (error) {
    logger.error(`Error while setting ${attr} to ${params[attr]}`, error)
    // TODO (wvffle): Use error handler with custom msg
  }
}
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
        v-title="object.name"
        :class="['ui', 'head', 'vertical', 'stripe', 'segment']"
      >
        <div class="ui stackable one column grid">
          <div class="ui column">
            <div class="segment-content">
              <h2 class="ui header">
                <i class="circular inverted book icon" />
                <div class="content">
                  {{ truncate(object.name) }}
                  <div class="sub header">
                    <template v-if="object.is_local">
                      <span class="ui tiny accent label">
                        <i class="home icon" />
                        <translate translate-context="Content/Moderation/*/Short, Noun">Local</translate>
                      </span>
                      &nbsp;
                    </template>
                  </div>
                </div>
              </h2>
              <div class="header-buttons">
                <div class="ui icon buttons">
                  <a
                    v-if="$store.state.auth.profile && $store.state.auth.profile.is_superuser"
                    class="ui labeled icon button"
                    :href="$store.getters['instance/absoluteUrl'](`/api/admin/music/library/${object.id}`)"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    <i class="wrench icon" />
                    <translate translate-context="Content/Moderation/Link/Verb">View in Django's admin</translate>&nbsp;
                  </a>
                  <button
                    v-dropdown
                    class="ui floating dropdown icon button"
                  >
                    <i class="dropdown icon" />
                    <div class="menu">
                      <a
                        v-if="$store.state.auth.profile && $store.state.auth.profile.is_superuser"
                        class="basic item"
                        :href="$store.getters['instance/absoluteUrl'](`/api/admin/music/library/${object.id}`)"
                        target="_blank"
                        rel="noopener noreferrer"
                      >
                        <i class="wrench icon" />
                        <translate translate-context="Content/Moderation/Link/Verb">View in Django's admin</translate>&nbsp;
                      </a>
                      <a
                        class="basic item"
                        :href="object.url || object.fid"
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
                          Delete this library?
                        </translate>
                      </p>
                    </template>
                    <template #modal-content>
                      <div>
                        <p>
                          <translate translate-context="Content/Moderation/Paragraph">
                            The library will be removed, as well as associated uploads, and follows. This action is irreversible.
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
                    Library data
                  </translate>
                </div>
              </h3>
              <table class="ui very basic table">
                <tbody>
                  <tr>
                    <td>
                      <translate translate-context="*/*/*/Noun">
                        Name
                      </translate>
                    </td>
                    <td>
                      {{ object.name }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.libraries', query: {q: getQuery('privacy_level', object.privacy_level) }}">
                        <translate translate-context="*/*/*">
                          Visibility
                        </translate>
                      </router-link>
                    </td>
                    <td>
                      <select
                        v-if="object.is_local"
                        v-model="object.privacy_level"
                        class="ui search selection dropdown"

                        @change="updateObj('privacy_level')"
                      >
                        <option
                          v-for="p in PRIVACY_LEVELS"
                          :key="p"
                          :value="p"
                        >
                          {{ sharedLabels.fields.privacy_level.shortChoices[p] }}
                        </option>
                      </select>
                      <template v-else>
                        {{ sharedLabels.fields.privacy_level.shortChoices[object.privacy_level as PrivacyLevel] }}
                      </template>
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.moderation.accounts.detail', params: {id: object.actor.full_username }}">
                        <translate translate-context="*/*/*/Noun">
                          Account
                        </translate>
                      </router-link>
                    </td>
                    <td>
                      {{ object.actor.preferred_username }}
                    </td>
                  </tr>
                  <tr v-if="!object.is_local">
                    <td>
                      <router-link :to="{name: 'manage.moderation.domains.detail', params: {id: object.domain }}">
                        <translate translate-context="Content/Moderation/*/Noun">
                          Domain
                        </translate>
                      </router-link>
                    </td>
                    <td>
                      {{ object.domain }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <translate translate-context="*/*/*/Noun">
                        Description
                      </translate>
                    </td>
                    <td>
                      {{ object.description }}
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
                      <human-date :date="object.creation_date" />
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <translate translate-context="Content/Federation/*/Noun">
                        Followers
                      </translate>
                    </td>
                    <td>
                      {{ stats.followers }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.moderation.reports.list', query: {q: getQuery('target', `library:${object.uuid}`) }}">
                        <translate translate-context="Content/Moderation/Table.Label/Noun">
                          Linked reports
                        </translate>
                      </router-link>
                    </td>
                    <td>
                      {{ stats.reports }}
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
                      <router-link :to="{name: 'manage.library.artists', query: {q: getQuery('library_id', object.id) }}">
                        <translate translate-context="*/*/*/Noun">
                          Artists
                        </translate>
                      </router-link>
                    </td>
                    <td>
                      {{ stats.artists }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.albums', query: {q: getQuery('library_id', object.id) }}">
                        <translate translate-context="*/*/*">
                          Albums
                        </translate>
                      </router-link>
                    </td>
                    <td>
                      {{ stats.albums }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.tracks', query: {q: getQuery('library_id', object.id) }}">
                        <translate translate-context="*/*/*">
                          Tracks
                        </translate>
                      </router-link>
                    </td>
                    <td>
                      {{ stats.tracks }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.uploads', query: {q: getQuery('library_id', object.id) }}">
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
