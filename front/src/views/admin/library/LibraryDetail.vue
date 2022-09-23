<script setup lang="ts">
import type { PrivacyLevel } from '~/types'

import { humanSize, truncate } from '~/utils/filters'
import { useI18n } from 'vue-i18n'
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

const { t } = useI18n()

const sharedLabels = useSharedLabels()
const router = useRouter()
const logger = useLogger()

const labels = computed(() => ({
  statsWarning: t('views.admin.library.LibraryDetail.warning.stats')
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

  isLoading.value = false
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

  isLoadingStats.value = false
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

  isLoading.value = false
}

const getQuery = (field: string, value: string) => `${field}:"${value}"`

const updateObj = async (attr: string) => {
  const params = {
    [attr]: object.value[attr]
  }

  try {
    await axios.patch(`manage/library/libraries/${props.id}/`, params)
    logger.info(`${attr} was updated successfully to ${params[attr]}`)
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
                        {{ $t('views.admin.library.LibraryDetail.header.local') }}
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
                    {{ $t('views.admin.library.LibraryDetail.link.django') }}
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
                        {{ $t('views.admin.library.LibraryDetail.link.django') }}
                      </a>
                      <a
                        class="basic item"
                        :href="object.url || object.fid"
                        target="_blank"
                        rel="noopener noreferrer"
                      >
                        <i class="external icon" />
                        {{ $t('views.admin.library.LibraryDetail.link.remoteProfile') }}
                      </a>
                    </div>
                  </button>
                </div>
                <div class="ui buttons">
                  <dangerous-button
                    :class="['ui', {loading: isLoading}, 'basic danger button']"
                    :action="remove"
                  >
                    {{ $t('views.admin.library.LibraryDetail.button.delete') }}
                    <template #modal-header>
                      <p>
                        {{ $t('views.admin.library.LibraryDetail.modal.delete.header') }}
                      </p>
                    </template>
                    <template #modal-content>
                      <div>
                        <p>
                          {{ $t('views.admin.library.LibraryDetail.modal.delete.content.warning') }}
                        </p>
                      </div>
                    </template>
                    <template #modal-confirm>
                      <p>
                        {{ $t('views.admin.library.LibraryDetail.button.delete') }}
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
                  {{ $t('views.admin.library.LibraryDetail.header.libraryData') }}
                </div>
              </h3>
              <table class="ui very basic table">
                <tbody>
                  <tr>
                    <td>
                      {{ $t('views.admin.library.LibraryDetail.table.library.name') }}
                    </td>
                    <td>
                      {{ object.name }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.libraries', query: {q: getQuery('privacy_level', object.privacy_level) }}">
                        {{ $t('views.admin.library.LibraryDetail.link.visibility') }}
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
                        {{ $t('views.admin.library.LibraryDetail.link.account') }}
                      </router-link>
                    </td>
                    <td>
                      {{ object.actor.preferred_username }}
                    </td>
                  </tr>
                  <tr v-if="!object.is_local">
                    <td>
                      <router-link :to="{name: 'manage.moderation.domains.detail', params: {id: object.domain }}">
                        {{ $t('views.admin.library.LibraryDetail.link.domain') }}
                      </router-link>
                    </td>
                    <td>
                      {{ object.domain }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      {{ $t('views.admin.library.LibraryDetail.table.library.description') }}
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
                  {{ $t('views.admin.library.LibraryDetail.header.activity') }}&nbsp;
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
                      {{ $t('views.admin.library.LibraryDetail.table.activity.firstSeen') }}
                    </td>
                    <td>
                      <human-date :date="object.creation_date" />
                    </td>
                  </tr>
                  <tr>
                    <td>
                      {{ $t('views.admin.library.LibraryDetail.table.activity.followers') }}
                    </td>
                    <td>
                      {{ stats.followers }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.moderation.reports.list', query: {q: getQuery('target', `library:${object.uuid}`) }}">
                        {{ $t('views.admin.library.LibraryDetail.link.reports') }}
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
                  {{ $t('views.admin.library.LibraryDetail.header.audioContent') }}&nbsp;
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
                      {{ $t('views.admin.library.LibraryDetail.table.audioContent.cachedSize') }}
                    </td>
                    <td>
                      {{ humanSize(stats.media_downloaded_size) }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      {{ $t('views.admin.library.LibraryDetail.table.audioContent.totalSize') }}
                    </td>
                    <td>
                      {{ humanSize(stats.media_total_size) }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.artists', query: {q: getQuery('library_id', object.id) }}">
                        {{ $t('views.admin.library.LibraryDetail.link.artists') }}
                      </router-link>
                    </td>
                    <td>
                      {{ stats.artists }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.albums', query: {q: getQuery('library_id', object.id) }}">
                        {{ $t('views.admin.library.LibraryDetail.link.albums') }}
                      </router-link>
                    </td>
                    <td>
                      {{ stats.albums }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.tracks', query: {q: getQuery('library_id', object.id) }}">
                        {{ $t('views.admin.library.LibraryDetail.link.tracks') }}
                      </router-link>
                    </td>
                    <td>
                      {{ stats.tracks }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.uploads', query: {q: getQuery('library_id', object.id) }}">
                        {{ $t('views.admin.library.LibraryDetail.link.uploads') }}
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
