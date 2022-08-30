<script setup lang="ts">
import type { RouteLocationRaw } from 'vue-router'

import { useGettext } from 'vue3-gettext'
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

const { $pgettext } = useGettext()

const labels = computed(() => ({
  title: $pgettext('*/Signup/Title', 'Sign Up')
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
          <translate translate-context="Content/Signup/Title">
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
