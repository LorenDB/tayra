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
    <template
      v-for="(row, idx) in data.logs"
      v-else
      :key="idx"
    >
      <p>
        {{ row }}
      </p>
    </template>
  </div>
</template>
<script>
export default {
  props: { data: { type: Object, required: true } }
}
</script>
