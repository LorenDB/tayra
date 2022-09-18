<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'

const { t } = useI18n()
const labels = computed(() => ({
  title: t('views.admin.library.Base.title'),
  secondaryMenu: t('views.admin.library.Base.secondaryMenu')
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
        {{ $t('views.admin.library.Base.editsLink') }}
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.channels'}"
      >
        {{ $t('views.admin.library.Base.channelsLink') }}
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.library.artists'}"
      >
        {{ $t('views.admin.library.Base.artistsLink') }}
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.library.albums'}"
      >
        {{ $t('views.admin.library.Base.albumsLink') }}
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.library.tracks'}"
      >
        {{ $t('views.admin.library.Base.tracksLink') }}
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.library.libraries'}"
      >
        {{ $t('views.admin.library.Base.librariesLink') }}
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.library.uploads'}"
      >
        {{ $t('views.admin.library.Base.uploadsLink') }}
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.library.tags'}"
      >
        {{ $t('views.admin.library.Base.tagsLink') }}
      </router-link>
    </nav>
    <router-view :key="$route.fullPath" />
  </div>
</template>
