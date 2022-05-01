<template>
  <main
    v-title="labels.title"
    class="main pusher"
  >
    <div class="ui vertical stripe segment">
      <section class="ui text container">
        <h2 class="ui header">
          <translate translate-context="Content/Settings/Title">
            Account settings
          </translate>
        </h2>
        <form
          class="ui form"
          @submit.prevent="submitSettings()"
        >
          <div
            v-if="settings.success"
            class="ui positive message"
          >
            <h4 class="header">
              <translate translate-context="Content/Settings/Message">
                Settings updated
              </translate>
            </h4>
          </div>
          <div
            v-if="settings.errors.length > 0"
            role="alert"
            class="ui negative message"
          >
            <h4 class="header">
              <translate translate-context="Content/Settings/Error message.Title">
                Your settings can't be updated
              </translate>
            </h4>
            <ul class="list">
              <li
                v-for="(error, key) in settings.errors"
                :key="key"
              >
                {{ error }}
              </li>
            </ul>
          </div>
          <div
            v-for="f in orderedSettingsFields"
            :key="f.id"
            class="field"
          >
            <label :for="f.id">{{ sharedLabels.fields[f.id].label }}</label>
            <p v-if="f.help">
              {{ sharedLabels.fields[f.id].help }}
            </p>
            <select
              v-if="f.type === 'dropdown'"
              :id="f.id"
              v-model="f.value"
              class="ui dropdown"
            >
              <option
                v-for="(c, key) in f.choices"
                :key="key"
                :value="c"
              >
                {{ sharedLabels.fields[f.id].choices[c] }}
              </option>
            </select>
            <content-form
              v-if="f.type === 'content'"
              v-model="f.value.text"
              :field-id="f.id"
            />
          </div>
          <button
            :class="['ui', {'loading': isLoading}, 'button']"
            type="submit"
          >
            <translate translate-context="Content/Settings/Button.Label/Verb">
              Update settings
            </translate>
          </button>
        </form>
      </section>
      <section class="ui text container">
        <div class="ui hidden divider" />
        <h2 class="ui header">
          <translate translate-context="Content/Settings/Title">
            Avatar
          </translate>
        </h2>
        <div class="ui form">
          <div
            v-if="avatarErrors.length > 0"
            role="alert"
            class="ui negative message"
          >
            <h4 class="header">
              <translate translate-context="Content/Settings/Error message.Title">
                Your avatar cannot be saved
              </translate>
            </h4>
            <ul class="list">
              <li
                v-for="(error, key) in avatarErrors"
                :key="key"
              >
                {{ error }}
              </li>
            </ul>
          </div>
          {{ }}
          <attachment-input
            :value="avatar.uuid"
            :initial-value="initialAvatar"
            :required="false"
            @input="submitAvatar($event)"
            @delete="avatar = {uuid: null}"
          >
            <translate translate-context="Content/Channel/*">
              Avatar
            </translate>
          </attachment-input>
        </div>
      </section>

      <section class="ui text container">
        <div class="ui hidden divider" />
        <h2 class="ui header">
          <translate translate-context="Content/Settings/Title/Verb">
            Change my password
          </translate>
        </h2>
        <div class="ui message">
          <translate translate-context="Content/Settings/Paragraph'">
            Changing your password will also change your Subsonic API password if you have requested one.
          </translate>&nbsp;<translate translate-context="Content/Settings/Paragraph">
            You will have to update your password on your clients that use this password.
          </translate>
        </div>
        <form
          class="ui form"
          @submit.prevent="submitPassword()"
        >
          <div
            v-if="passwordError"
            role="alert"
            class="ui negative message"
          >
            <h4 class="header">
              <translate translate-context="Content/Settings/Error message.Title">
                Your password cannot be changed
              </translate>
            </h4>
            <ul class="list">
              <li v-if="passwordError == 'invalid_credentials'">
                <translate translate-context="Content/Settings/Error message.List item/Call to action">
                  Please double-check your password is correct
                </translate>
              </li>
            </ul>
          </div>
          <div class="field">
            <label for="old-password-field"><translate translate-context="Content/Settings/Input.Label">Current password</translate></label>
            <password-input
              v-model="old_password"
              field-id="old-password-field"
              required
            />
          </div>
          <div class="field">
            <label for="new-password-field"><translate translate-context="Content/Settings/Input.Label">New password</translate></label>
            <password-input
              v-model="new_password"
              field-id="new-password-field"
              required
            />
          </div>
          <dangerous-button
            :class="['ui', {'loading': isLoading}, {disabled: !new_password || !old_password}, 'warning', 'button']"
            :action="submitPassword"
          >
            <translate translate-context="Content/Settings/Button.Label">
              Change password
            </translate>
            <template #modal-header>
              <p>
                <translate translate-context="Popup/Settings/Title">
                  Change your password?
                </translate>
              </p>
            </template>
            <template #modal-content>
              <div>
                <p>
                  <translate translate-context="Popup/Settings/Paragraph">
                    Changing your password will have the following consequences:
                  </translate>
                </p>
                <ul>
                  <li>
                    <translate translate-context="Popup/Settings/List item">
                      You will be logged out from this session and have to log in with the new one
                    </translate>
                  </li>
                  <li>
                    <translate translate-context="Popup/Settings/List item">
                      Your Subsonic password will be changed to a new, random one, logging you out from devices that used the old Subsonic password
                    </translate>
                  </li>
                </ul>
              </div>
            </template>
            <template #modal-confirm>
              <div>
                <translate translate-context="Popup/Settings/Button.Label">
                  Disable access
                </translate>
              </div>
            </template>
          </dangerous-button>
        </form>
        <div class="ui hidden divider" />
        <subsonic-token-form />
      </section>

      <section
        id="content-filters"
        class="ui text container"
      >
        <div class="ui hidden divider" />
        <h2 class="ui header">
          <i class="eye slash outline icon" />
          <div class="content">
            <translate translate-context="Content/Settings/Title/Noun">
              Content filters
            </translate>
          </div>
        </h2>
        <p>
          <translate translate-context="Content/Settings/Paragraph">
            Content filters help you hide content you don't want to see on the service.
          </translate>
        </p>

        <button
          class="ui icon button"
          @click="$store.dispatch('moderation/fetchContentFilters')"
        >
          <i class="refresh icon" />&nbsp;
          <translate translate-context="Content/*/Button.Label/Short, Verb">
            Refresh
          </translate>
        </button>
        <h3 class="ui header">
          <translate translate-context="Content/Settings/Title">
            Hidden artists
          </translate>
        </h3>
        <table class="ui compact very basic unstackable table">
          <thead>
            <tr>
              <th>
                <translate translate-context="*/*/*/Noun">
                  Name
                </translate>
              </th>
              <th>
                <translate translate-context="Content/*/*/Noun">
                  Creation date
                </translate>
              </th>
              <th />
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="filter in $store.getters['moderation/artistFilters']()"
              :key="filter.uuid"
            >
              <td>
                <router-link :to="{name: 'library.artists.detail', params: {id: filter.target.id }}">
                  {{ filter.target.name }}
                </router-link>
              </td>
              <td>
                <human-date :date="filter.creation_date" />
              </td>
              <td>
                <button
                  class="ui basic tiny button"
                  @click="$store.dispatch('moderation/deleteContentFilter', filter.uuid)"
                >
                  <translate translate-context="*/*/*/Verb">
                    Delete
                  </translate>
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </section>
      <section
        id="grants"
        class="ui text container"
      >
        <div class="ui hidden divider" />
        <h2 class="ui header">
          <i class="open lock icon" />
          <div class="content">
            <translate translate-context="Content/Settings/Title/Noun">
              Authorized apps
            </translate>
          </div>
        </h2>
        <p>
          <translate translate-context="Content/Settings/Paragraph">
            This is the list of applications that have access to your account data.
          </translate>
        </p>
        <button
          class="ui icon button"
          @click="fetchApps()"
        >
          <i class="refresh icon" />&nbsp;
          <translate translate-context="Content/*/Button.Label/Short, Verb">
            Refresh
          </translate>
        </button>
        <table
          v-if="apps.length > 0"
          class="ui compact very basic unstackable table"
        >
          <thead>
            <tr>
              <th>
                <translate translate-context="*/*/*/Noun">
                  Application
                </translate>
              </th>
              <th>
                <translate translate-context="Content/*/*/Noun">
                  Permissions
                </translate>
              </th>
              <th />
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="app in apps"
              :key="app.client_id"
            >
              <td>
                {{ app.name }}
              </td>
              <td>
                {{ app.scopes }}
              </td>
              <td>
                <dangerous-button
                  class="ui tiny danger button"
                  @confirm="revokeApp(app.client_id)"
                >
                  <translate translate-context="*/*/*/Verb">
                    Revoke
                  </translate>
                  <template #modal-header>
                    <p
                      v-translate="{application: app.name}"
                      translate-context="Popup/Settings/Title"
                    >
                      Revoke access for application "%{ application }"?
                    </p>
                  </template>
                  <template #modal-content>
                    <p>
                      <translate translate-context="Popup/Settings/Paragraph">
                        This will prevent this application from accessing the service on your behalf.
                      </translate>
                    </p>
                  </template>
                  <template #modal-confirm>
                    <div>
                      <translate translate-context="*/Settings/Button.Label/Verb">
                        Revoke access
                      </translate>
                    </div>
                  </template>
                </dangerous-button>
              </td>
            </tr>
          </tbody>
        </table>
        <empty-state v-else>
          <template #title>
            <translate translate-context="Content/Applications/Paragraph">
              You don't have any application connected with your account.
            </translate>
          </template>
          <translate translate-context="Content/Applications/Paragraph">
            If you authorize third-party applications to access your data, those applications will be listed here.
          </translate>
        </empty-state>
      </section>
      <section
        id="apps"
        class="ui text container"
      >
        <div class="ui hidden divider" />
        <h2 class="ui header">
          <i class="code icon" />
          <div class="content">
            <translate translate-context="Content/Settings/Title/Noun">
              Your applications
            </translate>
          </div>
        </h2>
        <p>
          <translate translate-context="Content/Settings/Paragraph">
            This is the list of applications that you have registered.
          </translate>
        </p>
        <router-link
          class="ui success button"
          :to="{name: 'settings.applications.new'}"
        >
          <translate translate-context="Content/Settings/Button.Label">
            Register a new application
          </translate>
        </router-link>
        <table
          v-if="ownedApps.length > 0"
          class="ui compact very basic unstackable table"
        >
          <thead>
            <tr>
              <th>
                <translate translate-context="*/*/*/Noun">
                  Application
                </translate>
              </th>
              <th>
                <translate translate-context="Content/*/*/Noun">
                  Scopes
                </translate>
              </th>
              <th>
                <translate translate-context="Content/*/*/Noun">
                  Creation date
                </translate>
              </th>
              <th />
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="app in ownedApps"
              :key="app.client_id"
            >
              <td>
                <router-link :to="{name: 'settings.applications.edit', params: {id: app.client_id}}">
                  {{ app.name }}
                </router-link>
              </td>
              <td>
                {{ app.scopes }}
              </td>
              <td>
                <human-date :date="app.created" />
              </td>
              <td>
                <router-link
                  class="ui tiny success button"
                  :to="{name: 'settings.applications.edit', params: {id: app.client_id}}"
                >
                  <translate translate-context="Content/*/Button.Label/Verb">
                    Edit
                  </translate>
                </router-link>
                <dangerous-button
                  class="ui tiny danger button"
                  @confirm="deleteApp(app.client_id)"
                >
                  <translate translate-context="*/*/*/Verb">
                    Remove
                  </translate>
                  <template #modal-header>
                    <p
                      v-translate="{application: app.name}"
                      translate-context="Popup/Settings/Title"
                    >
                      Remove application "%{ application }"?
                    </p>
                  </template>
                  <template #modal-content>
                    <p>
                      <translate translate-context="Popup/Settings/Paragraph">
                        This will permanently remove the application and all the associated tokens.
                      </translate>
                    </p>
                  </template>
                  <template #modal-confirm>
                    <div>
                      <translate translate-context="*/Settings/Button.Label/Verb">
                        Remove application
                      </translate>
                    </div>
                  </template>
                </dangerous-button>
              </td>
            </tr>
          </tbody>
        </table>
        <empty-state v-else>
          <template #title>
            <translate translate-context="Content/Applications/Paragraph">
              You don't have registered any application yet.
            </translate>
          </template>
          <translate translate-context="Content/Applications/Paragraph">
            Register one to integrate Funkwhale with third-party applications.
          </translate>
        </empty-state>
      </section>

      <section
        id="plugins"
        class="ui text container"
      >
        <div class="ui hidden divider" />
        <h2 class="ui header">
          <i class="code icon" />
          <div class="content">
            <translate translate-context="Content/Settings/Title/Noun">
              Plugins
            </translate>
          </div>
        </h2>
        <p>
          <translate translate-context="Content/Settings/Paragraph">
            Use plugins to extend Funkwhale and get additional features.
          </translate>
        </p>
        <router-link
          class="ui success button"
          :to="{name: 'settings.plugins'}"
        >
          <translate translate-context="Content/Settings/Button.Label">
            Manage plugins
          </translate>
        </router-link>
      </section>
      <section class="ui text container">
        <div class="ui hidden divider" />
        <h2 class="ui header">
          <i class="comment icon" />
          <div class="content">
            <translate translate-context="*/*/Button.Label">
              Change my e-mail address
            </translate>
          </div>
        </h2>
        <p>
          <translate translate-context="Content/Settings/Paragraph'">
            Change the e-mail address associated with your account. We will send a confirmation to the new address.
          </translate>
        </p>
        <p>
          <translate
            :translate-params="{email: $store.state.auth.profile.email}"
            translate-context="Content/Settings/Paragraph'"
          >
            Your current e-mail address is %{ email }.
          </translate>
        </p>
        <form
          class="ui form"
          @submit.prevent="changeEmail"
        >
          <div
            v-if="changeEmailErrors.length > 0"
            role="alert"
            class="ui negative message"
          >
            <h4 class="header">
              <translate translate-context="Content/Settings/Error message.Title">
                We cannot change your e-mail address
              </translate>
            </h4>
            <ul class="list">
              <li
                v-for="(error, key) in changeEmailErrors"
                :key="key"
              >
                {{ error }}
              </li>
            </ul>
          </div>
          <div class="field">
            <label for="new-email"><translate translate-context="*/*/*">New e-mail address</translate></label>
            <input
              id="new-email"
              v-model="newEmail"
              required
              type="email"
            >
          </div>
          <div class="field">
            <label for="current-password-field-email"><translate translate-context="*/*/*">Password</translate></label>
            <password-input
              v-model="emailPassword"
              field-id="current-password-field-email"
              required
            />
          </div>
          <button
            type="submit"
            class="ui button"
          >
            <translate translate-context="*/*/*">
              Update
            </translate>
          </button>
        </form>
      </section>
      <section class="ui text container">
        <div class="ui hidden divider" />
        <h2 class="ui header">
          <i class="trash icon" />
          <div class="content">
            <translate translate-context="*/*/Button.Label">
              Delete my account
            </translate>
          </div>
        </h2>
        <p>
          <translate translate-context="Content/Settings/Paragraph'">
            You can permanently and irreversibly delete your account and all the associated data using the form below. You will be asked for confirmation.
          </translate>
        </p>
        <div
          role="alert"
          class="ui warning message"
        >
          <translate translate-context="Content/Settings/Paragraph'">
            Your account will be deleted from our servers within a few minutes. We will also notify other servers who may have a copy of some of your data so they can proceed to deletion. Please note that some of these servers may be offline or unwilling to comply though.
          </translate>
        </div>
        <div class="ui form">
          <div
            v-if="accountDeleteErrors.length > 0"
            role="alert"
            class="ui negative message"
          >
            <h4 class="header">
              <translate translate-context="Content/Settings/Error message.Title">
                We cannot delete your account
              </translate>
            </h4>
            <ul class="list">
              <li
                v-for="(error, key) in accountDeleteErrors"
                :key="key"
              >
                {{ error }}
              </li>
            </ul>
          </div>
          <div class="field">
            <label for="current-password-field"><translate translate-context="*/*/*">Password</translate></label>
            <password-input
              v-model="password"
              field-id="current-password-field"
              required
            />
          </div>
          <dangerous-button
            :class="['ui', {'loading': isDeletingAccount}, {disabled: !password}, {danger: password}, 'button']"
            :action="deleteAccount"
          >
            <translate translate-context="*/*/Button.Label">
              Delete my account…
            </translate>
            <template #modal-header>
              <p>
                <translate translate-context="Popup/Settings/Title">
                  Do you want to delete your account?
                </translate>
              </p>
            </template>
            <template #modal-content>
              <div>
                <p>
                  <translate translate-context="Popup/Settings/Paragraph">
                    This is irreversible and will permanently remove your data from our servers. You will we immediatly logged out.
                  </translate>
                </p>
              </div>
            </template>
            <template #modal-confirm>
              <div>
                <translate translate-context="*/*/Button.Label">
                  Delete my account
                </translate>
              </div>
            </template>
          </dangerous-button>
        </div>
      </section>
    </div>
  </main>
