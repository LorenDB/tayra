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
        <translate >
          Edits
        </translate>
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.channels'}"
      >
        <translate >
          Channels
        </translate>
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.library.artists'}"
      >
        <translate >
          Artists
        </translate>
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.library.albums'}"
      >
        <translate >
          Albums
        </translate>
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.library.tracks'}"
      >
        <translate >
          Tracks
        </translate>
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.library.libraries'}"
      >
        <translate >
          Libraries
        </translate>
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.library.uploads'}"
      >
        <translate >
          Uploads
        </translate>
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.library.tags'}"
      >
        <translate >
          Tags
        </translate>
      </router-link>
    </nav>
    <router-view :key="$route.fullPath" />
  </div>
</template>
