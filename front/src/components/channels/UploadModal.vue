<script setup lang="ts">
import SemanticModal from '~/components/semantic/Modal.vue'
import ChannelUploadForm from '~/components/channels/UploadForm.vue'
import { humanSize } from '~/utils/filters'
import { useRouter } from 'vue-router'
import { useStore } from '~/store'
import { ref, computed } from 'vue'
import { useI18n } from 'vue-i18n'

const store = useStore()
const router = useRouter()
router.beforeEach(() => store.commit('channels/showUploadModal', { show: false }))

const update = (value: boolean) => store.commit('channels/showUploadModal', { show: value })

const { t } = useI18n()

const uploadForm = ref()

const statusData = ref()
const statusInfo = computed(() => {
  if (!statusData.value) {
    return []
  }

  const info = []
  if (statusData.value.totalSize) {
    info.push(humanSize(statusData.value.totalSize))
  }

  if (statusData.value.totalFiles) {
    info.push(t('components.channels.UploadModal.meta.files', statusData.value.totalFiles))
  }

  if (statusData.value.progress) {
    info.push(`${statusData.value.progress}%`)
  }

  if (statusData.value.speed) {
    info.push(`${humanSize(statusData.value.speed)}/s`)
  }

  return info
})

const step = ref(1)
const isLoading = ref(false)
</script>

<template>
  <semantic-modal
    v-model:show="$store.state.channels.showUploadModal"
    class="small"
  >
    <h4 class="header">
      <span v-if="step === 1">
        {{ $t('components.channels.UploadModal.header.publish') }}
      </span>
      <span v-else-if="step === 2">
        {{ $t('components.channels.UploadModal.header.uploadFiles') }}
      </span>
      <span v-else-if="step === 3">
        {{ $t('components.channels.UploadModal.header.uploadDetails') }}
      </span>
      <span v-else-if="step === 4">
        {{ $t('components.channels.UploadModal.header.processing') }}
      </span>
    </h4>
    <div class="scrolling content">
      <channel-upload-form
        ref="uploadForm"
        :channel="$store.state.channels.uploadModalConfig.channel ?? null"
        @step="step = $event"
        @loading="isLoading = $event"
        @status="statusData = $event"
      />
    </div>
    <div class="actions">
      <div class="left floated text left align">
        <template v-if="statusData && step >= 2">
          {{ statusInfo.join(' · ') }}
        </template>
        <div class="ui very small hidden divider" />
        <template v-if="statusData && statusData.quotaStatus">
          {{ $t('components.channels.UploadModal.meta.quota', humanSize((statusData.quotaStatus.remaining - statusData.uploadedSize) * 1000 * 1000)) }}
        </template>
      </div>
      <div class="ui hidden clearing divider mobile-only" />
      <button
        v-if="step === 1"
        class="ui basic cancel button"
      >
        {{ $t('components.channels.UploadModal.button.cancel') }}
      </button>
      <button
        v-else-if="step < 3"
        class="ui basic button"
        @click.stop.prevent="uploadForm.step -= 1"
      >
        {{ $t('components.channels.UploadModal.button.previous') }}
      </button>
      <button
        v-else-if="step === 3"
        class="ui basic button"
        @click.stop.prevent="uploadForm.step -= 1"
      >
        {{ $t('components.channels.UploadModal.button.update') }}
      </button>
      <button
        v-if="step === 1"
        class="ui primary button"
        @click.stop.prevent="uploadForm.step += 1"
      >
        {{ $t('components.channels.UploadModal.button.next') }}
      </button>
      <div
        v-if="step === 2"
        class="ui primary buttons"
      >
        <button
          :class="['ui', 'primary button', {loading: isLoading}]"
          type="submit"
          :disabled="!statusData?.canSubmit || undefined"
          @click.prevent.stop="uploadForm.publish"
        >
          {{ $t('components.channels.UploadModal.button.publish') }}
        </button>
        <button
          ref="dropdown"
          v-dropdown
          class="ui floating dropdown icon button"
          :disabled="!statusData?.canSubmit || undefined"
        >
          <i class="dropdown icon" />
          <div class="menu">
            <div
              role="button"
              class="basic item"
              @click="update(false)"
            >
              {{ $t('components.channels.UploadModal.button.finishLater') }}
            </div>
          </div>
        </button>
      </div>
      <button
        v-if="step === 4"
        class="ui basic cancel button"
        @click="update(false)"
      >
        {{ $t('components.channels.UploadModal.button.close') }}
      </button>
    </div>
  </semantic-modal>
</template>
