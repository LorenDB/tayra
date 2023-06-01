<script setup lang="ts">
import type { Album, Channel } from '~/types'

import axios from 'axios'
import { useVModel } from '@vueuse/core'
import { reactive, ref, watch } from 'vue'

interface Events {
  (e: 'update:modelValue', value: string): void
}

interface Props {
  modelValue: string | null
  channel: Channel | null
}

const emit = defineEmits<Events>()
const props = withDefaults(defineProps<Props>(), {
  modelValue: null,
  channel: null
})

const value = useVModel(props, 'modelValue', emit)

const albums = reactive<Album[]>([])

const isLoading = ref(false)
const fetchData = async () => {
  albums.length = 0
  if (!props.channel?.artist) return

  isLoading.value = true
  const response = await axios.get('albums/', {
    params: {
      artist: props.channel?.artist.id,
      include_channels: 'true'
    }
  })

  albums.push(...response.data.results)
  isLoading.value = false
}

watch(() => props.channel, fetchData, { immediate: true })
</script>

<template>
  <div>
    <label for="album-dropdown">
      <span v-if="channel && channel.artist && channel.artist.content_category === 'podcast'">
        {{ $t('components.channels.AlbumSelect.label.series') }}
      </span>
      <span v-else>
        {{ $t('components.channels.AlbumSelect.label.album') }}
      </span>
    </label>
    <select
      id="album-dropdown"
      v-model="value"
      class="ui search normal dropdown"
    >
      <option value="">
        {{ $t('components.channels.AlbumSelect.option.none') }}
      </option>
      <option
        v-for="album in albums"
        :key="album.id"
        :value="album.id"
      >
        {{ album.title }}
        <span>
          {{ $t('components.channels.AlbumSelect.meta.tracks', album.tracks_count) }}
        </span>
      </option>
    </select>
  </div>
</template>
