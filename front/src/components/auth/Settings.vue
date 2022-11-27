<script setup lang="ts">
import type { BackendError, Application, PrivacyLevel } from '~/types'
import type { $ElementType } from 'utility-types'

import axios from 'axios'
import $ from 'jquery'

import { computed, reactive, ref, onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
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

const { t } = useI18n()
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
  title: t('components.auth.Settings.title')
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
    ownedApps.value = response.data.results as Application[]
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
      content: t('components.auth.Settings.message.confirmDelete'),
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
          {{ $t('components.auth.Settings.header.accountSettings') }}
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
              {{ $t('components.auth.Settings.header.settingsUpdated') }}
            </h4>
          </div>
          <div
            v-if="settings.errors.length > 0"
            role="alert"
            class="ui negative message"
          >
            <h4 class="header">
              {{ $t('components.auth.Settings.header.updateFailure') }}
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
            {{ $t('components.auth.Settings.button.updateSettings') }}
          </button>
        </form>
      </section>
      <section class="ui text container">
        <div class="ui hidden divider" />
        <h2 class="ui header">
          {{ $t('components.auth.Settings.header.avatar') }}
        </h2>
        <div class="ui form">
          <div
            v-if="avatarErrors.length > 0"
            role="alert"
            class="ui negative message"
          >
            <h4 class="header">
              {{ $t('components.auth.Settings.header.avatarFailure') }}
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
            {{ $t('components.auth.Settings.label.avatar') }}
          </attachment-input>
        </div>
      </section>

      <section class="ui text container">
        <div class="ui hidden divider" />
        <h2 class="ui header">
          {{ $t('components.auth.Settings.header.changePassword') }}
        </h2>
        <div class="ui message">
          {{ $t('components.auth.Settings.description.changePassword.paragraph1') }}&nbsp;{{ $t('components.auth.Settings.description.changePassword.paragraph2') }}
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
              {{ $t('components.auth.Settings.header.passwordFailure') }}
            </h4>
            <ul class="list">
              <li v-if="passwordError == 'invalid_credentials'">
                {{ $t('components.auth.Settings.help.changePassword') }}
              </li>
            </ul>
          </div>
          <div class="field">
            <label for="old-password-field">{{ $t('components.auth.Settings.label.currentPassword') }}</label>
            <password-input
              v-model="credentials.oldPassword"
              field-id="old-password-field"
              required
            />
          </div>
          <div class="field">
            <label for="new-password-field">{{ $t('components.auth.Settings.label.newPassword') }}</label>
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
            {{ $t('components.auth.Settings.button.password') }}
            <template #modal-header>
              <p>
                {{ $t('components.auth.Settings.modal.changePassword.header') }}
              </p>
            </template>
            <template #modal-content>
              <div>
                <p>
                  {{ $t('components.auth.Settings.modal.changePassword.content.warning') }}
                </p>
                <ul>
                  <li>
                    {{ $t('components.auth.Settings.modal.changePassword.content.logout') }}
                  </li>
                  <li>
                    {{ $t('components.auth.Settings.modal.changePassword.content.subsonic') }}
                  </li>
                </ul>
              </div>
            </template>
            <template #modal-confirm>
              <div>
                {{ $t('components.auth.Settings.button.disableSubsonic') }}
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
            {{ $t('components.auth.Settings.header.contentFilters') }}
          </div>
        </h2>
        <p>
          {{ $t('components.auth.Settings.description.contentFilters') }}
        </p>

        <button
          class="ui icon button"
          @click="$store.dispatch('moderation/fetchContentFilters')"
        >
          <i class="refresh icon" />&nbsp;
          {{ $t('components.auth.Settings.button.refresh') }}
        </button>
        <h3 class="ui header">
          {{ $t('components.auth.Settings.header.hiddenArtists') }}
        </h3>
        <table class="ui compact very basic unstackable table">
          <thead>
            <tr>
              <th>
                {{ $t('components.auth.Settings.table.artists.header.name') }}
              </th>
              <th>
                {{ $t('components.auth.Settings.table.artists.header.creationDate') }}
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
                  {{ $t('components.auth.Settings.button.delete') }}
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
            {{ $t('components.auth.Settings.header.authorizedApps') }}
          </div>
        </h2>
        <p>
          {{ $t('components.auth.Settings.description.authorizedApps') }}
        </p>
        <button
          :class="['ui', 'icon', { loading: isLoadingApps }, 'button']"
          @click="fetchApps()"
        >
          <i class="refresh icon" />&nbsp;
          {{ $t('components.auth.Settings.button.refresh') }}
        </button>
        <table
          v-if="apps.length > 0"
          class="ui compact very basic unstackable table"
        >
          <thead>
            <tr>
              <th>
                {{ $t('components.auth.Settings.table.authorizedApps.header.application') }}
              </th>
              <th>
                {{ $t('components.auth.Settings.table.authorizedApps.header.permissions') }}
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
                  {{ $t('components.auth.Settings.button.revoke') }}
                  <template #modal-header>
                    <p>
                      {{ $t('components.auth.Settings.modal.revokeApp.header', {app: app.name}) }}
                    </p>
                  </template>
                  <template #modal-content>
                    <p>
                      {{ $t('components.auth.Settings.modal.revokeApp.content.warning') }}
                    </p>
                  </template>
                  <template #modal-confirm>
                    <div>
                      {{ $t('components.auth.Settings.button.revokeAccess') }}
                    </div>
                  </template>
                </dangerous-button>
              </td>
            </tr>
          </tbody>
        </table>
        <empty-state v-else>
          <template #title>
            {{ $t('components.auth.Settings.header.noApps') }}
          </template>
          {{ $t('components.auth.Settings.help.noApps') }}
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
            {{ $t('components.auth.Settings.header.yourApps') }}
          </div>
        </h2>
        <p>
          {{ $t('components.auth.Settings.description.yourApps') }}
        </p>
        <router-link
          class="ui success button"
          :to="{name: 'settings.applications.new'}"
        >
          {{ $t('components.auth.Settings.link.newApp') }}
        </router-link>
        <table
          v-if="ownedApps.length > 0"
          class="ui compact very basic unstackable table"
        >
          <thead>
            <tr>
              <th>
                {{ $t('components.auth.Settings.table.yourApps.header.application') }}
              </th>
              <th>
                {{ $t('components.auth.Settings.table.yourApps.header.scopes') }}
              </th>
              <th>
                {{ $t('components.auth.Settings.table.yourApps.header.creationDate') }}
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
                  {{ $t('components.auth.Settings.button.edit') }}
                </router-link>
                <dangerous-button
                  :class="['ui', 'tiny', 'danger', { loading: isDeleting.has(app.client_id) }, 'button']"
                  @confirm="deleteApp(app.client_id)"
                >
                  {{ $t('components.auth.Settings.button.remove') }}
                  <template #modal-header>
                    <p>
                      {{ $t('components.auth.Settings.modal.deleteApp.header', {app: app.name}) }}
                    </p>
                  </template>
                  <template #modal-content>
                    <p>
                      {{ $t('components.auth.Settings.modal.deleteApp.content.warning') }}
                    </p>
                  </template>
                  <template #modal-confirm>
                    <div>
                      {{ $t('components.auth.Settings.button.removeApp') }}
                    </div>
                  </template>
                </dangerous-button>
              </td>
            </tr>
          </tbody>
        </table>
        <empty-state v-else>
          <template #title>
            {{ $t('components.auth.Settings.header.noPersonalApps') }}
          </template>
          {{ $t('components.auth.Settings.help.noPersonalApps') }}
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
            {{ $t('components.auth.Settings.header.plugins') }}
          </div>
        </h2>
        <p>
          {{ $t('components.auth.Settings.description.plugins') }}
        </p>
        <router-link
          class="ui success button"
          :to="{name: 'settings.plugins'}"
        >
          {{ $t('components.auth.Settings.link.managePlugins') }}
        </router-link>
      </section>
      <section class="ui text container">
        <div class="ui hidden divider" />
        <h2 class="ui header">
          <i class="comment icon" />
          <div class="content">
            {{ $t('components.auth.Settings.header.changeEmail') }}
          </div>
        </h2>
        <p>
          {{ $t('components.auth.Settings.description.changeEmail') }}
        </p>
        <p>
          {{ $t('components.auth.Settings.message.currentEmail', { email: $store.state.auth.profile?.email }) }}
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
              {{ $t('components.auth.Settings.header.emailFailure') }}
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
            <label for="new-email">{{ $t('components.auth.Settings.label.newEmail') }}</label>
            <input
              id="new-email"
              v-model="newEmail"
              required
              type="email"
            >
          </div>
          <div class="field">
            <label for="current-password-field-email">{{ $t('components.auth.Settings.label.password') }}</label>
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
            {{ $t('components.auth.Settings.button.update') }}
          </button>
        </form>
      </section>
      <section class="ui text container">
        <div class="ui hidden divider" />
        <h2 class="ui header">
          <i class="trash icon" />
          <div class="content">
            {{ $t('components.auth.Settings.header.deleteAccount') }}
          </div>
        </h2>
        <p>
          {{ $t('components.auth.Settings.description.deleteAccount') }}
        </p>
        <div
          role="alert"
          class="ui warning message"
        >
          {{ $t('components.auth.Settings.warning.deleteAccount') }}
        </div>
        <div class="ui form">
          <div
            v-if="accountDeleteErrors.length > 0"
            role="alert"
            class="ui negative message"
          >
            <h4 class="header">
              {{ $t('components.auth.Settings.header.accountFailure') }}
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
            <label for="current-password-field">{{ $t('components.auth.Settings.label.currentPassword') }}</label>
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
            {{ $t('components.auth.Settings.button.deleteAccount') }}
            <template #modal-header>
              <p>
                {{ $t('components.auth.Settings.modal.deleteAccount.header') }}
              </p>
            </template>
            <template #modal-content>
              <div>
                <p>
                  {{ $t('components.auth.Settings.modal.deleteAccount.content.warning') }}
                </p>
              </div>
            </template>
            <template #modal-confirm>
              <div>
                {{ $t('components.auth.Settings.button.deleteAccountConfirm') }}
              </div>
            </template>
          </dangerous-button>
        </div>
      </section>
    </div>
  </main>
</template>
