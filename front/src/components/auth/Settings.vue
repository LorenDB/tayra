<script setup lang="ts">
import type { BackendError, Application, PrivacyLevel } from '~/types'
import type { $ElementType } from 'utility-types'

import axios from 'axios'
import $ from 'jquery'

import { computed, reactive, ref, onMounted } from 'vue'
import { useGettext } from 'vue3-gettext'
import { useRouter } from 'vue-router'
import { useStore } from '~/store'

import useSharedLabels from '~/composables/locale/useSharedLabels'
import useLogger from '~/composables/useLogger'

import SubsonicTokenForm from '~/components/auth/SubsonicTokenForm.vue'
import AttachmentInput from '~/components/common/AttachmentInput.vue'
import PasswordInput from '~/components/forms/PasswordInput.vue'

const SETTINGS_ORDER: FieldId[] = ['summary', 'privacy_level']

type Field = { id: 'summary', type: 'content', value: { text: string, content_type: 'text/markdown' } }
  | { id: 'privacy_level', type: 'dropdown', choices: PrivacyLevel[], value: string }
type FieldId = $ElementType<Field, 'id'>

interface Settings {
  success: boolean
  errors: string[]
  order: FieldId[]
  fields: Record<FieldId, Field>
}

const { $pgettext } = useGettext()
const sharedLabels = useSharedLabels()
const logger = useLogger()
const router = useRouter()
const store = useStore()

const settings = reactive({
  success: false,
  errors: [] as string[],
  fields: {
    summary: {
      id: 'summary',
      type: 'content',
      value: store.state.auth.profile?.summary ?? { text: '', content_type: 'text/markdown' }
    },
    privacy_level: {
      id: 'privacy_level',
      type: 'dropdown',
      value: store.state.auth.profile?.privacy_level,
      choices: ['me', 'instance', 'everyone']
    }
  }
} as Settings)

const orderedSettingsFields = SETTINGS_ORDER.map(id => settings.fields[id])

const labels = computed(() => ({
  title: $pgettext('Head/Settings/Title', 'Account Settings')
}))

const isLoading = ref(false)
const submitSettings = async () => {
  settings.success = false
  settings.errors = []
  isLoading.value = true

  const payload = {} as Record<FieldId, string | null | { text: string }>
  for (const id of SETTINGS_ORDER) {
    const field = settings.fields[id]
    payload[id] = field.type === 'content' && !field.value.text
      ? null
      : field.value
  }

  try {
    await axios.patch(`users/${store.state.auth.username}/`, payload)

    logger.info('Updated settings successfully')
    settings.success = true

    const me = await axios.get('users/me/')
    store.dispatch('auth/updateProfile', me.data)
  } catch (error) {
    logger.error('Error while updating settings')
    settings.errors.push(...(error as BackendError).backendErrors)
  }

  isLoading.value = false
}

const apps = ref([] as Application[])
const isLoadingApps = ref(false)
const fetchApps = async () => {
  apps.value = []
  isLoadingApps.value = true

  try {
    const response = await axios.get('oauth/grants/')
    apps.value = response.data as Application[]
  } catch (error) {
    logger.error('Error while fetching Apps')
    settings.errors.push(...(error as BackendError).backendErrors)
  }

  isLoadingApps.value = false
}

const ownedApps = ref([] as Application[])
const fetchOwnedApps = async () => {
  ownedApps.value = []
  // TODO: Add loader

  try {
    const response = await axios.get('oauth/apps/')
    ownedApps.value = response.data as Application[]
  } catch (error) {
    logger.error('Error while fetching owned Apps')
    settings.errors.push(...(error as BackendError).backendErrors)
  }
}

const isRevoking = reactive(new Set())
const revokeApp = async (id: string) => {
  isRevoking.add(id)

  try {
    await axios.delete(`oauth/grants/${id}/`)
    apps.value = apps.value.filter(app => app.client_id !== id)
  } catch (error) {
    logger.error('Error while revoking App')
    settings.errors.length = 0
    settings.errors.push(...(error as BackendError).backendErrors)
  }

  isRevoking.delete(id)
}

const isDeleting = reactive(new Set())
const deleteApp = async (id: string) => {
  isDeleting.add(id)

  try {
    await axios.delete(`oauth/apps/${id}/`)
    ownedApps.value = ownedApps.value.filter(app => app.client_id !== id)
  } catch (error) {
    logger.error('Error while deleting App')
    settings.errors.length = 0
    settings.errors.push(...(error as BackendError).backendErrors)
  }

  isDeleting.delete(id)
}

