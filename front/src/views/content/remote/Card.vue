<script setup lang="ts">
import type { Library } from '~/types'

import { useTimeoutFn } from '@vueuse/core'
import { computed, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useStore } from '~/store'

import axios from 'axios'

import RadioButton from '~/components/radios/Button.vue'

import useErrorHandler from '~/composables/useErrorHandler'
import useReport from '~/composables/moderation/useReport'

interface Emits {
  (e: 'followed'): void
}

interface Props {
  initialLibrary: Library
  displayFollow?: boolean
  displayScan?: boolean
  displayCopyFid?: boolean
}

const emit = defineEmits<Emits>()
const props = withDefaults(defineProps<Props>(), {
  displayFollow: true,
  displayScan: true,
  displayCopyFid: true
})

const { report, getReportableObjects } = useReport()
const store = useStore()

const library = ref(props.initialLibrary)
const isLoadingFollow = ref(false)
const showScan = ref(false)
const latestScan = ref(props.initialLibrary.latest_scan)

const scanProgress = computed(() => Math.min(latestScan.value.processed_files * 100 / latestScan.value.total_files, 100))
const scanStatus = computed(() => latestScan.value?.status ?? 'unknown')
const canLaunchScan = computed(() => scanStatus.value !== 'pending' && scanStatus.value !== 'scanning')
const radioPlayable = computed(() => (
  (library.value.actor.is_local || scanStatus.value === 'finished')
  && (library.value.privacy_level === 'everyone' || library.value.follow?.approved)
))

const { t } = useI18n()
const labels = computed(() => ({
  tooltips: {
    me: t('views.content.remote.Card.tooltip.private'),
    everyone: t('views.content.remote.Card.tooltip.public')
  }
}))

const launchScan = async () => {
  try {
    const response = await axios.post(`federation/libraries/${library.value.uuid}/scan/`)
    if (response.data.status !== 'skipped') {
      latestScan.value = response.data.scan
    }

    store.commit('ui/addMessage', {
      date: new Date(),
      content: response.data.status === 'skipped'
        ? t('views.content.remote.Card.message.scanSkipped')
        : t('views.content.remote.Card.message.scanLaunched')
    })
  } catch (error) {
    useErrorHandler(error as Error)
  }
}

const follow = async () => {
  isLoadingFollow.value = true
  try {
    const response = await axios.post('federation/follows/library/', { target: library.value.uuid })
    library.value.follow = response.data
    emit('followed')
  } catch (error) {
    console.error(error)
    store.commit('ui/addMessage', {
      content: t('views.content.remote.Card.error.follow', { error }),
      date: new Date()
    })
  }

  isLoadingFollow.value = false
}

const unfollow = async () => {
  isLoadingFollow.value = true
  try {
    if (library.value.follow) {
      await axios.delete(`federation/follows/library/${library.value.follow.uuid}/`)
      library.value.follow = undefined
    }
  } catch (error) {
    store.commit('ui/addMessage', {
      content: t('views.content.remote.Card.error.unfollow', { error }),
      date: new Date()
    })
  }

  isLoadingFollow.value = false
}

const fetchScanStatus = async () => {
  try {
    if (!library.value.follow) {
      return
    }

    const response = await axios.get(`federation/follows/library/${library.value.follow.uuid}/`)
    latestScan.value = response.data.target.latest_scan

    if (scanStatus.value === 'pending' || scanStatus.value === 'scanning') {
      startFetching()
    } else {
      stopFetching()
    }
  } catch (error) {
    useErrorHandler(error as Error)
  }
}

const { start: startFetching, stop: stopFetching } = useTimeoutFn(fetchScanStatus, 5000, { immediate: false })

watch(showScan, (shouldShow) => {
  if (shouldShow) {
    if (scanStatus.value === 'pending' || scanStatus.value === 'scanning') {
      fetchScanStatus()
    }

    return
  }

  stopFetching()
})
</script>

