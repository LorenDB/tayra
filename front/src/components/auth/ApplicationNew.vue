<script setup lang="ts">
import ApplicationForm from '~/components/auth/ApplicationForm.vue'
import { computed, reactive } from 'vue'
import { useGettext } from 'vue3-gettext'
import { useRouter } from 'vue-router'
import type { Application } from '~/types'
import { useStore } from '~/store'

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

const { $pgettext } = useGettext()
const labels = computed(() => ({
  title: $pgettext('Content/Settings/Button.Label', 'Create a new application')
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
          <translate translate-context="Content/Applications/Link">
            Back to settings
          </translate>
        </router-link>
        <h2 class="ui header">
          <translate translate-context="Content/Settings/Button.Label">
            Create a new application
          </translate>
        </h2>
        <application-form
          :defaults="defaults"
          @created="created"
        />
      </section>
    </div>
  </main>
</template>
