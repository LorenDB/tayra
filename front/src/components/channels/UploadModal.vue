<template>
  <modal
    v-model:show="$store.state.channels.showUploadModal"
    class="small"
  >
    <h4 class="header">
      <translate
        v-if="step === 1"
        key="1"
        translate-context="Popup/Channels/Title/Verb"
      >
        Publish audio
      </translate>
      <translate
        v-else-if="step === 2"
        key="2"
        translate-context="Popup/Channels/Title"
      >
        Files to upload
      </translate>
      <translate
        v-else-if="step === 3"
        key="3"
        translate-context="Popup/Channels/Title"
      >
        Upload details
      </translate>
      <translate
        v-else-if="step === 4"
        key="4"
        translate-context="Popup/Channels/Title"
      >
        Processing uploads
      </translate>
    </h4>
    <div class="scrolling content">
      <channel-upload-form
        ref="uploadForm"
        :channel="$store.state.channels.uploadModalConfig.channel"
        @step="step = $event"
        @loading="isLoading = $event"
        @published="$store.commit('channels/publish', $event)"
        @status="statusData = $event"
        @submittable="submittable = $event"
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
          {{ (statusData.quotaStatus.remaining * 1000 * 1000) - humanSize(statusData.uploadedSize) }}
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
        @click.stop.prevent="$refs.uploadForm.step -= 1"
      >
        <translate translate-context="*/*/Button.Label/Verb">
          Previous step
        </translate>
      </button>
      <button
        v-else-if="step === 3"
        class="ui basic button"
        @click.stop.prevent="$refs.uploadForm.step -= 1"
      >
        <translate translate-context="*/*/Button.Label/Verb">
          Update
        </translate>
      </button>
      <button
        v-if="step === 1"
        class="ui primary button"
        @click.stop.prevent="$refs.uploadForm.step += 1"
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
          :disabled="!statusData || !statusData.canSubmit"
          @click.prevent.stop="$refs.uploadForm.publish"
        >
          <translate translate-context="*/Channels/Button.Label">
            Publish
          </translate>
        </button>
        <button
          ref="dropdown"
          v-dropdown
          class="ui floating dropdown icon button"
          :disabled="!statusData || !statusData.canSubmit"
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
  </modal>
</template>

<script>
import Modal from '~/components/semantic/Modal.vue'
import ChannelUploadForm from '~/components/channels/UploadForm.vue'
import { humanSize } from '~/utils/filters'
import { onBeforeRouteLeave, onBeforeRouteUpdate } from 'vue-router'

export default {
  components: {
    Modal,
    ChannelUploadForm
  },
  setup () {
    const guard = () => {
      this.$store.commit('channels/showUploadModal', { show: false })
    }

    onBeforeRouteUpdate(guard)
    onBeforeRouteLeave(guard)

    return { humanSize }
  },
  data () {
    return {
      step: 1,
      isLoading: false,
      submittable: true,
      statusData: null
    }
  },
  computed: {
    labels () {
      return {}
    },
    statusInfo () {
      if (!this.statusData) {
        return []
      }
      const info = []
      if (this.statusData.totalSize) {
        info.push(humanSize(this.statusData.totalSize))
      }
      if (this.statusData.totalFiles) {
        const msg = this.$npgettext('*/*/*', '%{ count } file', '%{ count } files', this.statusData.totalFiles)
        info.push(
          this.$gettextInterpolate(msg, { count: this.statusData.totalFiles })
        )
      }
      if (this.statusData.progress) {
        info.push(`${this.statusData.progress}%`)
      }
      if (this.statusData.speed) {
        info.push(`${humanSize(this.statusData.speed)}/s`)
      }
      return info
    }
  },
  methods: {
    update (v) {
      this.$store.commit('channels/showUploadModal', { show: v })
    }
  }
}
</script>
