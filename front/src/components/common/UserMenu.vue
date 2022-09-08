<script setup lang="ts">
import { SUPPORTED_LOCALES } from '~/init/locale'
import { useI18n } from 'vue-i18n'
import { computed } from 'vue'

import useThemeList from '~/composables/useThemeList'
import useTheme from '~/composables/useTheme'

interface Events {
  (e: 'show:shortcuts-modal'): void
}

const emit = defineEmits<Events>()

const { t } = useI18n()
const themes = useThemeList()
const { theme } = useTheme()

const labels = computed(() => ({
  profile: t('Profile'),
  settings: t('Settings'),
  logout: t('Log out'),
  about: t('About'),
  shortcuts: t('Keyboard shortcuts'),
  support: t('Help'),
  forum: t('Forum'),
  docs: t('Documentation'),
  language: t('Change language'),
  theme: t('Change theme'),
  chat: t('Chat room'),
  git: t('Issue tracker'),
  login: t('Log in'),
  signup: t('Sign up'),
  notifications: t('Notifications')
}))
</script>

<template>
  <div class="ui menu">
    <div class="ui scrolling dropdown item">
      <i class="language icon" />
      {{ labels.language }}
      <i class="dropdown icon" />
      <div
        id="language-select"
        class="menu"
      >
        <a
          v-for="(language, key) in SUPPORTED_LOCALES"
          :key="key"
          :class="[{'active': $i18n.locale === key},'item']"
          :value="key"
          @click="$i18n.locale = key"
        >{{ language }}</a>
      </div>
    </div>
    <div class="ui dropdown item">
      <i class="palette icon" />
      {{ labels.theme }}
      <i class="dropdown icon" />
      <div
        id="theme-select"
        class="menu"
      >
        <a
          v-for="t in themes"
          :key="t.key"
          :class="[{'active': theme === t.key}, 'item']"
          :value="t.key"
          @click="theme = t.key"
        >
          <i :class="t.icon" />
          {{ t.name }}
        </a>
      </div>
    </div>
    <template v-if="$store.state.auth.authenticated">
      <div class="divider" />
      <router-link
        class="item"
        :to="{name: 'profile.overview', params: { username: $store.state.auth.username },}"
      >
        <i class="user icon" />
        {{ labels.profile }}
      </router-link>
      <router-link
        v-if="$store.state.auth.authenticated"
        class="item"
        :to="{name: 'notifications'}"
      >
        <i class="bell icon" />
        <div
          v-if="$store.state.ui.notifications.inbox > 0"
          :title="labels.notifications"
          :class="['ui', 'circular', 'mini', 'right floated', 'accent', 'label']"
        >
          {{ $store.state.ui.notifications.inbox }}
        </div>
        {{ labels.notifications }}
      </router-link>
      <router-link
        class="item"
        :to="{ path: '/settings' }"
      >
        <i class="cog icon" />
        {{ labels.settings }}
      </router-link>
    </template>
    <div class="divider" />
    <div class="ui dropdown item">
      <i class="life ring outline icon" />
      {{ labels.support }}
      <i class="dropdown icon" />
      <div class="menu">
        <a
          href="https://forum.funkwhale.audio"
          class="item"
          target="_blank"
        >
          <i class="users icon" />
          {{ labels.forum }}
        </a>
        <a
          href="https://matrix.to/#/#funkwhale-support:matrix.org"
          class="item"
          target="_blank"
        >
          <i class="comment icon" />
          {{ labels.chat }}
        </a>
        <a
          href="https://dev.funkwhale.audio/funkwhale/funkwhale/issues"
          class="item"
          target="_blank"
        >
          <i class="gitlab icon" />
          {{ labels.git }}
        </a>
      </div>
    </div>
    <a
      href="https://docs.funkwhale.audio"
      class="item"
      target="_blank"
    >
      <i class="book open icon" />
      {{ labels.docs }}
    </a>
    <a
      href=""
      class="item"
      @click.prevent="emit('show:shortcuts-modal')"
    >
      <i class="keyboard icon" />
      {{ labels.shortcuts }}
    </a>
    <router-link
      v-if="$route.path != '/about'"
      class="item"
      :to="{ name: 'about' }"
    >
      <i class="question circle outline icon" />
      {{ labels.about }}
    </router-link>
    <template v-if="$store.state.auth.authenticated && $route.path != '/logout'">
      <div class="divider" />
      <router-link
        class="item"
        style="color: var(--danger-color)!important;"
        :to="{ name: 'logout' }"
      >
        <i class="sign out alternate icon" />
        {{ labels.logout }}
      </router-link>
    </template>
    <template v-if="!$store.state.auth.authenticated">
      <div class="divider" />
      <router-link
        class="item"
        :to="{ name: 'login' }"
      >
        <i class="sign in alternate icon" />
        {{ labels.login }}
      </router-link>
    </template>
    <template v-if="!$store.state.auth.authenticated && $store.state.instance.settings.users.registration_enabled.value">
      <router-link
        class="item"
        :to="{ name: 'signup' }"
      >
        <i class="user icon" />
        {{ labels.signup }}
      </router-link>
    </template>
  </div>
</template>