<template>
  <div class="ui card">
    <div class="content">
      <h4 class="header">
        <router-link :to="{name: 'library.detail', params: {id: library.uuid}}">
          {{ library.name }}
        </router-link>
        <div
          v-dropdown
          class="ui right floated dropdown"
        >
          <i class="ellipsis vertical large icon nomargin" />
          <div class="menu">
            <button
              v-for="obj in getReportableObjects({library, account: library.actor})"
              :key="obj.target.type + obj.target.id"
              class="item basic"
              @click.stop.prevent="report(obj)"
            >
              <i class="share icon" /> {{ obj.label }}
            </button>
          </div>
        </div>
        <span
          v-if="library.privacy_level === 'me'"
          class="right floated"
          :data-tooltip="labels.tooltips.me"
        >
          <i class="small lock icon" />
        </span>
        <span
          v-else-if="library.privacy_level === 'everyone'"
          class="right floated"
          :data-tooltip="labels.tooltips.everyone"
        >
          <i class="small globe icon" />
        </span>
      </h4>
      <div class="meta">
        <span>
          <i class="small outline clock icon" />
          <human-date :date="library.creation_date" />
        </span>
      </div>
      <div class="description">
        {{ library.description }}
        <div class="ui hidden divider" />
      </div>
      <div class="meta">
        <i class="music icon" />
        {{ $t('views.content.remote.Card.meta.tracks', library.uploads_count) }}
      </div>
      <div
        v-if="displayScan && latestScan"
        class="meta"
      >
        <template v-if="latestScan.status === 'pending'">
          <i class="hourglass icon" />
          {{ $t('views.content.remote.Card.label.scanPending') }}
        </template>
        <template v-if="latestScan.status === 'scanning'">
          <i class="loading spinner icon" />
          {{ $t('views.content.remote.Card.label.scanProgress', {progress: scanProgress}) }}
        </template>
        <template v-else-if="latestScan.status === 'errored'">
          <i class="dangerdownload icon" />
          {{ $t('views.content.remote.Card.label.scanFailure') }}
        </template>
        <template v-else-if="latestScan.status === 'finished' && latestScan.errored_files === 0">
          <i class="success download icon" />
          {{ $t('views.content.remote.Card.label.scanSuccess') }}
        </template>
        <template v-else-if="latestScan.status === 'finished' && latestScan.errored_files > 0">
          <i class="warning download icon" />
          {{ $t('views.content.remote.Card.label.scanPartialSuccess') }}
        </template>
        <a
          href=""
          class="link right floated"
          @click.prevent="showScan = !showScan"
        >
          {{ $t('views.content.remote.Card.link.scanDetails') }}
          <i
            v-if="showScan"
            class="angle down icon"
          />
          <i
            v-else
            class="angle right icon"
          />
        </a>
        <div v-if="showScan">
          <template v-if="latestScan.modification_date">
            {{ $t('views.content.remote.Card.meta.lastUpdate') }}<human-date :date="latestScan.modification_date" /><br>
          </template>
          {{ $t('views.content.remote.Card.meta.failedTracks', {tracks: latestScan.errored_files}) }}
        </div>
      </div>
      <div
        v-if="displayScan && canLaunchScan"
        class="clearfix"
      >
        <a
          href=""
          class="right floated link"
          @click.prevent="launchScan"
        >
          {{ $t('views.content.remote.Card.link.scan') }}<i class="paper plane icon" />
        </a>
      </div>
    </div>
    <div class="extra content">
      <actor-link
        style="color: var(--link-color)"
        :actor="library.actor"
      />
    </div>
    <div
      v-if="displayCopyFid"
      class="extra content"
    >
      <div class="ui form">
        <div class="field">
          <label :for="library.fid">{{ $t('views.content.remote.Card.label.sharingLink') }}</label>
          <copy-input
            :id="library.fid"
            :button-classes="'basic'"
            :value="library.fid"
          />
        </div>
      </div>
    </div>
    <div
      v-if="displayFollow || radioPlayable"
      :class="['ui', {two: displayFollow && radioPlayable}, 'bottom', 'attached', 'buttons']"
    >
      <radio-button
        v-if="radioPlayable"
        :type="'library'"
        :object-id="library.uuid"
      />
      <template v-if="displayFollow">
        <button
          v-if="!library.follow"
          :class="['ui', 'success', {'loading': isLoadingFollow}, 'button']"
          @click="follow()"
        >
          {{ $t('views.content.remote.Card.button.follow') }}
        </button>
        <template v-else-if="!library.follow.approved">
          <button
            class="ui disabled button"
          >
            <i class="hourglass icon" />
            {{ $t('views.content.remote.Card.button.pending') }}
          </button>
          <button
            class="ui button"
            @click="unfollow"
          >
            {{ $t('views.content.remote.Card.button.cancel') }}
          </button>
        </template>
        <template v-else-if="library.follow.approved">
          <dangerous-button
            :class="['ui', 'button']"
            :action="unfollow"
          >
            {{ $t('views.content.remote.Card.button.unfollow') }}
            <template #modal-header>
              <p>
                {{ $t('views.content.remote.Card.modal.unfollow.header') }}
              </p>
            </template>
            <template #modal-content>
              <div>
                <p>
                  {{ $t('views.content.remote.Card.modal.unfollow.content.warning') }}
                </p>
              </div>
            </template>
            <template #modal-confirm>
              <div>
                {{ $t('views.content.remote.Card.button.unfollow') }}
              </div>
            </template>
          </dangerous-button>
        </template>
      </template>
    </div>
  </div>
</template>
