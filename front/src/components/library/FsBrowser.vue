<script setup lang="ts">
import type { FileSystem, FSEntry } from '~/types'

import { useVModel } from '@vueuse/core'

interface Props {
  data: FileSystem
  loading: boolean
  modelValue: string[]
}

const props = defineProps<Props>()
const emit = defineEmits(['update:modelValue', 'import'])

const value = useVModel(props, 'modelValue', emit)
const handleClick = (entry: FSEntry) => {
  if (!entry.dir) return

  if (entry.name === '..') {
    value.value.pop()
    return
  }

  value.value.push(entry.name)
}
</script>

<template>
  <div :class="['ui', { loading }, 'segment']">
    <div class="ui fluid action input">
      <input
        class="ui disabled"
        disabled
        :value="props.data.root + '/' + value.join('/')"
      >
      <button
        class="ui button"
        @click.prevent="emit('import')"
      >
        <translate translate-context="Content/Library/Button/Verb">
          Import
        </translate>
      </button>
    </div>
    <div class="ui list component-fs-browser">
      <a
        v-if="value.length > 0"
        class="item"
        href=""
        @click.prevent="handleClick({ name: '..', dir: true })"
      >
        <i class="folder icon" />
        <div class="content">
          <div class="header">..</div>
        </div>
      </a>
      <a
        v-for="e in data.content"
        :key="e.name"
        class="item"
        href=""
        @click.prevent="handleClick(e)"
      >
        <i
          v-if="e.dir"
          class="folder icon"
        />
        <i
          v-else
          class="file icon"
        />
        <div class="content">
          <div class="header">{{ e.name }}</div>
        </div>
      </a>
    </div>
  </div>
</template>
