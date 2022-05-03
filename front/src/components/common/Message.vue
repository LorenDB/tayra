<script setup lang="ts">
import $ from 'jquery'
import { onMounted } from 'vue'
import { useStore } from '~/store'

interface Message {
  content: string
  key: string
}

const props = defineProps<{ message: Message }>()

const store = useStore()
onMounted(() => {
  const params = {
    context: '#app',
    message: props.message.content,
    showProgress: 'top',
    position: 'bottom right',
    progressUp: true,
    onRemove () {
      store.commit('ui/removeMessage', props.message.key)
    },
    ...props.message
  }

  // @ts-expect-error toast is from semantic ui
  $('body').toast(params)
  $('.ui.toast.visible').last().attr('role', 'alert')
})
</script>

<template>
  <div />
</template>
