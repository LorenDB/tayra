<template>
  <span
    v-if="isLoading || isDone"
    class="feedback"
  >
    <span
      v-if="isLoading"
      :class="['ui', 'active', size, 'inline', 'loader']"
    />
    <i
      v-if="isDone"
      :class="['success', size, 'check', 'icon']"
    />
  </span>
</template>

<script>

export default {
  props: {
    isLoading: { type: Boolean, required: true },
    size: { type: String, default: 'small' }
  },
  data () {
    return {
      timer: null,
      isDone: false
    }
  },
  watch: {
    isLoading (v) {
      const self = this
      if (v && this.timer) {
        clearTimeout(this.timer)
      }
      if (v) {
        this.isDone = false
      } else {
        this.isDone = true
        this.timer = setTimeout(() => {
          self.isDone = false
        }, (2000))
      }
    }
  },
  destroyed () {
    if (this.timer) {
      clearTimeout(this.timer)
    }
  }
}
</script>
