<template>
  <div :class="['ui', {loading}, 'segment']">
    <div class="ui fluid action input">
      <input
        class="ui disabled"
        disabled
        :value="data.root + '/' + value.join('/')"
      >
      <button
        class="ui button"
        @click.prevent="$emit('import')"
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
        @click.prevent="handleClick({name: '..', dir: true})"
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
<script>
export default {
  props: {
    data: { type: Object, required: true },
    loading: { type: Boolean, required: true },
    value: { type: Array, required: true }
  },
  methods: {
    handleClick (element) {
      if (!element.dir) {
        return
      }
      if (element.name === '..') {
        const newValue = [...this.value]
        newValue.pop()
        this.$emit('input', newValue)
      } else {
        this.$emit('input', [...this.value, element.name])
      }
    }
  }
}
</script>
