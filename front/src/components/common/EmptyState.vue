<script setup lang="ts">
interface Props {
  refresh?: boolean
}

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
          <translate translate-context="Content/*/Paragraph">
            No results were found.
          </translate>
        </slot>
      </div>
    </h4>
    <div class="inline center aligned text">
      <slot />
      <button
        v-if="refresh"
        class="ui button"
        @click="$emit('refresh')"
      >
        <translate translate-context="Content/*/Button.Label/Short, Verb">
          Refresh
        </translate>
      </button>
    </div>
  </div>
</template>