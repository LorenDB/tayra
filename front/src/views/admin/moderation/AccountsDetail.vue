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
  statsWarning: t('Statistics are computed from known activity and content on your instance, and do not reflect general activity for this object'),
  uploadQuota: t('Determine how much content the user can upload. Leave empty to use the default value of the instance.')
}))

const allPermissions = computed(() => [
  { code: 'library', label: t('Library') },
  { code: 'moderation', label: t('Moderation') },
  { code: 'settings', label: t('Settings') }
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
                        Local account
                      </span>
                      &nbsp;
                    </template>
                    <a
                      :href="object.url || object.fid"
                      target="_blank"
                      rel="noopener noreferrer"
                    >
                      Open profile&nbsp;
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
                    View in Django's admin&nbsp;
                  </a>
                  <a
                    v-else-if="$store.state.auth.profile && $store.state.auth.profile.is_superuser"
                    class="ui labeled icon button"
                    :href="$store.getters['instance/absoluteUrl'](`/api/admin/federation/actor/${object.id}`)"
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
                    You don't have any rule in place for this account.
                  </h3>
                </header>
                <p>
                  Moderation policies help you control how your instance interact with a given domain or account.
                </p>
                <button
                  class="ui primary button"
                  @click="showPolicyForm = true"
                >
                  Add a moderation policy
                </button>
              </template>
              <instance-policy-card
                v-else-if="policy && !showPolicyForm"
                :object="policy"
                @update="showPolicyForm = true"
              >
                <header class="ui header">
                  <h3>
                    This domain is subject to specific moderation rules
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
                  Account data
                </div>
              </h3>
              <table class="ui very basic table">
                <tbody>
                  <tr>
                    <td>
                      Username
                    </td>
                    <td>
                      {{ object.preferred_username }}
                    </td>
                  </tr>
                  <tr v-if="!object.user">
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
                      Display name
                    </td>
                    <td>
                      {{ object.name }}
                    </td>
                  </tr>
                  <tr v-if="object.user">
                    <td>
                      Email address
                    </td>
                    <td>
                      {{ object.user.email }}
                    </td>
                  </tr>
                  <tr v-if="object.user">
                    <td>
                      Login status
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
                          <translate
                            v-if="object.user.is_active"
                          >Enabled</translate>
                          <translate
                            v-else
                          >Disabled</translate>
                        </label>
                      </div>
                      <translate
                        v-else-if="object.user.is_active"
                      >
                        Enabled
                      </translate>
                      <translate
                        v-else
                      >
                        Disabled
                      </translate>
                    </td>
                  </tr>
                  <tr v-if="object.user">
                    <td>
                      Permissions
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
                      Type
                    </td>
                    <td>
                      {{ object.type }}
                    </td>
                  </tr>
                  <tr v-if="!object.user">
                    <td>
                      Last checked
                    </td>
                    <td>
                      <human-date
                        v-if="object.last_fetch_date"
                        :date="object.last_fetch_date"
                      />
                      <translate
                        v-else
                      >
                        N/A
                      </translate>
                    </td>
                  </tr>
                  <tr v-if="object.user">
                    <td>
                      Sign-up date
                    </td>
                    <td>
                      <human-date :date="object.user.date_joined" />
                    </td>
                  </tr>
                  <tr v-if="object.user">
                    <td>
                      Last activity
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
                  <tr v-if="!object.user">
                    <td>
                      First seen
                    </td>
                    <td>
                      <human-date :date="object.creation_date" />
                    </td>
                  </tr>
                  <tr>
                    <td>
                      Emitted messages
                    </td>
                    <td>
                      {{ stats.outbox_activities }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      Received library follows
                    </td>
                    <td>
                      {{ stats.received_library_follows }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      Emitted library follows
                    </td>
                    <td>
                      {{ stats.emitted_library_follows }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.moderation.reports.list', query: {q: getQuery('target', `account:${object.full_username}`) }}">
                        Linked reports
                      </router-link>
                    </td>
                    <td>
                      {{ stats.reports }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.moderation.requests.list', query: {q: getQuery('submitter', `${object.full_username}`) }}">
                        Requests
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
                  <tr v-if="!object.user">
                    <td>
                      Cached size
                    </td>
                    <td>
                      {{ humanSize(stats.media_downloaded_size) }}
                    </td>
                  </tr>
                  <tr v-if="object.user">
                    <td>
                      Upload quota
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
                          MB&#32;
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
                      Total size
                    </td>
                    <td>
                      {{ humanSize(stats.media_total_size) }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.channels', query: {q: getQuery('account', object.full_username) }}">
                        Channels
                      </router-link>
                    </td>
                    <td>
                      {{ stats.channels }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.libraries', query: {q: getQuery('account', object.full_username) }}">
                        Libraries
                      </router-link>
                    </td>
                    <td>
                      {{ stats.libraries }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.uploads', query: {q: getQuery('account', object.full_username) }}">
                        Uploads
                      </router-link>
                    </td>
                    <td>
                      {{ stats.uploads }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      Artists
                    </td>
                    <td>
                      {{ stats.artists }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      Albums
                    </td>
                    <td>
                      {{ stats.albums }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      Tracks
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
