<template>
  <div class="ui toast-container">
    <message
      v-for="message in $store.state.ui.messages"
      :key="message.key"
      :message="message"
    />
    <slot />
  </div>
</template>

<script>

export default {}
</script>
