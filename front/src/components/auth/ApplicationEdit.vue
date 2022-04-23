<template>
  <main
    v-title="labels.title"
    class="main pusher"
  >
    <div class="ui vertical stripe segment">
      <section class="ui text container">
        <div
          v-if="isLoading"
          class="ui inverted active dimmer"
        >
          <div class="ui loader" />
        </div>
        <template v-else>
          <router-link :to="{name: 'settings'}">
            <translate translate-context="Content/Applications/Link">
              Back to settings
            </translate>
          </router-link>
          <h2 class="ui header">
            <translate translate-context="Content/Applications/Title">
              Application details
            </translate>
          </h2>
          <div class="ui form">
            <p>
              <translate translate-context="Content/Application/Paragraph/">
                Application ID and secret are really sensitive values and must be treated like passwords. Do not share those with anyone else.
              </translate>
            </p>
            <div class="field">
              <label for="copy-id"><translate translate-context="Content/Applications/Label">Application ID</translate></label>
              <copy-input
                id="copy-id"
                :value="application.client_id"
              />
            </div>
            <div class="field">
              <label for="copy-secret"><translate translate-context="Content/Applications/Label">Application secret</translate></label>
              <copy-input
                id="copy-secret"
                :value="application.client_secret"
              />
            </div>
            <div
              v-if="application.token != undefined"
              class="field"
            >
              <label for="copy-secret"><translate translate-context="Content/Applications/Label">Access token</translate></label>
              <copy-input
                id="copy-secret"
                :value="application.token"
              />
              <a
                href=""
                @click.prevent="refreshToken"
              >
                <i class="refresh icon" />
                <translate translate-context="Content/Applications/Label">Regenerate token</translate>
              </a>
            </div>
          </div>
          <h2 class="ui header">
            <translate translate-context="Content/Applications/Title">
              Edit application
            </translate>
          </h2>
          <application-form
            :app="application"
            @updated="application = $event"
          />
        </template>
      </section>
    </div>
  </main>
</template>

<script>
import axios from 'axios'

import ApplicationForm from '~/components/auth/ApplicationForm.vue'

export default {
  components: {
    ApplicationForm
  },
  props: { id: { type: Number, required: true } },
  data () {
    return {
      application: null,
      isLoading: false
    }
  },
  computed: {
    labels () {
      return {
        title: this.$pgettext('Content/Applications/Title', 'Edit application')
      }
    }
  },
  created () {
    this.fetchApplication()
  },
  methods: {
    fetchApplication () {
      this.isLoading = true
      const self = this
      axios.get(`oauth/apps/${this.id}/`).then((response) => {
        self.isLoading = false
        self.application = response.data
      }, error => {
        self.isLoading = false
        self.errors = error.backendErrors
      })
    },
    async refreshToken () {
      self.isLoading = true
      const response = await axios.post(`oauth/apps/${this.id}/refresh-token`)
      this.application = response.data
      self.isLoading = false
    }
  }
}
</script>
