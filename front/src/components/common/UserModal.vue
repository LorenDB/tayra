<script setup lang="ts">
import SemanticModal from '~/components/semantic/Modal.vue'
import useThemeList from '~/composables/useThemeList'
import useTheme from '~/composables/useTheme'
import { useVModel } from '@vueuse/core'
import { computed } from 'vue'
import { useGettext } from 'vue3-gettext'

interface Events {
  (e: 'update:show', value: boolean): void
  (e: 'showLanguageModalEvent'): void
  (e: 'showThemeModalEvent'): void
}

interface Props {
  show: boolean
}

const emit = defineEmits<Events>()
const props = defineProps<Props>()

const show = useVModel(props, 'show', emit)

const theme = useTheme()
const themes = useThemeList()

const { $pgettext } = useGettext()
const labels = computed(() => ({
  header: $pgettext('Popup/Title/Noun', 'Options'),
  profile: $pgettext('*/*/*/Noun', 'Profile'),
  settings: $pgettext('*/*/*/Noun', 'Settings'),
  logout: $pgettext('Sidebar/Login/List item.Link/Verb', 'Log out'),
  about: $pgettext('Sidebar/About/List item.Link', 'About'),
  shortcuts: $pgettext('*/*/*/Noun', 'Keyboard shortcuts'),
  support: $pgettext('Sidebar/*/Listitem.Link', 'Help'),
  forum: $pgettext('Sidebar/*/Listitem.Link', 'Forum'),
  docs: $pgettext('Sidebar/*/Listitem.Link', 'Documentation'),
  help: $pgettext('Sidebar/*/Listitem.Link', 'Help'),
  language: $pgettext('Sidebar/Settings/Dropdown.Label/Short, Verb', 'Language'),
  theme: $pgettext('Sidebar/Settings/Dropdown.Label/Short, Verb', 'Theme'),
  chat: $pgettext('Sidebar/*/Listitem.Link', 'Chat room'),
  git: $pgettext('Sidebar/*/List item.Link', 'Issue tracker'),
  login: $pgettext('*/*/Button.Label/Verb', 'Log in'),
  signup: $pgettext('*/*/Button.Label/Verb', 'Sign up'),
  notifications: $pgettext('*/Notifications/*', 'Notifications'),
  useOtherInstance: $pgettext('Sidebar/*/List item.Link', 'Use another instance')
}))
</script>

