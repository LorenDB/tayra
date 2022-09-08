<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { computed } from 'vue'

const { t } = useI18n()

const labels = computed(() => ({
  secondaryMenu: t('Secondary menu'),
  title: t('Add content')
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
        <translate >
          Libraries
        </translate>
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'content.libraries.files'}"
      >
        <translate >
          Tracks
        </translate>
      </router-link>
    </nav>
    <router-view :key="$route.fullPath" />
  </main>
</template>
