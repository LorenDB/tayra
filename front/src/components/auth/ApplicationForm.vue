<template>
  <form
    class="ui form component-form"
    role="alert"
    @submit.prevent="submit()"
  >
    <div
      v-if="errors.length > 0"
      class="ui negative message"
    >
      <h4 class="header">
        <translate translate-context="Content/*/Error message.Title">
          We cannot save your changes
        </translate>
      </h4>
      <ul class="list">
        <li
          v-for="(error, key) in errors"
          :key="key"
        >
          {{ error }}
        </li>
      </ul>
    </div>
    <div class="ui field">
      <label for="application-name"><translate translate-context="*/*/*/Noun">Name</translate></label>
      <input
        id="application-name"
        v-model="fields.name"
        name="name"
        required
        type="text"
      >
    </div>
    <div class="ui field">
      <label for="redirect-uris"><translate translate-context="Content/Applications/Input.Label/Noun">Redirect URI</translate></label>
      <input
        id="redirect-uris"
        v-model="fields.redirect_uris"
        name="redirect_uris"
        type="text"
      >
      <p class="help">
        <translate translate-context="Content/Applications/Help Text">
          Use "urn:ietf:wg:oauth:2.0:oob" as a redirect URI if your application is not served on the web.
        </translate>
      </p>
    </div>
    <div class="ui field">
      <label><translate translate-context="Content/*/*/Noun">Scopes</translate></label>
      <p>
        <translate translate-context="Content/Applications/Paragraph/">
          Checking the parent "Read" or "Write" scopes implies access to all the corresponding children scopes.
        </translate>
      </p>
      <div class="ui stackable two column grid">
        <div
          v-for="(parent, key) in allScopes"
          :key="key"
          class="column"
        >
          <div class="ui parent checkbox">
            <input
              :id="parent.id"
              v-model="scopeArray"
              :value="parent.id"
              type="checkbox"
            >
            <label :for="parent.id">
              {{ parent.label }}
              <p class="help">
                {{ parent.description }}
              </p>
            </label>
          </div>

          <div
            v-for="(child, index) in parent.children"
            :key="index"
          >
            <div class="ui child checkbox">
              <input
                :id="child.id"
                v-model="scopeArray"
                :value="child.id"
                type="checkbox"
              >
              <label :for="child.id">
                {{ child.id }}
                <p class="help">
                  {{ child.description }}
                </p>
              </label>
            </div>
          </div>
        </div>
      </div>
    </div>
    <button
      :class="['ui', {'loading': isLoading}, 'success', 'button']"
      type="submit"
    >
      <translate
        v-if="updating"
        key="2"
        translate-context="Content/Applications/Button.Label/Verb"
      >
        Update application
      </translate>
      <translate
        v-else
        key="3"
        translate-context="Content/Applications/Button.Label/Verb"
      >
        Create application
      </translate>
    </button>
  </form>
</template>

<script>
import { uniq } from 'lodash-es'
import axios from 'axios'
import TranslationsMixin from '@/components/mixins/Translations.vue'

export default {
  mixins: [TranslationsMixin],
  props: {
    app: { type: Object, required: false, default: () => { return null } },
    defaults: { type: Object, required: false, default: () => { return {} } }
  },
  data () {
    const defaults = this.defaults || {}
    const app = this.app || {}
    return {
      isLoading: false,
      errors: [],
      fields: {
        name: app.name || defaults.name || '',
        redirect_uris: app.redirect_uris || defaults.redirect_uris || 'urn:ietf:wg:oauth:2.0:oob',
        scopes: app.scopes || defaults.scopes || 'read'
      },
      scopes: [
        { id: 'profile', icon: 'user' },
        { id: 'libraries', icon: 'book' },
        { id: 'favorites', icon: 'heart' },
        { id: 'listenings', icon: 'music' },
        { id: 'follows', icon: 'users' },
        { id: 'playlists', icon: 'list' },
        { id: 'radios', icon: 'rss' },
        { id: 'filters', icon: 'eye slash' },
        { id: 'notifications', icon: 'bell' },
        { id: 'edits', icon: 'pencil alternate' }
      ]
    }
  },
  computed: {
    updating () {
      return this.app
    },
    scopeArray: {
      get () {
        return this.fields.scopes.split(' ')
      },
      set (v) {
        this.fields.scopes = uniq(v).join(' ')
      }
    },
    allScopes () {
      const self = this
      const parents = [
        {
          id: 'read',
          label: this.$pgettext('Content/OAuth Scopes/Label/Verb', 'Read'),
          description: this.$pgettext('Content/OAuth Scopes/Help Text', 'Read-only access to user data'),
          value: this.scopeArray.indexOf('read') > -1
        },
        {
          id: 'write',
          label: this.$pgettext('Content/OAuth Scopes/Label/Verb', 'Write'),
          description: this.$pgettext('Content/OAuth Scopes/Help Text', 'Write-only access to user data'),
          value: this.scopeArray.indexOf('write') > -1
        }
      ]
      parents.forEach((p) => {
        p.children = self.scopes.map(s => {
          const id = `${p.id}:${s.id}`
          return {
            id,
            value: this.scopeArray.indexOf(id) > -1
          }
        })
      })
      return parents
    }
  },
  methods: {
    submit () {
      this.errors = []
      const self = this
      self.isLoading = true
      const payload = this.fields
      let event, promise
      if (this.updating) {
        event = 'updated'
        promise = axios.patch(`oauth/apps/${this.app.client_id}/`, payload)
      } else {
        event = 'created'
        promise = axios.post('oauth/apps/', payload)
      }
      return promise.then(
        response => {
          self.isLoading = false
          self.$emit(event, response.data)
        },
        error => {
          self.isLoading = false
          self.errors = error.backendErrors
        }
      )
    }
  }
}
</script>
