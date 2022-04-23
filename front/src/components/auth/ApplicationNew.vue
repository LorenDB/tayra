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

<script>
import ApplicationForm from '~/components/auth/ApplicationForm.vue'

export default {
  components: {
    ApplicationForm
  },
  props: {
    name: { type: String, default: '' },
    redirectUris: { type: String, default: '' },
    scopes: { type: String, default: '' }
  },
  data () {
    return {
      application: null,
      isLoading: false,
      defaults: {
        name: this.name,
        redirectUris: this.redirectUris,
        scopes: this.scopes
      }
    }
  },
  computed: {
    labels () {
      return {
        title: this.$pgettext('Content/Settings/Button.Label', 'Create a new application')
      }
    }
  }
}
</script>
