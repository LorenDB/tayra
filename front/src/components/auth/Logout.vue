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
          <translate >
            Are you sure you want to log out?
          </translate>
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
          <translate >
            Yes, log me out!
          </translate>
        </button>
      </div>
      <div
        v-else
        class="ui small text container"
      >
        <h2>
          <translate >
            You aren't currently logged in
          </translate>
        </h2>
        <router-link
          to="/login"
          class="ui button"
        >
          <translate >
            Log in!
          </translate>
        </router-link>
      </div>
    </section>
  </main>
</template>
