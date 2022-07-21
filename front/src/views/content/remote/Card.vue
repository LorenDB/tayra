<script setup lang="ts">
import type { Library } from '~/types'

import axios from 'axios'
import RadioButton from '~/components/radios/Button.vue'
import useReport from '~/composables/moderation/useReport'
import { useTimeoutFn } from '@vueuse/core'
import { useStore } from '~/store'
import { useGettext } from 'vue3-gettext'
import { computed, ref, watch } from 'vue'

interface Props {
  initialLibrary: Library
  displayFollow?: boolean
  displayScan?: boolean
  displayCopyFid?: boolean
}

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

const { $pgettext } = useGettext()
const labels = computed(() => ({
  tooltips: {
    me: $pgettext('Content/Library/Card.Help text', 'This library is private and your approval from its owner is needed to access its content'),
    everyone: $pgettext('Content/Library/Card.Help text', 'This library is public and you can access its content freely')
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
        ? $pgettext('Content/Library/Message', 'Scan skipped (previous scan is too recent)')
        : $pgettext('Content/Library/Message', 'Scan launched')
    })
  } catch (error) {
    // TODO (wvffle): Handle error
  }
}

const emit = defineEmits(['followed', 'deleted'])
const follow = async () => {
  isLoadingFollow.value = true
  try {
    const response = await axios.post('federation/follows/library/', { target: library.value.uuid })
    library.value.follow = response.data
    emit('followed')
  } catch (error) {
    // TODO (wvffle): ==> CORRECTLY HANDLED ERROR HERE <==
    store.commit('ui/addMessage', {
      // TODO (wvffle): Translate
      content: 'Cannot follow remote library: ' + error,
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
      // TODO (wvffle): Translate
      content: 'Cannot unfollow remote library: ' + error,
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
    // TODO (wvffle): Handle error
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
        <translate
          translate-context="*/*/*"
          :translate-params="{count: library.uploads_count}"
          :translate-n="library.uploads_count"
          translate-plural="%{ count } tracks"
        >
          %{ count } track
        </translate>
      </div>
      <div
        v-if="displayScan && latestScan"
        class="meta"
      >
        <template v-if="latestScan.status === 'pending'">
          <i class="hourglass icon" />
          <translate translate-context="Content/Library/Card.List item">
            Scan pending
          </translate>
        </template>
        <template v-if="latestScan.status === 'scanning'">
          <i class="loading spinner icon" />
          <translate
            translate-context="Content/Library/Card.List item"
            :translate-params="{progress: scanProgress}"
          >
            Scanning… (%{ progress }%)
          </translate>
        </template>
        <template v-else-if="latestScan.status === 'errored'">
          <i class="dangerdownload icon" />
          <translate translate-context="Content/Library/Card.List item">
            Problem during scanning
          </translate>
        </template>
        <template v-else-if="latestScan.status === 'finished' && latestScan.errored_files === 0">
          <i class="success download icon" />
          <translate translate-context="Content/Library/Card.List item">
            Scanned
          </translate>
        </template>
        <template v-else-if="latestScan.status === 'finished' && latestScan.errored_files > 0">
          <i class="warning download icon" />
          <translate translate-context="Content/Library/Card.List item">
            Scanned with errors
          </translate>
        </template>
        <a
          href=""
          class="link right floated"
          @click.prevent="showScan = !showScan"
        >
          <translate translate-context="Content/Library/Card.Button.Label/Noun">Details</translate>
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
            <translate translate-context="Content/Library/Card.List item/Noun">
              Last update:
            </translate><human-date :date="latestScan.modification_date" /><br>
          </template>
          <translate translate-context="Content/Library/Card.List item/Noun">
            Failed tracks:
          </translate> {{ latestScan.errored_files }}
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
          <translate translate-context="Content/Library/Card.Button.Label/Verb">Scan now</translate> <i class="paper plane icon" />
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
          <label :for="library.fid"><translate translate-context="Content/Library/Title">Sharing link</translate></label>
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
          <translate translate-context="Content/Library/Card.Button.Label/Verb">
            Follow
          </translate>
        </button>
        <template v-else-if="!library.follow.approved">
          <button
            class="ui disabled button"
          >
            <i class="hourglass icon" />
            <translate translate-context="Content/Library/Card.Paragraph">
              Follow request pending approval
            </translate>
          </button>
          <button
            class="ui button"
            @click="unfollow"
          >
            <translate translate-context="Content/Library/Card.Paragraph">
              Cancel follow request
            </translate>
          </button>
        </template>
        <template v-else-if="library.follow.approved">
          <dangerous-button
            :class="['ui', 'button']"
            :action="unfollow"
          >
            <translate translate-context="*/Library/Button.Label/Verb">
              Unfollow
            </translate>
            <template #modal-header>
              <p>
                <translate translate-context="Popup/Library/Title">
                  Unfollow this library?
                </translate>
              </p>
            </template>
            <template #modal-content>
              <div>
                <p>
                  <translate translate-context="Popup/Library/Paragraph">
                    By unfollowing this library, you loose access to its content.
                  </translate>
                </p>
              </div>
            </template>
            <template #modal-confirm>
              <div>
                <translate translate-context="*/Library/Button.Label/Verb">
                  Unfollow
                </translate>
              </div>
            </template>
          </dangerous-button>
        </template>
      </template>
    </div>
  </div>
</template>
