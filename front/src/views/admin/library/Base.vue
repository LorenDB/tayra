<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'

const { t } = useI18n()
const labels = computed(() => ({
  title: t('views.admin.library.Base.title'),
  secondaryMenu: t('views.admin.library.Base.menu.secondary')
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
        {{ $t('views.admin.library.Base.link.edits') }}
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.channels'}"
      >
        {{ $t('views.admin.library.Base.link.channels') }}
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.library.artists'}"
      >
        {{ $t('views.admin.library.Base.link.artists') }}
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.library.albums'}"
      >
        {{ $t('views.admin.library.Base.link.albums') }}
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.library.tracks'}"
      >
        {{ $t('views.admin.library.Base.link.tracks') }}
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.library.libraries'}"
      >
        {{ $t('views.admin.library.Base.link.libraries') }}
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.library.uploads'}"
      >
        {{ $t('views.admin.library.Base.link.uploads') }}
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.library.tags'}"
      >
        {{ $t('views.admin.library.Base.link.tags') }}
      </router-link>
    </nav>
    <router-view :key="$route.fullPath" />
  </div>
</template>
