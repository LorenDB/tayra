<script setup lang="ts">
import type { Upload } from '~/types'

import { ref, computed, watch } from 'vue'

import TagsSelector from '~/components/library/TagsSelector.vue'
import AttachmentInput from '~/components/common/AttachmentInput.vue'

interface Emits {
  // TODO (wvffle): Find correct type
  (e: 'values', values: Record<string, string>): void
}

interface Props {
  upload: Upload
  values?: Record<string, string> | null
}

const emit = defineEmits<Emits>()
const props = withDefaults(defineProps<Props>(), {
  values: null
})

// TODO (wvffle): This is something like a Track, but `cover` is a plain uuid
const newValues = ref({ ...(props.values ?? props.upload.import_metadata) } as any)

// computed: {
//   isLoading () {
//     return !!this.metadata
//   }
// },
const isLoading = computed(() => !props.upload)
watch(newValues, (values) => emit('values', values), { immediate: true })
</script>

<template>
  <div :class="['ui', {loading: isLoading}, 'form']">
    <div class="ui required field">
      <label for="upload-title">
        <translate translate-context="*/*/*/Noun">Title</translate>
      </label>
      <input
        v-model="newValues.title"
        type="text"
      >
    </div>
    <attachment-input
      v-model="newValues.cover"
      @delete="newValues.cover = null"
    >
      <translate translate-context="Content/Channel/*">
        Track Picture
      </translate>
    </attachment-input>
    <div class="ui small hidden divider" />
    <div class="ui two fields">
      <div class="ui field">
        <label for="upload-tags">
          <translate translate-context="*/*/*/Noun">Tags</translate>
        </label>
        <tags-selector
          id="upload-tags"
          v-model="newValues.tags"
          :required="false"
        />
      </div>
      <div class="ui field">
        <label for="upload-position">
          <translate translate-context="*/*/*/Short, Noun">Position</translate>
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
        <translate translate-context="*/*/*">Description</translate>
      </label>
      <content-form
        v-model="newValues.description"
        field-id="upload-description"
      />
    </div>
  </div>
</template>
