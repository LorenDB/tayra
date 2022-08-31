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

  isLoading.value = true
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

  isLoading.value = true
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
                    :href="$store.getters['instance/absoluteUrl'](`/api/admin/music/upload/${object.id}`)"
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
                        :href="$store.getters['instance/absoluteUrl'](`/api/admin/music/upload/${object.id}`)"
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
                  <a
                    v-if="object.audio_file"
                    class="ui labeled icon button"
                    :href="$store.getters['instance/absoluteUrl'](object.audio_file)"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    <i class="download icon" />
                    <translate translate-context="Content/Track/Link/Verb">Download</translate>
                  </a>
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
                          Delete this upload?
                        </translate>
                      </p>
                    </template>
                    <template #modal-content>
                      <div>
                        <p>
                          <translate translate-context="Content/Moderation/Paragraph">
                            The upload will be removed. This action is irreversible.
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
                    Upload data
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
                      {{ displayName(object) }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.uploads', query: {q: getQuery('privacy_level', object.library.privacy_level) }}">
                        <translate translate-context="*/*/*">
                          Visibility
                        </translate>
                      </router-link>
                    </td>
                    <td>
                      {{ privacyLevels }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.moderation.accounts.detail', params: {id: object.library.actor.full_username }}">
                        <translate translate-context="*/*/*/Noun">
                          Account
                        </translate>
                      </router-link>
                    </td>
                    <td>
                      {{ object.library.actor.preferred_username }}
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
                      <router-link :to="{name: 'manage.library.uploads', query: {q: getQuery('status', object.import_status) }}">
                        <translate translate-context="Content/*/*/Noun">
                          Import status
                        </translate>
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
                        <translate translate-context="*/*/*/Noun">
                          Library
                        </translate>
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
                  <translate translate-context="Content/Moderation/Title">
                    Activity
                  </translate>&nbsp;
                </div>
              </h3>
              <table class="ui very basic table">
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
                      <translate translate-context="Content/*/*/Noun">
                        Accessed date
                      </translate>
                    </td>
                    <td>
                      <human-date
                        v-if="object.accessed_date"
                        :date="object.accessed_date"
                      />
                      <translate
                        v-else
                        translate-context="*/*/*"
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
                  <translate translate-context="Content/Moderation/Title">
                    Audio content
                  </translate>&nbsp;
                </div>
              </h3>
              <table class="ui very basic table">
                <tbody>
                  <tr v-if="object.track">
                    <td>
                      <router-link :to="{name: 'manage.library.tracks.detail', params: {id: object.track.id }}">
                        <translate translate-context="*/*/*/Noun">
                          Track
                        </translate>
                      </router-link>
                    </td>
                    <td>
                      {{ object.track.title }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <translate translate-context="Content/Moderation/Table.Label/Noun">
                        Cached size
                      </translate>
                    </td>
                    <td>
                      <template v-if="object.audio_file">
                        {{ humanSize(object.size) }}
                      </template>
                      <translate
                        v-else
                        translate-context="*/*/*"
                      >
                        N/A
                      </translate>
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <translate translate-context="Content/*/*/Noun">
                        Size
                      </translate>
                    </td>
                    <td>
                      {{ humanSize(object.size) }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <translate translate-context="Content/Track/*/Noun">
                        Bitrate
                      </translate>
                    </td>
                    <td>
                      <template v-if="object.bitrate">
                        {{ humanSize(object.bitrate) }}/s
                      </template>
                      <translate
                        v-else
                        translate-context="*/*/*"
                      >
                        N/A
                      </translate>
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <translate translate-context="Content/*/*">
                        Duration
                      </translate>
                    </td>
                    <td>
                      <template v-if="object.duration">
                        {{ time.parse(object.duration) }}
                      </template>
                      <translate
                        v-else
                        translate-context="*/*/*"
                      >
                        N/A
                      </translate>
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.uploads', query: {q: getQuery('type', object.mimetype) }}">
                        <translate translate-context="Content/Track/Table.Label/Noun">
                          Type
                        </translate>
                      </router-link>
                    </td>
                    <td>
                      <template v-if="object.mimetype">
                        {{ object.mimetype }}
                      </template>
                      <translate
                        v-else
                        translate-context="*/*/*"
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
