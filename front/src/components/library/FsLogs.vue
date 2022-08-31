<script setup lang="ts">
import type { FSLogs } from '~/types'

interface Props {
  data: FSLogs
}

defineProps<Props>()
</script>

<template>
  <div class="ui segment component-fs-logs">
    <div
      v-if="data.status === 'pending'"
      class="ui active dimmer"
    >
      <div class="ui text loader">
        <translate translate-context="Content/Library/Paragraph">
          Import hasn't started yet
        </translate>
      </div>
    </div>
    <template v-else>
      <p
        v-for="row in data.logs"
        :key="row"
      >
        {{ row }}
      </p>
    </template>
  </div>
</template>
