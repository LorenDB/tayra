<template>
  <main
    v-title="labels.title"
    class="main pusher"
  >
    <nav
      class="ui secondary pointing menu"
      role="navigation"
      :aria-label="labels.secondaryMenu"
    >
      <router-link
        class="ui item"
        :to="{name: 'content.libraries.index'}"
      >
        <translate translate-context="*/*/*/Noun">
          Libraries
        </translate>
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'content.libraries.files'}"
      >
        <translate translate-context="*/*/*">
          Tracks
        </translate>
      </router-link>
    </nav>
    <router-view :key="$route.fullPath" />
  </main>
</template>
<script>
export default {
  computed: {
    labels () {
      const title = this.$pgettext('*/Library/*/Verb', 'Add content')
      const secondaryMenu = this.$pgettext('Menu/*/Hidden text', 'Secondary menu')
      return {
        title,
        secondaryMenu
      }
    }
  }
}
</script>
