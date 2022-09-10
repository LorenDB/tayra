<script setup lang="ts">
import type { Upload, Track } from '~/types'

import { reactive, computed, watch } from 'vue'

import TagsSelector from '~/components/library/TagsSelector.vue'
import AttachmentInput from '~/components/common/AttachmentInput.vue'

type Values = Pick<Track, 'title' | 'description' | 'position' | 'tags'> & { cover: string }
interface Events {
  (e: 'update:values', values: Values): void
}

interface Props {
  upload: Upload
  values: Values | null
}

const emit = defineEmits<Events>()
const props = withDefaults(defineProps<Props>(), {
  values: null
})

const newValues = reactive<Values>({
  ...(props.values ?? props.upload.import_metadata ?? {}) as Values
})

const isLoading = computed(() => !props.upload)
watch(newValues, (values) => emit('update:values', values), { immediate: true })
</script>

<template>
  <div :class="['ui', {loading: isLoading}, 'form']">
    <div class="ui required field">
      <label for="upload-title">
        Title
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
      Track Picture
    </attachment-input>
    <div class="ui small hidden divider" />
    <div class="ui two fields">
      <div class="ui field">
        <label for="upload-tags">
          Tags
        </label>
        <tags-selector
          id="upload-tags"
          v-model="newValues.tags"
          :required="false"
        />
      </div>
      <div class="ui field">
        <label for="upload-position">
          Position
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
        Description
      </label>
      <content-form
        v-model="newValues.description"
        field-id="upload-description"
      />
    </div>
  </div>
</template>
