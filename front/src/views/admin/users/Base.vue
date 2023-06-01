<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { computed } from 'vue'

const { t } = useI18n()

const labels = computed(() => ({
  manageUsers: t('views.admin.users.Base.title'),
  secondaryMenu: t('views.admin.users.Base.menu.secondary')
}))
</script>

<template>
  <div
    v-title="labels.manageUsers"
    class="main pusher"
  >
    <nav
      class="ui secondary pointing menu"
      role="navigation"
      :aria-label="labels.secondaryMenu"
    >
      <router-link
        class="ui item"
        :to="{name: 'manage.users.users.list'}"
      >
        {{ $t('views.admin.users.Base.link.users') }}
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.users.invitations.list'}"
      >
        {{ $t('views.admin.users.Base.link.invitations') }}
      </router-link>
    </nav>
    <router-view :key="$route.fullPath" />
  </div>
</template>
