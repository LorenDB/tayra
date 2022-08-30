<script setup lang="ts">
import type { BackendError, Channel } from '~/types'

import { computed, watch, ref } from 'vue'
import axios from 'axios'

interface Events {
  (e: 'submittable', value: boolean): void
  (e: 'loading', value: boolean): void
  (e: 'created'): void
}

interface Props {
  channel: Channel
}

const emit = defineEmits<Events>()
const props = defineProps<Props>()

const title = ref('')

const errors = ref([] as string[])
const isLoading = ref(false)
const submit = async () => {
  isLoading.value = true
  errors.value = []

  try {
    await axios.post('albums/', {
      title: title.value,
      artist: props.channel.artist?.id
    })

    emit('created')
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }

  isLoading.value = false
}

const submittable = computed(() => title.value.length > 0)
watch(submittable, (value) => emit('submittable', value))
watch(isLoading, (value) => emit('loading', value))

defineExpose({
  submit
})
</script>

<template>
  <form
    :class="['ui', {loading: isLoading}, 'form']"
    @submit.stop.prevent
  >
    <div
      v-if="errors.length > 0"
      role="alert"
      class="ui negative message"
    >
      <h4 class="header">
        <translate translate-context="Content/*/Error message.Title">
          Error while creating
        </translate>
      </h4>
      <ul class="list">
        <li
          v-for="(error, key) in errors"
          :key="key"
        >
          {{ error }}
        </li>
      </ul>
    </div>
    <div class="ui required field">
      <label for="album-title">
        <translate translate-context="*/*/*/Noun">Title</translate>
      </label>
      <input
        v-model="title"
        type="text"
      >
    </div>
  </form>
</template>
