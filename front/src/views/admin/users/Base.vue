<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { computed } from 'vue'

const { t } = useI18n()

const labels = computed(() => ({
  manageUsers: t('Manage users'),
  secondaryMenu: t('Secondary menu')
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
        Users
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.users.invitations.list'}"
      >
        Invitations
      </router-link>
    </nav>
    <router-view :key="$route.fullPath" />
  </div>
</template>