<template>
  <!-- TODO make generic and move to semantic/modal? -->
  <semantic-modal
    v-model:show="show"
    :scrolling="true"
    :fullscreen="false"
  >
    <div
      v-if="$store.state.auth.authenticated"
      class="header"
    >
      <img
        v-if="$store.state.auth.profile?.avatar && $store.state.auth.profile?.avatar.urls.medium_square_crop"
        v-lazy="$store.getters['instance/absoluteUrl']($store.state.auth.profile?.avatar.urls.medium_square_crop)"
        alt=""
        class="ui centered small circular image"
      >
      <actor-avatar
        v-else
        :actor="{preferred_username: $store.state.auth.username, full_username: $store.state.auth.username,}"
      />
      <h3 class="user-modal title">
        {{ labels.header }}
      </h3>
    </div>
    <div
      v-else
      class="header"
    >
      <h3 class="ui center aligned icon header">
        {{ labels.header }}
      </h3>
    </div>
    <div class="content">
      <div class="ui one column unstackable grid">
        <div class="row">
          <div
            class="column"
            role="button"
            @click="[$emit('update:show', false), emit('showLanguageModalEvent')]"
          >
            <i class="language icon user-modal list-icon" />
            <span class="user-modal list-item">{{ labels.language }}:</span>
            <div class="right floated">
              <span class="user-modal list-item">{{ $language.available[$language.current] }}</span>
              <i class="action-hint chevron right icon" />
            </div>
          </div>
        </div>
        <div class="row">
          <div
            class="column"
            role="button"
            @click="[$emit('update:show', false), emit('showThemeModalEvent')]"
          >
            <i class="palette icon user-modal list-icon" />
            <span class="user-modal list-item">{{ labels.theme }}:</span>
            <div class="right floated">
              <span class="user-modal list-item"> {{ themes.find(x => x.key === theme)?.name }}</span>
              <i class="action-hint chevron right icon user-modal" />
            </div>
          </div>
        </div>
        <div class="ui divider" />
        <template v-if="$store.state.auth.authenticated">
          <div class="row">
            <div
              class="column"
              role="button"
              @click.prevent.exact="$router.push({name: 'profile.overview', params: { username: $store.state.auth.username }})"
            >
              <i class="user icon user-modal list-icon" />
              <span class="user-modal list-item">{{ labels.profile }}</span>
            </div>
          </div>
          <div class="row">
            <router-link
              v-if="$store.state.auth.authenticated"
              v-slot="{ navigate }"
              custom
              :to="{ name: 'notifications' }"
            >
              <div
                class="column"
                role="button"
                @click="navigate"
                @keypress.enter="navigate()"
              >
                <i class="user-modal list-icon bell icon" />
                <span class="user-modal list-item">{{ labels.notifications }}</span>
              </div>
            </router-link>
          </div>
          <div class="row">
            <router-link
              v-slot="{ navigate }"
              custom
              :to="{ path: '/settings' }"
            >
              <div
                class="column"
                role="button"
                @click="navigate"
                @keypress.enter="navigate()"
              >
                <i class="user-modal list-icon cog icon" />
                <span class="user-modal list-item">{{ labels.settings }}</span>
              </div>
            </router-link>
          </div>
          <div class="ui divider" />
        </template>
        <div class="row">
          <a
            class="column"
            href="https://funkwhale.audio/help"
            target="_blank"
          >
            <i class="user-modal list-icon life ring outline icon" />
            <span class="user-modal list-item">{{ labels.help }}</span>
          </a>
        </div>
        <div class="row">
          <a
            class="column"
            href="https://docs.funkwhale.audio"
            target="_blank"
          >
            <i class="user-modal list-icon book open icon" />
            <span class="user-modal list-item">{{ labels.docs }}</span>
          </a>
        </div>
        <div class="row">
          <router-link
            v-slot="{ navigate }"
            custom
            :to="{ name: 'about' }"
          >
            <div
              class="column"
              role="button"
              @click="navigate"
              @keypress.enter="navigate()"
            >
              <i class="user-modal list-icon question circle outline icon" />
              <span class="user-modal list-item">{{ labels.about }}</span>
            </div>
          </router-link>
        </div>
        <div class="ui divider" />

        <router-link
          v-if="$store.state.auth.authenticated"
          v-slot="{ navigate }"
          custom
          :to="{ name: 'logout' }"
        >
          <div
            class="column"
            role="button"
            @click="navigate"
            @keypress.enter="navigate()"
          >
            <i class="user-modal list-icon sign out alternate icon" />
            <span class="user-modal list-item">{{ labels.logout }}</span>
          </div>
        </router-link>
        <router-link
          v-else
          v-slot="{ navigate }"
          custom
          :to="{ name: 'login' }"
        >
          <div
            class="column"
            role="button"
            @click="navigate"
            @keypress.enter="navigate()"
          >
            <i class="user-modal list-icon sign in alternate icon" />
            <span class="user-modal list-item">{{ labels.login }}</span>
          </div>
        </router-link>
        <router-link
          v-if="!$store.state.auth.authenticated && $store.state.instance.settings.users.registration_enabled.value"
          v-slot="{ navigate }"
          custom
          :to="{ name: 'signup' }"
        >
          <div
            class="column"
            role="button"
            @click="navigate"
            @keypress.enter="navigate()"
          >
            <i class="user-modal list-item user icon" />
            <span class="user-modal list-item">{{ labels.signup }}</span>
          </div>
        </router-link>
      </div>
    </div>
  </semantic-modal>
</template>

<style>
.action-hint {
  margin-left: 1rem !important;
}
</style>
