<script setup lang="ts">
import type { Application } from '~/types'

import { computed, reactive } from 'vue'
import { useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'

import { useStore } from '~/store'

import ApplicationForm from '~/components/auth/ApplicationForm.vue'

interface Props {
  name?: string
  scopes?: string
  redirectUris?: string
}

const props = withDefaults(defineProps<Props>(), {
  name: '',
  scopes: '',
  redirectUris: ''
})

const defaults = reactive({
  name: props.name,
  scopes: props.scopes,
  redirectUris: props.redirectUris
})

const { t } = useI18n()
const labels = computed(() => ({
  title: t('components.auth.ApplicationNew.title')
}))

const router = useRouter()
const store = useStore()

const created = (application: Application) => {
  store.state.auth.applicationSecret = application.client_secret
  console.log(application)
  return router.push({
    name: 'settings.applications.edit',
    params: {
      id: application.client_id
    }
  })
}
</script>

<template>
  <main
    v-title="labels.title"
    class="main pusher"
  >
    <div class="ui vertical stripe segment">
      <section class="ui text container">
        <router-link :to="{name: 'settings'}">
          {{ $t('components.auth.ApplicationNew.link.settings') }}
        </router-link>
        <h2 class="ui header">
          {{ labels.title }}
        </h2>
        <application-form
          :defaults="defaults"
          @created="created"
        />
      </section>
    </div>
  </main>
</template>
