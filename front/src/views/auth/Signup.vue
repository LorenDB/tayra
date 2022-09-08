<script setup lang="ts">
import type { RouteLocationRaw } from 'vue-router'

import { useI18n } from 'vue-i18n'
import { computed } from 'vue'

import SignupForm from '~/components/auth/SignupForm.vue'

interface Props {
  defaultInvitation?: string
  next?: RouteLocationRaw
}

withDefaults(defineProps<Props>(), {
  defaultInvitation: undefined,
  next: '/'
})

const { t } = useI18n()

const labels = computed(() => ({
  title: t('Sign Up')
}))
</script>

<template>
  <main
    v-title="labels.title"
    class="main pusher"
  >
    <section class="ui vertical stripe segment">
      <div class="ui small text container">
        <h2>
          <translate >
            Create a Funkwhale account
          </translate>
        </h2>
        <signup-form
          :default-invitation="defaultInvitation"
          :next="next"
        />
      </div>
    </section>
  </main>
</template>
