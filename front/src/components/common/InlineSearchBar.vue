<script setup lang="ts">
import { useVModel } from '@vueuse/core'
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'

interface Events {
  (e: 'update:modelValue', value: string): void
  (e: 'search', query: string): void
}

interface Props {
  modelValue: string
  placeholder?: string
}

const emit = defineEmits<Events>()
const props = withDefaults(defineProps<Props>(), {
  placeholder: ''
})

const value = useVModel(props, 'modelValue', emit)

const { t } = useI18n()
const labels = computed(() => ({
  searchPlaceholder: t('components.common.InlineSearchBar.placeholder.search'),
  clear: t('components.common.InlineSearchBar.button.clear')
}))

const search = () => {
  value.value = ''
  emit('search', value.value)
}
</script>

<template>
  <form
    class="ui inline form"
    @submit.stop.prevent="emit('search', value)"
  >
    <div :class="['ui', 'action', {icon: value}, 'input']">
      <label
        for="search-query"
        class="hidden"
      >
        {{ $t('components.common.InlineSearchBar.label.search') }}
      </label>
      <input
        id="search-query"
        v-model="value"
        name="search-query"
        type="text"
        :placeholder="placeholder || labels.searchPlaceholder"
      >
      <i
        v-if="value"
        class="x link icon"
        :title="labels.clear"
        @click.stop.prevent="search"
      />
      <button
        type="submit"
        class="ui icon basic button"
      >
        <i class="search icon" />
      </button>
    </div>
  </form>
</template>
