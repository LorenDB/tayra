<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { computed } from 'vue'

const { t } = useI18n()

const labels = computed(() => ({
  secondaryMenu: t('views.content.Base.menu.secondary'),
  title: t('views.content.Base.title')
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
        {{ $t('views.content.Base.link.libraries') }}
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'content.libraries.files'}"
      >
        {{ $t('views.content.Base.link.tracks') }}
      </router-link>
    </nav>
    <router-view :key="$route.fullPath" />
  </main>
</template>