</template>

<script>
import $ from 'jquery'
import axios from 'axios'
import PasswordInput from '~/components/forms/PasswordInput.vue'
import SubsonicTokenForm from '~/components/auth/SubsonicTokenForm.vue'
import TranslationsMixin from '~/components/mixins/Translations.vue'
import AttachmentInput from '~/components/common/AttachmentInput.vue'
import useLogger from '~/composables/useLogger'

const logger = useLogger()

export default {
  components: {
    PasswordInput,
    SubsonicTokenForm,
    AttachmentInput
  },
  mixins: [TranslationsMixin],
  data () {
    const d = {
      // We need to initialize the component with any
      // properties that will be used in it
      old_password: '',
      new_password: '',
      avatar: { ...(this.$store.state.auth.profile.avatar || { uuid: null }) },
      passwordError: '',
      password: '',
      isLoading: false,
      isLoadingAvatar: false,
      isDeletingAccount: false,
      changeEmailErrors: [],
      isChangingEmail: false,
      newEmail: null,
      emailPassword: null,
      accountDeleteErrors: [],
      avatarErrors: [],
      apps: [],
      ownedApps: [],
      settings: {
        success: false,
        errors: [],
        order: ['summary', 'privacy_level'],
        fields: {
          summary: {
            type: 'content',
            initial: this.$store.state.auth.profile.summary || { text: '', content_type: 'text/markdown' }
          },
          privacy_level: {
            type: 'dropdown',
            initial: this.$store.state.auth.profile.privacy_level,
            choices: ['me', 'instance', 'everyone']
          }
        }
      }
    }
    d.initialAvatar = d.avatar.uuid
    d.settings.order.forEach(id => {
      d.settings.fields[id].value = d.settings.fields[id].initial
      d.settings.fields[id].id = id
    })
    return d
  },
  computed: {
    labels () {
      return {
        title: this.$pgettext('Head/Settings/Title', 'Account Settings')
      }
    },
    orderedSettingsFields () {
      const self = this
      return this.settings.order.map(id => {
        return self.settings.fields[id]
      })
    },
    settingsValues () {
      const self = this
      const s = {}
      this.settings.order.forEach(setting => {
        const conf = self.settings.fields[setting]
        s[setting] = conf.value
        if (setting === 'summary' && !conf.value.text) {
          s[setting] = null
        }
      })
      return s
    }
  },
  created () {
    this.fetchApps()
    this.fetchOwnedApps()
  },
  mounted () {
    $('select.dropdown').dropdown()
  },
  methods: {
    submitSettings () {
      this.settings.success = false
      this.settings.errors = []
      const self = this
      const payload = this.settingsValues
      const url = `users/${this.$store.state.auth.username}/`
      return axios.patch(url, payload).then(
        response => {
          logger.info('Updated settings successfully')
          self.settings.success = true
          return axios.get('users/me/').then(response => {
            self.$store.dispatch('auth/updateProfile', response.data)
          })
        },
        error => {
          logger.error('Error while updating settings')
          self.isLoading = false
          self.settings.errors = error.backendErrors
        }
      )
    },
    fetchApps () {
      this.apps = []
      const self = this
      const url = 'oauth/grants/'
      return axios.get(url).then(
        response => {
          self.apps = response.data
        },
        error => {
          logger.error('Error while fetching Apps')
          self.isLoading = false
          self.settings.errors = error.backendErrors
        }
      )
    },
    fetchOwnedApps () {
      this.ownedApps = []
      const self = this
      const url = 'oauth/apps/'
      return axios.get(url).then(
        response => {
          self.ownedApps = response.data.results
        },
        error => {
          logger.error('Error while fetching owned Apps')
          self.isLoading = false
          self.settings.errors = error.backendErrors
        }
      )
    },
    revokeApp (id) {
      const self = this
      const url = `oauth/grants/${id}/`
      return axios.delete(url).then(
        response => {
          self.apps = self.apps.filter(a => {
            return a.client_id !== id
          })
        },
        error => {
          logger.error('Error while revoking App')
          self.isLoading = false
          self.settings.errors = error.backendErrors
        }
      )
    },
    deleteApp (id) {
      const self = this
      const url = `oauth/apps/${id}/`
      return axios.delete(url).then(
        response => {
          self.ownedApps = self.ownedApps.filter(a => {
            return a.client_id !== id
          })
        },
        error => {
          logger.error('Error while deleting App')
          self.isLoading = false
          self.settings.errors = error.backendErrors
        }
      )
    },
    submitAvatar (uuid) {
      this.isLoadingAvatar = true
      this.avatarErrors = []
      const self = this
      axios
        .patch(`users/${this.$store.state.auth.username}/`, { avatar: uuid })
        .then(
          response => {
            this.isLoadingAvatar = false
            self.avatar = response.data.avatar
            self.$store.commit('auth/avatar', response.data.avatar)
          },
          error => {
            self.isLoadingAvatar = false
            self.avatarErrors = error.backendErrors
          }
        )
    },
    submitPassword () {
      const self = this
      self.isLoading = true
      this.error = ''
      const credentials = {
        old_password: this.old_password,
        new_password1: this.new_password,
        new_password2: this.new_password
      }
      const url = 'auth/registration/change-password/'
      return axios.post(url, credentials).then(
        response => {
          logger.info('Password successfully changed')
          self.$router.push({
            name: 'profile.overview',
            params: {
              username: self.$store.state.auth.username
            }
          })
        },
        error => {
          if (error.response.status === 400) {
            self.passwordError = 'invalid_credentials'
          } else {
            self.passwordError = 'unknown_error'
          }
          self.isLoading = false
        }
      )
    },
    deleteAccount () {
      this.isDeletingAccount = true
      this.accountDeleteErrors = []
      const self = this
      const payload = {
        confirm: true,
        password: this.password
      }
      axios.delete('users/me/', { data: payload })
        .then(
          response => {
            self.isDeletingAccount = false
            const msg = self.$pgettext('*/Auth/Message', 'Your deletion request was submitted, your account and content will be deleted shortly')
            self.$store.commit('ui/addMessage', {
              content: msg,
              date: new Date()
            })
            self.$store.dispatch('auth/logout')
          },
          error => {
            self.isDeletingAccount = false
            self.accountDeleteErrors = error.backendErrors
          }
        )
    },

    changeEmail () {
      this.isChangingEmail = true
      this.changeEmailErrors = []
      const self = this
      const payload = {
        password: this.emailPassword,
        email: this.newEmail
      }
      axios.post('users/users/change-email/', payload)
        .then(
          response => {
            self.isChangingEmail = false
            self.newEmail = null
            self.emailPassword = null
            const msg = self.$pgettext('*/Auth/Message', 'Your e-mail address has been changed, please check your inbox for our confirmation message.')
            self.$store.commit('ui/addMessage', {
              content: msg,
              date: new Date()
            })
          },
          error => {
            self.isChangingEmail = false
            self.changeEmailErrors = error.backendErrors
          }
        )
    }
  }
}
</script>
