<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'

const { t } = useI18n()
const labels = computed(() => ({
  title: t('components.auth.Logout.title')
}))
</script>

<template>
  <main
    v-title="labels.title"
    class="main pusher"
  >
    <section class="ui vertical stripe segment">
      <div
        v-if="$store.state.auth.authenticated"
        class="ui small text container"
      >
        <h2>
          {{ $t('components.auth.Logout.confirmHeader') }}
        </h2>
        <p>
          {{ $t('components.auth.Logout.loggedInUsername', { username: $store.state.auth.username }) }}
        </p>
        <button
          class="ui button"
          @click="$store.dispatch('auth/logout')"
        >
          {{ $t('components.auth.Logout.confirmLogoutButton') }}
        </button>
      </div>
      <div
        v-else
        class="ui small text container"
      >
        <h2>
          {{ $t('components.auth.Logout.loggedOutHeader') }}
        </h2>
        <router-link
          to="/login"
          class="ui button"
        >
          {{ $t('components.auth.Logout.logInLink') }}
        </router-link>
      </div>
    </section>
  </main>
</template>
