<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'

const { t } = useI18n()
const labels = computed(() => ({
  title: t('Manage library'),
  secondaryMenu: t('Secondary menu')
}))
</script>

<template>
  <div
    v-title="labels.title"
    class="main pusher page-admin-library"
  >
    <nav
      class="ui secondary pointing menu"
      role="navigation"
      :aria-label="labels.secondaryMenu"
    >
      <router-link
        class="ui item"
        :to="{name: 'manage.library.edits'}"
      >
        Edits
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.channels'}"
      >
        Channels
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.library.artists'}"
      >
        Artists
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.library.albums'}"
      >
        Albums
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.library.tracks'}"
      >
        Tracks
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.library.libraries'}"
      >
        Libraries
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.library.uploads'}"
      >
        Uploads
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.library.tags'}"
      >
        Tags
      </router-link>
    </nav>
    <router-view :key="$route.fullPath" />
  </div>
</template>
