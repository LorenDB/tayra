<script setup lang="ts">
import type { InstancePolicy } from '~/types'

import { humanSize } from '~/utils/filters'
import { useI18n } from 'vue-i18n'
import { computed, ref } from 'vue'
import { get } from 'lodash-es'

import axios from 'axios'

import InstancePolicyForm from '~/components/manage/moderation/InstancePolicyForm.vue'
import InstancePolicyCard from '~/components/manage/moderation/InstancePolicyCard.vue'

import useErrorHandler from '~/composables/useErrorHandler'

interface Props {
  id: number
  allowListEnabled: boolean
}

const props = defineProps<Props>()

const { t } = useI18n()

const labels = computed(() => ({
  statsWarning: t('views.admin.moderation.DomainsDetail.statsWarning')
}))

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

const isLoading = ref(false)
const object = ref()
const externalUrl = computed(() => `https://${object.value?.name}`)
const fetchData = async () => {
  isLoading.value = true

  try {
    const response = await axios.get(`manage/federation/domains/${props.id}/`)
    object.value = response.data
    if (response.data.instance_policy) {
      fetchPolicy(response.data.instance_policy)
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
    const response = await axios.get(`manage/federation/domains/${props.id}/stats/`)
    stats.value = response.data
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoadingStats.value = false
}

fetchStats()
fetchData()

const refreshNodeInfo = (data: any) => {
  object.value.nodeinfo = data
  object.value.nodeinfo_fetch_date = new Date()
}

const getQuery = (field: string, value: string) => `${field}:"${value}"`

const showPolicyForm = ref(false)
const updatePolicy = (newPolicy: InstancePolicy) => {
  policy.value = newPolicy
  showPolicyForm.value = false
}

const isLoadingAllowList = ref(false)
const setAllowList = async (value: boolean) => {
  isLoadingAllowList.value = true

  try {
    const response = await axios.patch(`manage/federation/domains/${props.id}/`, { allowed: value })
    object.value = response.data
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoadingAllowList.value = false
}
</script>

<template>
  <main class="page-admin-domain-detail">
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
        <div class="ui stackable two column grid">
          <div class="ui column">
            <div class="segment-content">
              <h2 class="ui header">
                <i class="circular inverted cloud icon" />
                <div class="content">
                  {{ object.name }}
                  <div class="sub header">
                    <a
                      :href="externalUrl"
                      target="_blank"
                      rel="noopener noreferrer"
                      class="logo-wrapper"
                    >
                      {{ $t('views.admin.moderation.DomainsDetail.websiteLink') }}&nbsp;
                      <i class="external icon" />
                    </a>
                  </div>
                </div>
              </h2>
              <div class="header-buttons">
                <div class="ui icon buttons">
                  <a
                    v-if="$store.state.auth.profile?.is_superuser"
                    class="ui labeled icon button"
                    :href="$store.getters['instance/absoluteUrl'](`/api/admin/federation/domain/${object.name}`)"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    <i class="wrench icon" />
                    {{ $t('views.admin.moderation.DomainsDetail.djangoLink') }}&nbsp;
                  </a>
                </div>
                <div
                  v-if="allowListEnabled"
                  class="ui icon buttons"
                >
                  <button
                    v-if="object.allowed"
                    :class="['ui', 'labeled', {loading: isLoadingAllowList}, 'icon', 'button']"
                    @click.prevent="setAllowList(false)"
                  >
                    <i class="x icon" />
                    {{ $t('views.admin.moderation.DomainsDetail.removeFromAllowList') }}
                  </button>
                  <button
                    v-else
                    :class="['ui', 'labeled', {loading: isLoadingAllowList}, 'icon', 'button']"
                    @click.prevent="setAllowList(true)"
                  >
                    <i class="check icon" />
                    {{ $t('views.admin.moderation.DomainsDetail.addToAllowList') }}
                  </button>
                </div>
              </div>
            </div>
          </div>
          <div class="ui column">
            <div class="ui compact clearing placeholder segment component-placeholder">
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
                    {{ $t('views.admin.moderation.DomainsDetail.noPolicyHeader') }}
                  </h3>
                </header>
                <p>
                  {{ $t('views.admin.moderation.DomainsDetail.policyDescription') }}
                </p>
                <button
                  class="ui primary button"
                  @click="showPolicyForm = true"
                >
                  {{ $t('views.admin.moderation.DomainsDetail.addPolicyButton') }}
                </button>
              </template>
              <instance-policy-card
                v-else-if="policy && !showPolicyForm"
                :object="policy"
                @update="showPolicyForm = true"
              >
                <header class="ui header">
                  <h3>
                    {{ $t('views.admin.moderation.DomainsDetail.activePolicyHeader') }}
                  </h3>
                </header>
              </instance-policy-card>
              <instance-policy-form
                v-else-if="showPolicyForm"
                :object="policy"
                type="domain"
                :target="object.name"
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
                  {{ $t('views.admin.moderation.DomainsDetail.instanceDataHeader') }}
                </div>
              </h3>
              <table class="ui very basic table">
                <tbody>
                  <tr v-if="allowListEnabled">
                    <td>
                      {{ $t('views.admin.moderation.DomainsDetail.inAllowListLabel') }}
                    </td>
                    <td>
                      <span
                        v-if="object.allowed"
                      >
                        {{ $t('views.admin.moderation.DomainsDetail.inAllowListTrue') }}
                      </span>
                      <span
                        v-else
                      >
                        {{ $t('views.admin.moderation.DomainsDetail.inAllowListFalse') }}
                      </span>
                    </td>
                  </tr>
                  <tr>
                    <td>
                      {{ $t('views.admin.moderation.DomainsDetail.lastCheckedLabel') }}
                    </td>
                    <td>
                      <human-date
                        v-if="object.nodeinfo_fetch_date"
                        :date="object.nodeinfo_fetch_date"
                      />
                      <span
                        v-else
                      >
                        {{ $t('views.admin.moderation.DomainsDetail.notApplicable') }}
                      </span>
                    </td>
                  </tr>

                  <template v-if="object.nodeinfo && object.nodeinfo.status === 'ok'">
                    <tr>
                      <td>
                        {{ $t('views.admin.moderation.DomainsDetail.softwareLabel') }}
                      </td>
                      <td>
                        {{ $t('views.admin.moderation.DomainsDetail.softwareValue', {name: get(object, 'nodeinfo.payload.software.name', t('views.admin.moderation.DomainsDetail.notApplicable')), version: get(object, 'nodeinfo.payload.software.version', t('views.admin.moderation.DomainsDetail.notApplicable'))}) }}
                      </td>
                    </tr>
                    <tr>
                      <td>
                        {{ $t('views.admin.moderation.DomainsDetail.domainNameLabel') }}
                      </td>
                      <td>
                        {{ get(object, 'nodeinfo.payload.metadata.nodeName', t('views.admin.moderation.DomainsDetail.notApplicable')) }}
                      </td>
                    </tr>
                    <tr>
                      <td>
                        {{ $t('views.admin.moderation.DomainsDetail.totalUsersLabel') }}
                      </td>
                      <td>
                        {{ get(object, 'nodeinfo.payload.usage.users.total', t('views.admin.moderation.DomainsDetail.notApplicable')) }}
                      </td>
                    </tr>
                  </template>
                  <template v-if="object.nodeinfo && object.nodeinfo.status === 'error'">
                    <tr>
                      <td>
                        {{ $t('views.admin.moderation.DomainsDetail.nodeInfoStatusLabel') }}
                      </td>
                      <td>
                        {{ $t('views.admin.moderation.DomainsDetail.nodeInfoFailureMessage') }}&nbsp;

                        <span :data-tooltip="object.nodeinfo.error"><i class="question circle icon" /></span>
                      </td>
                    </tr>
                  </template>
                </tbody>
              </table>
              <ajax-button
                method="get"
                :url="'manage/federation/domains/' + object.name + '/nodeinfo/'"
                @action-done="refreshNodeInfo"
              >
                {{ $t('views.admin.moderation.DomainsDetail.refreshNodeInfoButton') }}
              </ajax-button>
            </section>
          </div>
          <div class="column">
            <section>
              <h3 class="ui header">
                <i class="feed icon" />
                <div class="content">
                  {{ $t('views.admin.moderation.DomainsDetail.activityHeader') }}&nbsp;
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
                      {{ $t('views.admin.moderation.DomainsDetail.firstSeenLabel') }}
                    </td>
                    <td>
                      <human-date :date="object.creation_date" />
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link
                        :to="{name: 'manage.moderation.accounts.list', query: {q: 'domain:' + object.name }}"
                      >
                        {{ $t('views.admin.moderation.DomainsDetail.knownAccountsLink') }}
                      </router-link>
                    </td>
                    <td>
                      {{ stats.actors }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      {{ $t('views.admin.moderation.DomainsDetail.emittedMessagesLabel') }}
                    </td>
                    <td>
                      {{ stats.outbox_activities }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      {{ $t('views.admin.moderation.DomainsDetail.receivedFollowsLabel') }}
                    </td>
                    <td>
                      {{ stats.received_library_follows }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      {{ $t('views.admin.moderation.DomainsDetail.emittedFollowsLabel') }}
                    </td>
                    <td>
                      {{ stats.emitted_library_follows }}
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
                  {{ $t('views.admin.moderation.DomainsDetail.audioContentHeader') }}&nbsp;
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
                      {{ $t('views.admin.moderation.DomainsDetail.cachedSizeLabel') }}
                    </td>
                    <td>
                      {{ humanSize(stats.media_downloaded_size) }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      {{ $t('views.admin.moderation.DomainsDetail.totalSizeLabel') }}
                    </td>
                    <td>
                      {{ humanSize(stats.media_total_size) }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.channels', query: {q: getQuery('domain', object.name) }}">
                        {{ $t('views.admin.moderation.DomainsDetail.channelsLabel') }}
                      </router-link>
                    </td>
                    <td>
                      {{ stats.channels }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.libraries', query: {q: getQuery('domain', object.name) }}">
                        {{ $t('views.admin.moderation.DomainsDetail.librariesLabel') }}
                      </router-link>
                    </td>
                    <td>
                      {{ stats.libraries }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.uploads', query: {q: getQuery('domain', object.name) }}">
                        {{ $t('views.admin.moderation.DomainsDetail.uploadsLabel') }}
                      </router-link>
                    </td>
                    <td>
                      {{ stats.uploads }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.artists', query: {q: getQuery('domain', object.name) }}">
                        {{ $t('views.admin.moderation.DomainsDetail.artistsLabel') }}
                      </router-link>
                    </td>
                    <td>
                      {{ stats.artists }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.albums', query: {q: getQuery('domain', object.name) }}">
                        {{ $t('views.admin.moderation.DomainsDetail.albumsLabel') }}
                      </router-link>
                    </td>
                    <td>
                      {{ stats.albums }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.tracks', query: {q: getQuery('domain', object.name) }}">
                        {{ $t('views.admin.moderation.DomainsDetail.tracksLabel') }}
                      </router-link>
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
