<script setup lang="ts">
import type { RouteLocationRaw } from 'vue-router'

import LoginForm from '~/components/auth/LoginForm.vue'
import { useRouter } from 'vue-router'
import { computed } from 'vue'
import { useGettext } from 'vue3-gettext'
import { useStore } from '~/store'
import { whenever } from '@vueuse/core'

interface Props {
  next?: RouteLocationRaw
}

const props = withDefaults(defineProps<Props>(), {
  next: '/library'
})

const { $pgettext } = useGettext()
const labels = computed(() => ({
  title: $pgettext('Head/Login/Title', 'Log In')
}))

const store = useStore()
const router = useRouter()
whenever(() => store.state.auth.authenticated, () => {
  const resolved = router.resolve(props.next)
  router.push(resolved.name === '404' ? '/library' : props.next)
})
</script>

<template>
  <main
    v-title="labels.title"
    class="main pusher"
  >
    <section class="ui vertical stripe segment">
      <div class="ui small text container">
        <h2>
          <translate translate-context="Content/Login/Title/Verb">
            Log in to your Funkwhale account
          </translate>
        </h2>
        <login-form :next="next" />
      </div>
    </section>
  </main>
</template>
