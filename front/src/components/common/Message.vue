<template>
  <div />
</template>
<script>
import $ from 'jquery'

export default {
  props: { message: { type: Object, required: true } },
  mounted () {
    const self = this
    const params = {
      context: '#app',
      message: this.message.content,
      showProgress: 'top',
      position: 'bottom right',
      progressUp: true,
      onRemove () {
        self.$store.commit('ui/removeMessage', self.message.key)
      },
      ...this.message
    }
    $('body').toast(params)

    $('.ui.toast.visible').last().attr('role', 'alert')
  }
}
</script>
