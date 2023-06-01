<script setup lang="ts">
import type { Upload, Track } from '~/types'

import { reactive, computed, watch } from 'vue'

import TagsSelector from '~/components/library/TagsSelector.vue'
import AttachmentInput from '~/components/common/AttachmentInput.vue'

type Values = Pick<Track, 'title' | 'position' | 'tags'> & { cover: string | null, description: string }
interface Events {
  (e: 'update:values', values: Values): void
}

interface Props {
  upload: Upload
  values: Partial<Values> | null
}

const emit = defineEmits<Events>()
const props = withDefaults(defineProps<Props>(), {
  values: null
})

const newValues = reactive<Values>({
  description: '',
  title: '',
  tags: [],
  cover: null,
  ...(props.values ?? props.upload.import_metadata ?? {})
})

const isLoading = computed(() => !props.upload)
watch(newValues, (values) => emit('update:values', values), { immediate: true })
</script>

<template>
  <div :class="['ui', {loading: isLoading}, 'form']">
    <div class="ui required field">
      <label for="upload-title">
        {{ $t('components.channels.UploadMetadataForm.label.title') }}
      </label>
      <input
        v-model="newValues.title"
        type="text"
      >
    </div>
    <attachment-input
      v-model="newValues.cover"
      @delete="newValues.cover = ''"
    >
      {{ $t('components.channels.UploadMetadataForm.label.image') }}
    </attachment-input>
    <div class="ui small hidden divider" />
    <div class="ui two fields">
      <div class="ui field">
        <label for="upload-tags">
          {{ $t('components.channels.UploadMetadataForm.label.tags') }}
        </label>
        <tags-selector
          id="upload-tags"
          v-model="newValues.tags"
          :required="false"
        />
      </div>
      <div class="ui field">
        <label for="upload-position">
          {{ $t('components.channels.UploadMetadataForm.label.position') }}
        </label>
        <input
          v-model="newValues.position"
          type="number"
          min="1"
          step="1"
        >
      </div>
    </div>
    <div class="ui field">
      <label for="upload-description">
        {{ $t('components.channels.UploadMetadataForm.label.description') }}
      </label>
      <content-form
        v-model="newValues.description"
        field-id="upload-description"
      />
    </div>
  </div>
</template>
