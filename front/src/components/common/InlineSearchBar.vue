<script setup lang="ts">
import { useVModel } from '@vueuse/core'
import { computed } from 'vue'
import { useGettext } from 'vue3-gettext'

interface Props {
  modelValue: string
  placeholder?: string
}

const props = withDefaults(defineProps<Props>(), {
  placeholder: ''
})

const emit = defineEmits(['update:modelValue', 'search'])
const value = useVModel(props, 'modelValue', emit)

const { $pgettext } = useGettext()
const labels = computed(() => ({
  searchPlaceholder: $pgettext('Content/Search/Input.Placeholder', 'Search…'),
  clear: $pgettext('Content/Library/Button.Label', 'Clear')
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
        <translate translate-context="Content/Search/Input.Label/Noun">Search</translate>
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
