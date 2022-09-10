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
                        Local
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
                    View in Django's admin&nbsp;
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
                        View in Django's admin&nbsp;
                      </a>
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
                  <a
                    v-if="object.audio_file"
                    class="ui labeled icon button"
                    :href="$store.getters['instance/absoluteUrl'](object.audio_file)"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    <i class="download icon" />
                    Download
                  </a>
                </div>
                <div class="ui buttons">
                  <dangerous-button
                    :class="['ui', {loading: isLoading}, 'basic danger button']"
                    :action="remove"
                  >
                    Delete
                    <template #modal-header>
                      <p>
                        Delete this upload?
                      </p>
                    </template>
                    <template #modal-content>
                      <div>
                        <p>
                          The upload will be removed. This action is irreversible.
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
                  Upload data
                </div>
              </h3>
              <table class="ui very basic table">
                <tbody>
                  <tr>
                    <td>
                      Name
                    </td>
                    <td>
                      {{ displayName(object) }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.uploads', query: {q: getQuery('privacy_level', object.library.privacy_level) }}">
                        Visibility
                      </router-link>
                    </td>
                    <td>
                      {{ privacyLevels }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.moderation.accounts.detail', params: {id: object.library.actor.full_username }}">
                        Account
                      </router-link>
                    </td>
                    <td>
                      {{ object.library.actor.preferred_username }}
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
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.uploads', query: {q: getQuery('status', object.import_status) }}">
                        Import status
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
                        Library
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
                  Activity&nbsp;
                </div>
              </h3>
              <table class="ui very basic table">
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
                      Accessed date
                    </td>
                    <td>
                      <human-date
                        v-if="object.accessed_date"
                        :date="object.accessed_date"
                      />
                      <translate
                        v-else
                      >
                        N/A
                      </translate>
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
                </div>
              </h3>
              <table class="ui very basic table">
                <tbody>
                  <tr v-if="object.track">
                    <td>
                      <router-link :to="{name: 'manage.library.tracks.detail', params: {id: object.track.id }}">
                        Track
                      </router-link>
                    </td>
                    <td>
                      {{ object.track.title }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      Cached size
                    </td>
                    <td>
                      <template v-if="object.audio_file">
                        {{ humanSize(object.size) }}
                      </template>
                      <translate
                        v-else
                      >
                        N/A
                      </translate>
                    </td>
                  </tr>
                  <tr>
                    <td>
                      Size
                    </td>
                    <td>
                      {{ humanSize(object.size) }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      Bitrate
                    </td>
                    <td>
                      <template v-if="object.bitrate">
                        {{ humanSize(object.bitrate) }}/s
                      </template>
                      <translate
                        v-else
                      >
                        N/A
                      </translate>
                    </td>
                  </tr>
                  <tr>
                    <td>
                      Duration
                    </td>
                    <td>
                      <template v-if="object.duration">
                        {{ time.parse(object.duration) }}
                      </template>
                      <translate
                        v-else
                      >
                        N/A
                      </translate>
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.uploads', query: {q: getQuery('type', object.mimetype) }}">
                        Type
                      </router-link>
                    </td>
                    <td>
                      <template v-if="object.mimetype">
                        {{ object.mimetype }}
                      </template>
                      <translate
                        v-else
                      >
                        N/A
                      </translate>
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
