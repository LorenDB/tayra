<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'

const { t } = useI18n()
const labels = computed(() => ({
  title: t('Log Out')
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
          Are you sure you want to log out?
        </h2>
        <p
          v-translate="{username: $store.state.auth.username}"
        >
          You are currently logged in as %{ username }
        </p>
        <button
          class="ui button"
          @click="$store.dispatch('auth/logout')"
        >
          Yes, log me out!
        </button>
      </div>
      <div
        v-else
        class="ui small text container"
      >
        <h2>
          You aren't currently logged in
        </h2>
        <router-link
          to="/login"
          class="ui button"
        >
          Log in!
        </router-link>
      </div>
    </section>
  </main>
</template>
