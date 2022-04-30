<template>
  <div class="main pusher page-library">
    <router-view :key="$router.currentRoute.value.fullPath" />
  </div>
</template>

<script>
export default {
  computed: {
    showImports () {
      return (
        this.$store.state.auth.availablePermissions.upload ||
        this.$store.state.auth.availablePermissions.library
      )
    },
    labels () {
      return {
        secondaryMenu: this.$pgettext('Menu/*/Hidden text', 'Secondary menu')
      }
    }
  }
}
</script>
