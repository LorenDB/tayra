<script setup lang="ts">
interface Events {
  (e: 'refresh'): void
}

interface Props {
  refresh?: boolean
}

const emit = defineEmits<Events>()
withDefaults(defineProps<Props>(), {
  refresh: false
})
</script>

<template>
  <div class="ui small placeholder segment component-placeholder component-empty-state">
    <h4 class="ui header">
      <div class="content">
        <slot name="title">
          <i class="search icon" />
          {{ $t('components.common.EmptyState.header.noResults') }}
        </slot>
      </div>
    </h4>
    <div class="inline center aligned text">
      <slot />
      <button
        v-if="refresh"
        class="ui button"
        @click="emit('refresh')"
      >
        {{ $t('components.common.EmptyState.button.refresh') }}
      </button>
    </div>
  </div>
</template>
