<script setup lang="ts">
import type { Channel } from '~/types'
import SemanticModal from '~/components/semantic/Modal.vue'
import ChannelAlbumForm from '~/components/channels/AlbumForm.vue'
import { watch, ref } from 'vue'

interface Props {
  channel: Channel
}

defineProps<Props>()

const isLoading = ref(false)
const submittable = ref(false)
const show = ref(false)

watch(show, () => {
  isLoading.value = false
  submittable.value = false
})

</script>

<template>
  <semantic-modal
    v-model:show="show"
    class="small"
  >
    <h4 class="header">
      <translate
        v-if="channel.content_category === 'podcasts'"
        translate-context="Popup/Channels/Title/Verb"
      >
        New series
      </translate>
      <translate
        v-else
        translate-context="Popup/Channels/Title"
      >
        New album
      </translate>
    </h4>
    <div class="scrolling content">
      <channel-album-form
        ref="albumForm"
        :channel="channel"
        @loading="isLoading = $event"
        @submittable="submittable = $event"
        @created="$emit('created', $event)"
      />
    </div>
    <div class="actions">
      <button class="ui basic cancel button">
        <translate translate-context="*/*/Button.Label/Verb">
          Cancel
        </translate>
      </button>
      <button
        :class="['ui', 'primary', {loading: isLoading}, 'button']"
        :disabled="!submittable"
        @click.stop.prevent="$refs.albumForm.submit()"
      >
        <translate translate-context="*/*/Button.Label">
          Create
        </translate>
      </button>
    </div>
  </semantic-modal>
</template>
