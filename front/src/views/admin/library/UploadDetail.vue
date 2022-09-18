<script setup lang="ts">
import type { PrivacyLevel, ImportStatus } from '~/types'

import { humanSize, truncate } from '~/utils/filters'
import { useRouter } from 'vue-router'
import { computed, ref } from 'vue'

import time from '~/utils/time'
import axios from 'axios'

import ImportStatusModal from '~/components/library/ImportStatusModal.vue'

import useSharedLabels from '~/composables/locale/useSharedLabels'
import useErrorHandler from '~/composables/useErrorHandler'

interface Props {
  id: number
}

const props = defineProps<Props>()

const sharedLabels = useSharedLabels()
const router = useRouter()

const privacyLevels = computed(() => sharedLabels.fields.privacy_level.shortChoices[object.value.library.privacy_level as PrivacyLevel])
const importStatus = computed(() => sharedLabels.fields.import_status.choices[object.value.import_status as ImportStatus].label)

const isLoading = ref(false)
const object = ref()
const fetchData = async () => {
  isLoading.value = true

  try {
    const response = await axios.get(`manage/library/uploads/${props.id}/`)
    object.value = response.data
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoading.value = false
}

fetchData()

const remove = async () => {
  isLoading.value = true

  try {
    await axios.delete(`manage/uploads/${props.id}/`)
    router.push({ name: 'manage.library.uploads' })
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoading.value = false
}

const getQuery = (field: string, value: string) => `${field}:"${value}"`
const displayName = (object: any) => object.filename ?? object.source ?? object.uuid

const showUploadDetailModal = ref(false)
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
      <import-status-modal
        v-model:show="showUploadDetailModal"
        :upload="object"
      />
      <section
        v-title="displayName(object)"
        :class="['ui', 'head', 'vertical', 'stripe', 'segment']"
      >
        <div class="ui stackable one column grid">
          <div class="ui column">
            <div class="segment-content">
              <h2 class="ui header">
                <i class="circular inverted file icon" />
                <div class="content">
                  {{ truncate(displayName(object)) }}
                  <div class="sub header">
                    <template v-if="object.is_local">
                      <span class="ui tiny accent label">
                        <i class="home icon" />
                        {{ $t('views.admin.library.UploadDetail.localLabel') }}
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
                    :href="$store.getters['instance/absoluteUrl'](`/api/admin/music/upload/${object.id}`)"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    <i class="wrench icon" />
                    {{ $t('views.admin.library.UploadDetail.djangoLink') }}
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
                        :href="$store.getters['instance/absoluteUrl'](`/api/admin/music/upload/${object.id}`)"
                        target="_blank"
                        rel="noopener noreferrer"
                      >
                        <i class="wrench icon" />
                        {{ $t('views.admin.library.UploadDetail.djangoLink') }}
                      </a>
                      <a
                        class="basic item"
                        :href="object.url || object.fid"
                        target="_blank"
                        rel="noopener noreferrer"
                      >
                        <i class="external icon" />
                        {{ $t('views.admin.library.UploadDetail.remoteProfileLink') }}
                      </a>
                    </div>
                  </button>
                </div>
                <div class="ui buttons">
                  <a
                    v-if="object.audio_file"
                    class="ui labeled icon button"
                    :href="$store.getters['instance/absoluteUrl'](object.audio_file)"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    <i class="download icon" />
                    {{ $t('views.admin.library.UploadDetail.downloadButton') }}
                  </a>
                </div>
                <div class="ui buttons">
                  <dangerous-button
                    :class="['ui', {loading: isLoading}, 'basic danger button']"
                    :action="remove"
                  >
                    {{ $t('views.admin.library.UploadDetail.deleteButton') }}
                    <template #modal-header>
                      <p>
                        {{ $t('views.admin.library.UploadDetail.deleteModalHeader') }}
                      </p>
                    </template>
                    <template #modal-content>
                      <div>
                        <p>
                          {{ $t('views.admin.library.UploadDetail.deleteModalMessage') }}
                        </p>
                      </div>
                    </template>
                    <template #modal-confirm>
                      <p>
                        {{ $t('views.admin.library.UploadDetail.deleteButton') }}
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
                  {{ $t('views.admin.library.UploadDetail.uploadDataHeader') }}
                </div>
              </h3>
              <table class="ui very basic table">
                <tbody>
                  <tr>
                    <td>
                      {{ $t('views.admin.library.UploadDetail.nameLabel') }}
                    </td>
                    <td>
                      {{ displayName(object) }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.uploads', query: {q: getQuery('privacy_level', object.library.privacy_level) }}">
                        {{ $t('views.admin.library.UploadDetail.visibilityLabel') }}
                      </router-link>
                    </td>
                    <td>
                      {{ privacyLevels }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.moderation.accounts.detail', params: {id: object.library.actor.full_username }}">
                        {{ $t('views.admin.library.UploadDetail.accountLabel') }}
                      </router-link>
                    </td>
                    <td>
                      {{ object.library.actor.preferred_username }}
                    </td>
                  </tr>
                  <tr v-if="!object.is_local">
                    <td>
                      <router-link :to="{name: 'manage.moderation.domains.detail', params: {id: object.domain }}">
                        {{ $t('views.admin.library.UploadDetail.domainLabel') }}
                      </router-link>
                    </td>
                    <td>
                      {{ object.domain }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.uploads', query: {q: getQuery('status', object.import_status) }}">
                        {{ $t('views.admin.library.UploadDetail.importStatusLabel') }}
                      </router-link>
                    </td>
                    <td>
                      {{ importStatus }}
                      <button
                        class="ui tiny basic icon button"
                        :title="sharedLabels.fields.import_status.label"
                        @click="showUploadDetailModal = true"
                      >
                        <i class="question circle outline icon" />
                      </button>
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.libraries.detail', params: {id: object.library.uuid }}">
                        {{ $t('views.admin.library.UploadDetail.libraryLabel') }}
                      </router-link>
                    </td>
                    <td>
                      {{ object.library.name }}
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
                  {{ $t('views.admin.library.UploadDetail.activityHeader') }}&nbsp;
                </div>
              </h3>
              <table class="ui very basic table">
                <tbody>
                  <tr>
                    <td>
                      {{ $t('views.admin.library.UploadDetail.firstSeenLabel') }}
                    </td>
                    <td>
                      <human-date :date="object.creation_date" />
                    </td>
                  </tr>
                  <tr>
                    <td>
                      {{ $t('views.admin.library.UploadDetail.accessedDateLabel') }}
                    </td>
                    <td>
                      <human-date
                        v-if="object.accessed_date"
                        :date="object.accessed_date"
                      />
                      <span
                        v-else
                      >
                        {{ $t('views.admin.library.UploadDetail.notApplicable') }}
                      </span>
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
                  {{ $t('views.admin.library.UploadDetail.audioContentHeader') }}&nbsp;
                </div>
              </h3>
              <table class="ui very basic table">
                <tbody>
                  <tr v-if="object.track">
                    <td>
                      <router-link :to="{name: 'manage.library.tracks.detail', params: {id: object.track.id }}">
                        {{ $t('views.admin.library.UploadDetail.trackLabel') }}
                      </router-link>
                    </td>
                    <td>
                      {{ object.track.title }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      {{ $t('views.admin.library.UploadDetail.cachedSizeLabel') }}
                    </td>
                    <td>
                      <template v-if="object.audio_file">
                        {{ humanSize(object.size) }}
                      </template>
                      <span
                        v-else
                      >
                        {{ $t('views.admin.library.UploadDetail.notApplicable') }}
                      </span>
                    </td>
                  </tr>
                  <tr>
                    <td>
                      {{ $t('views.admin.library.UploadDetail.sizeLabel') }}
                    </td>
                    <td>
                      {{ humanSize(object.size) }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      {{ $t('views.admin.library.UploadDetail.bitrateLabel') }}
                    </td>
                    <td>
                      <template v-if="object.bitrate">
                        {{ $t('views.admin.library.UploadDetail.bitrateValue', {bitrate: humanSize(object.bitrate)}) }}
                      </template>
                      <span
                        v-else
                      >
                        {{ $t('views.admin.library.UploadDetail.notApplicable') }}
                      </span>
                    </td>
                  </tr>
                  <tr>
                    <td>
                      {{ $t('views.admin.library.UploadDetail.durationLabel') }}
                    </td>
                    <td>
                      <template v-if="object.duration">
                        {{ time.parse(object.duration) }}
                      </template>
                      <span
                        v-else
                      >
                        {{ $t('views.admin.library.UploadDetail.notApplicable') }}
                      </span>
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.uploads', query: {q: getQuery('type', object.mimetype) }}">
                        {{ $t('views.admin.library.UploadDetail.typeLabel') }}
                      </router-link>
                    </td>
                    <td>
                      <template v-if="object.mimetype">
                        {{ object.mimetype }}
                      </template>
                      <span
                        v-else
                      >
                        {{ $t('views.admin.library.UploadDetail.notApplicable') }}
                      </span>
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
