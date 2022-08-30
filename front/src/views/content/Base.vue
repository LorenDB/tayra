<script setup lang="ts">
import { useGettext } from 'vue3-gettext'
import { computed } from 'vue'

const { $pgettext } = useGettext()

const labels = computed(() => ({
  secondaryMenu: $pgettext('Menu/*/Hidden text', 'Secondary menu'),
  title: $pgettext('*/Library/*/Verb', 'Add content')
}))
</script>

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
