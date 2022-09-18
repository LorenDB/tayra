<script setup lang="ts">
import type { InstancePolicy } from '~/types'

import { computed, ref, reactive, nextTick, watch } from 'vue'
import { useCurrentElement } from '@vueuse/core'
import { humanSize } from '~/utils/filters'
import { useI18n } from 'vue-i18n'

import axios from 'axios'
import $ from 'jquery'

import InstancePolicyForm from '~/components/manage/moderation/InstancePolicyForm.vue'
import InstancePolicyCard from '~/components/manage/moderation/InstancePolicyCard.vue'

import useErrorHandler from '~/composables/useErrorHandler'
import useLogger from '~/composables/useLogger'

interface Props {
  id: number
}

const props = defineProps<Props>()

const { t } = useI18n()

const logger = useLogger()

const labels = computed(() => ({
  statsWarning: t('views.admin.moderation.AccountsDetail.statsWarning'),
  uploadQuota: t('views.admin.moderation.AccountsDetail.uploadQuota')
}))

const allPermissions = computed(() => [
  { code: 'library', label: t('views.admin.moderation.AccountsDetail.libraryPermission') },
  { code: 'moderation', label: t('views.admin.moderation.AccountsDetail.moderationPermission') },
  { code: 'settings', label: t('views.admin.moderation.AccountsDetail.settingsPermission') }
])