const avatar = ref({ uuid: null, ...(store.state.auth.profile?.avatar ?? {}) })
// TODO (wvffle): Maybe should be reactive?
const initialAvatar = avatar.value.uuid ?? undefined
const avatarErrors = ref([] as string[])
const isLoadingAvatar = ref(false)
const submitAvatar = async (uuid: string | null) => {
  if (!uuid) return

  isLoadingAvatar.value = true

  try {
    const response = await axios.patch(`users/${store.state.auth.username}/`, { avatar: uuid })
    avatar.value = response.data.avatar
    store.commit('auth/avatar', response.data.avatar)
  } catch (error) {
    avatarErrors.value = (error as BackendError).backendErrors
  }

  avatarErrors.value = []
  isLoadingAvatar.value = false
}

const passwordError = ref('')
const credentials = reactive({
  oldPassword: '',
  newPassword: ''
})
const isLoadingPassword = ref(false)
const submitPassword = async () => {
  isLoadingPassword.value = true
  passwordError.value = ''

  try {
    await axios.post('auth/registration/change-password/', {
      old_password: credentials.oldPassword,
      new_password1: credentials.newPassword,
      new_password2: credentials.newPassword
    })

    logger.info('Password successfully changed')
    return router.push({
      name: 'profile.overview',
      params: { username: store.state.auth.username }
    })
  } catch (error) {
    if ((error as BackendError).response?.status === 400) {
      passwordError.value = 'invalid_credentials'
    } else {
      passwordError.value = 'unknown_error'
    }
  }

  isLoadingPassword.value = false
}

const deleteAccountPassword = ref('')
const isDeletingAccount = ref(false)
const accountDeleteErrors = ref([] as string[])
const deleteAccount = async () => {
  isDeletingAccount.value = true
  accountDeleteErrors.value = []

  try {
    const payload = {
      confirm: true,
      password: deleteAccountPassword.value
    }

    await axios.delete('users/me/', { data: payload })

    store.commit('ui/addMessage', {
      content: $pgettext('*/Auth/Message', 'Your deletion request was submitted, your account and content will be deleted shortly'),
      date: new Date()
    })

    store.dispatch('auth/logout')
  } catch (error) {
    accountDeleteErrors.value = (error as BackendError).backendErrors
  }

  deleteAccountPassword.value = ''
  isDeletingAccount.value = false
}

const isChangingEmail = ref(false)
const emailPassword = ref('')
const newEmail = ref('')
const changeEmailErrors = ref([] as string[])
const changeEmail = async () => {
  isChangingEmail.value = true
  changeEmailErrors.value = []

  try {
    await axios.post('users/users/change-email/', {
      password: emailPassword.value,
      email: newEmail.value
    })

    newEmail.value = ''
  } catch (error) {
    changeEmailErrors.value = (error as BackendError).backendErrors
  }

  emailPassword.value = ''
  isChangingEmail.value = false
}

onMounted(() => {
  $('select.dropdown').dropdown()
})

fetchApps()
fetchOwnedApps()
</script>

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
            <p v-if="sharedLabels.fields[f.id].help">
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
                {{ sharedLabels.fields[f.id].choices?.[c] }}
              </option>
            </select>
            <content-form
              v-if="f.type === 'content'"
              v-model="f.value.text"
              :field-id="f.id"
            />
          </div>
          <button
            :class="['ui', { loading: isLoading }, 'button']"
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
          <attachment-input
            v-model="avatar.uuid"
            :initial-value="initialAvatar"
            @update:model-value="submitAvatar($event)"
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
              v-model="credentials.oldPassword"
              field-id="old-password-field"
              required
            />
          </div>
          <div class="field">
            <label for="new-password-field"><translate translate-context="Content/Settings/Input.Label">New password</translate></label>
            <password-input
              v-model="credentials.newPassword"
              field-id="new-password-field"
              required
            />
          </div>
          <dangerous-button
            :class="['ui', {'loading': isLoadingPassword}, {disabled: !credentials.newPassword || !credentials.oldPassword}, 'warning', 'button']"
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
          :class="['ui', 'icon', { loading: isLoadingApps }, 'button']"
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
                  :class="['ui', 'tiny', 'danger', { loading: isRevoking.has(app.client_id) }, 'button']"
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
                  :class="['ui', 'tiny', 'danger', { loading: isDeleting.has(app.client_id) }, 'button']"
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
            :translate-params="{email: $store.state.auth.profile?.email}"
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
              v-model="deleteAccountPassword"
              field-id="current-password-field"
              required
            />
          </div>
          <dangerous-button
            :class="['ui', {'loading': isDeletingAccount}, {disabled: !deleteAccountPassword}, {danger: deleteAccountPassword}, 'button']"
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
