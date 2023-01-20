<script setup lang="ts">
import type { Channel } from '~/types'
import SemanticModal from '~/components/semantic/Modal.vue'
import ChannelAlbumForm from '~/components/channels/AlbumForm.vue'
import { watch, ref } from 'vue'

interface Events {
  (e: 'created'): void
}

interface Props {
  channel: Channel
}

const emit = defineEmits<Events>()
defineProps<Props>()

const isLoading = ref(false)
const submittable = ref(false)
const show = ref(false)

watch(show, () => {
  isLoading.value = false
  submittable.value = false
})

const albumForm = ref()
defineExpose({
  show
})
</script>

<template>
  <semantic-modal
    v-model:show="show"
    class="small"
  >
    <h4 class="header">
      <span v-if="channel.content_category === 'podcast'">
        {{ $t('components.channels.AlbumModal.header.newSeries') }}
      </span>
      <span v-else>
        {{ $t('components.channels.AlbumModal.header.newAlbum') }}
      </span>
    </h4>
    <div class="scrolling content">
      <channel-album-form
        ref="albumForm"
        :channel="channel"
        @loading="isLoading = $event"
        @submittable="submittable = $event"
        @created="emit('created')"
      />
    </div>
    <div class="actions">
      <button class="ui basic cancel button">
        {{ $t('components.channels.AlbumModal.button.cancel') }}
      </button>
      <button
        :class="['ui', 'primary', {loading: isLoading}, 'button']"
        :disabled="!submittable"
        @click.stop.prevent="albumForm.submit()"
      >
        {{ $t('components.channels.AlbumModal.button.create') }}
      </button>
    </div>
  </semantic-modal>
</template>