const isLoadingPolicy = ref(false)
const policy = ref()
const fetchPolicy = async (id: number) => {
  isLoadingPolicy.value = true

  try {
    const response = await axios.get(`manage/moderation/instance-policies/${id}/`)
    policy.value = response.data
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoadingPolicy.value = false
}

const permissions = reactive([] as string[])
const isLoading = ref(false)
const object = ref()
const fetchData = async () => {
  isLoading.value = true

  try {
    const response = await axios.get(`manage/accounts/${props.id}/`)
    object.value = response.data

    if (response.data.instance_policy) {
      fetchPolicy(response.data.instance_policy)
    }

    if (response.data.user) {
      for (const { code } of allPermissions.value) {
        if (response.data.user.permissions[code]) {
          permissions.push(code)
        }
      }
    }
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
    const response = await axios.get(`manage/accounts/${props.id}/stats/`)
    stats.value = response.data
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoadingStats.value = false
}

fetchStats()
fetchData()

const el = useCurrentElement()
watch(object, async () => {
  await nextTick()
  $(el.value).find('select.dropdown').dropdown()
})

const getQuery = (field: string, value: string) => `${field}:"${value}"`

const updating = reactive(new Set<string>())
const updateUser = async (attr: string, toNull = false) => {
  let newValue = object.value.user[attr]
  if (toNull && !newValue) {
    newValue = null
  }

  updating.add(attr)

  const params = {
    [attr]: newValue
  }

  if (attr === 'permissions') {
    params.permissions = allPermissions.value.reduce((acc, { code }) => {
      acc[code] = permissions.includes(code)
      return acc
    }, {} as Record<string, boolean>)
  }

  try {
    await axios.patch(`manage/users/users/${object.value.user.id}/`, params)
    logger.info(`${attr} was updated successfully to ${newValue}`)
  } catch (error) {
    logger.error(`Error while setting ${attr} to ${newValue}`, error)
    // TODO: Use error handler
  }

  updating.delete(attr)
}

const showPolicyForm = ref(false)
const updatePolicy = (newPolicy: InstancePolicy) => {
  policy.value = newPolicy
  showPolicyForm.value = false
}
</script>

<template>
  <main class="page-admin-account-detail">
    <div
      v-if="isLoading"
      class="ui vertical segment"
    >
      <div :class="['ui', 'centered', 'active', 'inline', 'loader']" />
    </div>
    <template v-if="object">
      <section
        v-title="object.full_username"
        :class="['ui', 'head', 'vertical', 'stripe', 'segment']"
      >
        <div class="ui stackable two column grid">
          <div class="ui column">
            <div class="segment-content">
              <h2 class="ui header">
                <i class="circular inverted user icon" />
                <div class="content">
                  {{ object.full_username }}
                  <div class="sub header">
                    <template v-if="object.user">
                      <span class="ui tiny accent label">
                        <i class="home icon" />
                        {{ $t('views.admin.moderation.AccountsDetail.localAccountLabel') }}
                      </span>
                      &nbsp;
                    </template>
                    <a
                      :href="object.url || object.fid"
                      target="_blank"
                      rel="noopener noreferrer"
                    >
                      {{ $t('views.admin.moderation.AccountsDetail.openProfileLink') }}&nbsp;
                      <i class="external icon" />
                    </a>
                  </div>
                </div>
              </h2>
              <div class="header-buttons">
                <div class="ui icon buttons">
                  <a
                    v-if="object.user && $store.state.auth.profile && $store.state.auth.profile.is_superuser"
                    class="ui labeled icon button"
                    :href="$store.getters['instance/absoluteUrl'](`/api/admin/users/user/${object.user.id}`)"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    <i class="wrench icon" />
                    {{ $t('views.admin.moderation.AccountsDetail.djangoLink') }}&nbsp;
                  </a>
                  <a
                    v-else-if="$store.state.auth.profile && $store.state.auth.profile.is_superuser"
                    class="ui labeled icon button"
                    :href="$store.getters['instance/absoluteUrl'](`/api/admin/federation/actor/${object.id}`)"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    <i class="wrench icon" />
                    {{ $t('views.admin.moderation.AccountsDetail.djangoLink') }}&nbsp;
                  </a>
                  <button
                    v-dropdown
                    class="ui floating dropdown icon button"
                  >
                    <i class="dropdown icon" />
                    <div class="menu">
                      <a
                        class="basic item"
                        :href="object.url || object.fid"
                        target="_blank"
                        rel="noopener noreferrer"
                      >
                        <i class="external icon" />
                        {{ $t('views.admin.moderation.AccountsDetail.remoteProfileLink') }}&nbsp;
                      </a>
                    </div>
                  </button>
                </div>
              </div>
            </div>
          </div>
          <div class="ui column">
            <div
              v-if="!object.user"
              class="ui compact clearing placeholder segment component-placeholder"
            >
              <template v-if="isLoadingPolicy">
                <div class="paragraph">
                  <div class="line" />
                  <div class="line" />
                  <div class="line" />
                  <div class="line" />
                  <div class="line" />
                </div>
              </template>
              <template v-else-if="!policy && !showPolicyForm">
                <header class="ui header">
                  <h3>
                    <i class="shield icon" />
                    {{ $t('views.admin.moderation.AccountsDetail.noPolicyHeader') }}
                  </h3>
                </header>
                <p>
                  {{ $t('views.admin.moderation.AccountsDetail.policyDescription') }}
                </p>
                <button
                  class="ui primary button"
                  @click="showPolicyForm = true"
                >
                  {{ $t('views.admin.moderation.AccountsDetail.addPolicyButton') }}
                </button>
              </template>
              <instance-policy-card
                v-else-if="policy && !showPolicyForm"
                :object="policy"
                @update="showPolicyForm = true"
              >
                <header class="ui header">
                  <h3>
                    {{ $t('views.admin.moderation.AccountsDetail.activePolicyHeader') }}
                  </h3>
                </header>
              </instance-policy-card>
              <instance-policy-form
                v-else-if="showPolicyForm"
                :object="policy"
                type="actor"
                :target="object.full_username"
                @cancel="showPolicyForm = false"
                @save="updatePolicy"
                @delete="policy = null; showPolicyForm = false"
              />
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
                  {{ $t('views.admin.moderation.AccountsDetail.accountDataHeader') }}
                </div>
              </h3>
              <table class="ui very basic table">
                <tbody>
                  <tr>
                    <td>
                      {{ $t('views.admin.moderation.AccountsDetail.usernameLabel') }}
                    </td>
                    <td>
                      {{ object.preferred_username }}
                    </td>
                  </tr>
                  <tr v-if="!object.user">
                    <td>
                      <router-link :to="{name: 'manage.moderation.domains.detail', params: {id: object.domain }}">
                        {{ $t('views.admin.moderation.AccountsDetail.domainLabel') }}
                      </router-link>
                    </td>
                    <td>
                      {{ object.domain }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      {{ $t('views.admin.moderation.AccountsDetail.displayNameLabel') }}
                    </td>
                    <td>
                      {{ object.name }}
                    </td>
                  </tr>
                  <tr v-if="object.user">
                    <td>
                      {{ $t('views.admin.moderation.AccountsDetail.emailLabel') }}
                    </td>
                    <td>
                      {{ object.user.email }}
                    </td>
                  </tr>
                  <tr v-if="object.user">
                    <td>
                      {{ $t('views.admin.moderation.AccountsDetail.loginStatusLabel') }}
                    </td>
                    <td>
                      <div
                        v-if="object.user.username != $store.state.auth.profile?.username"
                        class="ui toggle checkbox"
                      >
                        <input
                          id="is-active"
                          v-model="object.user.is_active"
                          type="checkbox"
                          @change="updateUser('is_active')"
                        >
                        <label for="is-active">
                          <span
                            v-if="object.user.is_active"
                          >{{ $t('views.admin.moderation.AccountsDetail.enabledStatus') }}</span>
                          <span
                            v-else
                          >{{ $t('views.admin.moderation.AccountsDetail.disabledStatus') }}</span>
                        </label>
                      </div>
                      <span
                        v-else-if="object.user.is_active"
                      >
                        {{ $t('views.admin.moderation.AccountsDetail.enabledStatus') }}
                      </span>
                      <span
                        v-else
                      >
                        {{ $t('views.admin.moderation.AccountsDetail.disabledStatus') }}
                      </span>
                    </td>
                  </tr>
                  <tr v-if="object.user">
                    <td>
                      {{ $t('views.admin.moderation.AccountsDetail.permissionsLabel') }}
                    </td>
                    <td>
                      <select
                        v-model="permissions"
                        multiple
                        class="ui search selection dropdown"
                        @change="updateUser('permissions')"
                      >
                        <option
                          v-for="(p, key) in allPermissions"
                          :key="key"
                          :value="p.code"
                        >
                          {{ p.label }}
                        </option>
                      </select>
                      <action-feedback :is-loading="updating.has('permissions')" />
                    </td>
                  </tr>
                  <tr>
                    <td>
                      {{ $t('views.admin.moderation.AccountsDetail.userTypeLabel') }}
                    </td>
                    <td>
                      {{ object.type }}
                    </td>
                  </tr>
                  <tr v-if="!object.user">
                    <td>
                      {{ $t('views.admin.moderation.AccountsDetail.lastCheckedLabel') }}
                    </td>
                    <td>
                      <human-date
                        v-if="object.last_fetch_date"
                        :date="object.last_fetch_date"
                      />
                      <span
                        v-else
                      >
                        {{ $t('views.admin.moderation.AccountsDetail.notApplicable') }}
                      </span>
                    </td>
                  </tr>
                  <tr v-if="object.user">
                    <td>
                      {{ $t('views.admin.moderation.AccountsDetail.signupDateLabel') }}
                    </td>
                    <td>
                      <human-date :date="object.user.date_joined" />
                    </td>
                  </tr>
                  <tr v-if="object.user">
                    <td>
                      {{ $t('views.admin.moderation.AccountsDetail.lastActivityLabel') }}
                    </td>
                    <td>
                      <human-date :date="object.user.last_activity" />
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
                  {{ $t('views.admin.moderation.AccountsDetail.activityHeader') }}&nbsp;
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
                  <tr v-if="!object.user">
                    <td>
                      {{ $t('views.admin.moderation.AccountsDetail.firstSeenLabel') }}
                    </td>
                    <td>
                      <human-date :date="object.creation_date" />
                    </td>
                  </tr>
                  <tr>
                    <td>
                      {{ $t('views.admin.moderation.AccountsDetail.emittedMessagesLabel') }}
                    </td>
                    <td>
                      {{ stats.outbox_activities }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      {{ $t('views.admin.moderation.AccountsDetail.receivedFollowsLabel') }}
                    </td>
                    <td>
                      {{ stats.received_library_follows }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      {{ $t('views.admin.moderation.AccountsDetail.emittedFollowsLabel') }}
                    </td>
                    <td>
                      {{ stats.emitted_library_follows }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.moderation.reports.list', query: {q: getQuery('target', `account:${object.full_username}`) }}">
                        {{ $t('views.admin.moderation.AccountsDetail.linkedReportsLabel') }}
                      </router-link>
                    </td>
                    <td>
                      {{ stats.reports }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.moderation.requests.list', query: {q: getQuery('submitter', `${object.full_username}`) }}">
                        {{ $t('views.admin.moderation.AccountsDetail.requestsLabel') }}
                      </router-link>
                    </td>
                    <td>
                      {{ stats.requests }}
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
                  {{ $t('views.admin.moderation.AccountsDetail.audioContentHeader') }}&nbsp;
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
                  <tr v-if="!object.user">
                    <td>
                      {{ $t('views.admin.moderation.AccountsDetail.cachedSizeLabel') }}
                    </td>
                    <td>
                      {{ humanSize(stats.media_downloaded_size) }}
                    </td>
                  </tr>
                  <tr v-if="object.user">
                    <td>
                      {{ $t('views.admin.moderation.AccountsDetail.uploadQuotaLabel') }}
                      <span :data-tooltip="labels.uploadQuota"><i class="question circle icon" /></span>
                    </td>
                    <td>
                      <div class="ui right labeled input">
                        <input
                          v-model.number="object.user.upload_quota"
                          step="100"
                          name="quota"
                          type="number"
                          @change="updateUser('upload_quota', true)"
                        >
                        <div class="ui basic label">
                          {{ $t('views.admin.moderation.AccountsDetail.megabyteLabel') }}
                        </div>
                        <action-feedback
                          class="ui basic label"
                          size="tiny"
                          :is-loading="updating.has('upload_quota')"
                        />
                      </div>
                    </td>
                  </tr>
                  <tr>
                    <td>
                      {{ $t('views.admin.moderation.AccountsDetail.totalSizeLabel') }}
                    </td>
                    <td>
                      {{ humanSize(stats.media_total_size) }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.channels', query: {q: getQuery('account', object.full_username) }}">
                        {{ $t('views.admin.moderation.AccountsDetail.channelsLabel') }}
                      </router-link>
                    </td>
                    <td>
                      {{ stats.channels }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.libraries', query: {q: getQuery('account', object.full_username) }}">
                        {{ $t('views.admin.moderation.AccountsDetail.librariesLabel') }}
                      </router-link>
                    </td>
                    <td>
                      {{ stats.libraries }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.uploads', query: {q: getQuery('account', object.full_username) }}">
                        {{ $t('views.admin.moderation.AccountsDetail.uploadsLabel') }}
                      </router-link>
                    </td>
                    <td>
                      {{ stats.uploads }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      {{ $t('views.admin.moderation.AccountsDetail.artistsLabel') }}
                    </td>
                    <td>
                      {{ stats.artists }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      {{ $t('views.admin.moderation.AccountsDetail.albumsLabel') }}
                    </td>
                    <td>
                      {{ stats.albums }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      {{ $t('views.admin.moderation.AccountsDetail.tracksLabel') }}
                    </td>
                    <td>
                      {{ stats.tracks }}
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
