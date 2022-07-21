<script setup lang="ts">
import ApplicationForm from '~/components/auth/ApplicationForm.vue'
import { computed, reactive } from 'vue'
import { useGettext } from 'vue3-gettext'

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
          @created="$router.push({name: 'settings.applications.edit', params: {id: $event.client_id}})"
        />
      </section>
    </div>
  </main>
</template>
