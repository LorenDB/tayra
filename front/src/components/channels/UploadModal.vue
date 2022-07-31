<script setup lang="ts">
import SemanticModal from '~/components/semantic/Modal.vue'
import ChannelUploadForm from '~/components/channels/UploadForm.vue'
import { humanSize } from '~/utils/filters'
import { useRouter } from 'vue-router'
import { useStore } from '~/store'
import { ref, computed } from 'vue'
import { useGettext } from 'vue3-gettext'

const store = useStore()
const router = useRouter()
router.beforeEach(() => store.commit('channels/showUploadModal', { show: false }))

const update = (value: boolean) => store.commit('channels/showUploadModal', { show: value })

const { $npgettext, $gettext } = useGettext()

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
    const msg = $npgettext('*/*/*', '%{ count } file', '%{ count } files', statusData.value.totalFiles)
    info.push($gettext(msg, { count: statusData.value.totalFiles }))
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
      <translate
        v-if="step === 1"
        translate-context="Popup/Channels/Title/Verb"
      >
        Publish audio
      </translate>
      <translate
        v-else-if="step === 2"
        translate-context="Popup/Channels/Title"
      >
        Files to upload
      </translate>
      <translate
        v-else-if="step === 3"
        translate-context="Popup/Channels/Title"
      >
        Upload details
      </translate>
      <translate
        v-else-if="step === 4"
        translate-context="Popup/Channels/Title"
      >
        Processing uploads
      </translate>
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
          <translate translate-context="Content/Library/Paragraph">
            Remaining storage space:
          </translate>
          {{ humanSize((statusData.quotaStatus.remaining - statusData.uploadedSize) * 1000 * 1000) }}
        </template>
      </div>
      <div class="ui hidden clearing divider mobile-only" />
      <button
        v-if="step === 1"
        class="ui basic cancel button"
      >
        <translate translate-context="*/*/Button.Label/Verb">
          Cancel
        </translate>
      </button>
      <button
        v-else-if="step < 3"
        class="ui basic button"
        @click.stop.prevent="uploadForm.step -= 1"
      >
        <translate translate-context="*/*/Button.Label/Verb">
          Previous step
        </translate>
      </button>
      <button
        v-else-if="step === 3"
        class="ui basic button"
        @click.stop.prevent="uploadForm.step -= 1"
      >
        <translate translate-context="*/*/Button.Label/Verb">
          Update
        </translate>
      </button>
      <button
        v-if="step === 1"
        class="ui primary button"
        @click.stop.prevent="uploadForm.step += 1"
      >
        <translate translate-context="*/*/Button.Label">
          Next step
        </translate>
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
          <translate translate-context="*/Channels/Button.Label">
            Publish
          </translate>
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
              <translate translate-context="Content/*/Button.Label/Verb">
                Finish later
              </translate>
            </div>
          </div>
        </button>
      </div>
      <button
        v-if="step === 4"
        class="ui basic cancel button"
        @click="update(false)"
      >
        <translate translate-context="*/*/Button.Label/Verb">
          Close
        </translate>
      </button>
    </div>
  </semantic-modal>
</template>
