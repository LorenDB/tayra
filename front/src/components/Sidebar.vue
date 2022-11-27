<script setup lang="ts">
import type { RouteRecordName } from 'vue-router'

import { computed, ref, watch, watchEffect, onMounted } from 'vue'
import { setI18nLanguage, SUPPORTED_LOCALES } from '~/init/locale'
import { useCurrentElement } from '@vueuse/core'
import { setupDropdown } from '~/utils/fomantic'
import { useRoute } from 'vue-router'
import { useStore } from '~/store'
import { useI18n } from 'vue-i18n'

import SemanticModal from '~/components/semantic/Modal.vue'
import UserModal from '~/components/common/UserModal.vue'
import SearchBar from '~/components/audio/SearchBar.vue'
import UserMenu from '~/components/common/UserMenu.vue'
import Logo from '~/components/Logo.vue'

import useThemeList from '~/composables/useThemeList'
import useTheme from '~/composables/useTheme'

interface Events {
  (e: 'show:set-instance-modal'): void
}

interface Props {
  width: number
}

const emit = defineEmits<Events>()
defineProps<Props>()

const store = useStore()
const { theme } = useTheme()
const themes = useThemeList()
const { t, locale: i18nLocale } = useI18n()

const route = useRoute()
const isCollapsed = ref(true)
watch(() => route.path, () => (isCollapsed.value = true))

const additionalNotifications = computed(() => store.getters['ui/additionalNotifications'])
const logoUrl = computed(() => store.state.auth.authenticated ? 'library.index' : 'index')

const labels = computed(() => ({
  mainMenu: t('components.Sidebar.label.main'),
  selectTrack: t('components.Sidebar.label.play'),
  pendingFollows: t('components.Sidebar.label.follows'),
  pendingReviewEdits: t('components.Sidebar.label.edits'),
  pendingReviewReports: t('components.Sidebar.label.reports'),
  language: t('components.Sidebar.label.language'),
  theme: t('components.Sidebar.label.theme'),
  addContent: t('components.Sidebar.label.add'),
  administration: t('components.Sidebar.label.administration')
}))

type SidebarMenuTabs = 'explore' | 'myLibrary'
const expanded = ref<SidebarMenuTabs>('explore')

const ROUTE_MAPPINGS: Record<SidebarMenuTabs, RouteRecordName[]> = {
  explore: [
    'search',
    'library.index',
    'library.podcasts.browse',
    'library.albums.browse',
    'library.albums.detail',
    'library.artists.browse',
    'library.artists.detail',
    'library.tracks.detail',
    'library.playlists.browse',
    'library.playlists.detail',
    'library.radios.browse',
    'library.radios.detail'
  ],
  myLibrary: [
    'library.me',
    'library.albums.me',
    'library.artists.me',
    'library.playlists.me',
    'library.radios.me',
    'favorites'
  ]
}

watchEffect(() => {
  if (ROUTE_MAPPINGS.explore.includes(route.name as RouteRecordName)) {
    expanded.value = 'explore'
    return
  }

  if (ROUTE_MAPPINGS.myLibrary.includes(route.name as RouteRecordName)) {
    expanded.value = 'myLibrary'
    return
  }

  expanded.value = store.state.auth.authenticated ? 'myLibrary' : 'explore'
})

const moderationNotifications = computed(() =>
  store.state.ui.notifications.pendingReviewEdits
    + store.state.ui.notifications.pendingReviewReports
    + store.state.ui.notifications.pendingReviewRequests
)

const showLanguageModal = ref(false)
const locale = ref(i18nLocale.value)
watch(locale, (locale) => {
  setI18nLanguage(locale)
})

const isProduction = import.meta.env.PROD
const showUserModal = ref(false)
const showThemeModal = ref(false)

const el = useCurrentElement()
watchEffect(() => {
  if (store.state.auth.authenticated) {
    setupDropdown('.admin-dropdown', el.value)
  }

  setupDropdown('.user-dropdown', el.value)
})

onMounted(() => {
  document.getElementById('fake-sidebar')?.classList.add('loaded')
})
</script>

<template>
  <aside :class="['ui', 'vertical', 'left', 'visible', 'wide', {'collapsed': isCollapsed}, 'sidebar', 'component-sidebar']">
    <header class="ui basic segment header-wrapper">
      <router-link
        :title="'Funkwhale'"
        :to="{name: logoUrl}"
      >
        <i class="logo bordered inverted vibrant big icon">
          <logo class="logo" />
          <span class="visually-hidden">{{ $t('components.Sidebar.link.home') }}</span>
        </i>
      </router-link>
      <nav class="top ui compact right aligned inverted text menu">
        <div class="right menu">
          <div
            v-if="$store.state.auth.availablePermissions['settings'] || $store.state.auth.availablePermissions['moderation']"
            class="item"
            :title="labels.administration"
          >
            <div class="item ui inline admin-dropdown dropdown">
              <i class="wrench icon" />
              <div
                v-if="moderationNotifications > 0"
                :class="['ui', 'accent', 'mini', 'bottom floating', 'circular', 'label']"
              >
                {{ moderationNotifications }}
              </div>
              <div class="menu">
                <h3 class="header">
                  {{ $t('components.Sidebar.header.administration') }}
                </h3>
                <div class="divider" />
                <router-link
                  v-if="$store.state.auth.availablePermissions['library']"
                  class="item"
                  :to="{name: 'manage.library.edits', query: {q: 'is_approved:null'}}"
                >
                  <div
                    v-if="$store.state.ui.notifications.pendingReviewEdits > 0"
                    :title="labels.pendingReviewEdits"
                    :class="['ui', 'circular', 'mini', 'right floated', 'accent', 'label']"
                  >
                    {{ $store.state.ui.notifications.pendingReviewEdits }}
                  </div>
                  {{ $t('components.Sidebar.link.library') }}
                </router-link>
                <router-link
                  v-if="$store.state.auth.availablePermissions['moderation']"
                  class="item"
                  :to="{name: 'manage.moderation.reports.list', query: {q: 'resolved:no'}}"
                >
                  <div
                    v-if="$store.state.ui.notifications.pendingReviewReports + $store.state.ui.notifications.pendingReviewRequests > 0"
                    :title="labels.pendingReviewReports"
                    :class="['ui', 'circular', 'mini', 'right floated', 'accent', 'label']"
                  >
                    {{ $store.state.ui.notifications.pendingReviewReports + $store.state.ui.notifications.pendingReviewRequests }}
                  </div>
                  {{ $t('components.Sidebar.link.moderation') }}
                </router-link>
                <router-link
                  v-if="$store.state.auth.availablePermissions['settings']"
                  class="item"
                  :to="{name: 'manage.users.users.list'}"
                >
                  {{ $t('components.Sidebar.link.users') }}
                </router-link>
                <router-link
                  v-if="$store.state.auth.availablePermissions['settings']"
                  class="item"
                  :to="{path: '/manage/settings'}"
                >
                  {{ $t('components.Sidebar.link.settings') }}
                </router-link>
              </div>
            </div>
          </div>
        </div>
        <router-link
          v-if="$store.state.auth.authenticated"
          class="item"
          :to="{name: 'content.index'}"
        >
          <i class="upload icon" />
          <span class="visually-hidden">{{ labels.addContent }}</span>
        </router-link>
        <template v-if="width > 768">
          <div class="item">
            <div class="ui user-dropdown dropdown">
              <img
                v-if="$store.state.auth.authenticated && $store.state.auth.profile?.avatar && $store.state.auth.profile?.avatar.urls.medium_square_crop"
                class="ui avatar image"
                alt=""
                :src="$store.getters['instance/absoluteUrl']($store.state.auth.profile?.avatar.urls.medium_square_crop)"
              >
              <actor-avatar
                v-else-if="$store.state.auth.authenticated"
                :actor="{preferred_username: $store.state.auth.username, full_username: $store.state.auth.username,}"
              />
              <i
                v-else
                class="cog icon"
              />
              <div
                v-if="$store.state.ui.notifications.inbox + additionalNotifications > 0"
                :class="['ui', 'accent', 'mini', 'bottom floating', 'circular', 'label']"
              >
                {{ $store.state.ui.notifications.inbox + additionalNotifications }}
              </div>
              <user-menu
                v-bind="$attrs"
                :width="width"
              />
            </div>
          </div>
        </template>
        <template v-else>
          <a
            href=""
            class="item"
            @click.prevent.exact="showUserModal = !showUserModal"
          >
            <img
              v-if="$store.state.auth.authenticated && $store.state.auth.profile?.avatar?.urls.medium_square_crop"
              class="ui avatar image"
              alt=""
              :src="$store.getters['instance/absoluteUrl']($store.state.auth.profile?.avatar.urls.medium_square_crop)"
            >
            <actor-avatar
              v-else-if="$store.state.auth.authenticated"
              :actor="{preferred_username: $store.state.auth.username, full_username: $store.state.auth.username,}"
            />
            <i
              v-else
              class="cog icon"
            />
            <div
              v-if="$store.state.ui.notifications.inbox + additionalNotifications > 0"
              :class="['ui', 'accent', 'mini', 'bottom floating', 'circular', 'label']"
            >
              {{ $store.state.ui.notifications.inbox + additionalNotifications }}
            </div>
          </a>
        </template>
        <user-modal
          v-model:show="showUserModal"
          @show-theme-modal-event="showThemeModal=true"
          @show-language-modal-event="showLanguageModal=true"
        />
        <semantic-modal
          ref="languageModal"
          v-model:show="showLanguageModal"
          :fullscreen="false"
        >
          <i
            role="button"
            class="left chevron back inside icon"
            @click.prevent.exact="showUserModal = !showUserModal"
          />
          <div class="header">
            <h3 class="title">
              {{ labels.language }}
            </h3>
          </div>
          <div class="content">
            <fieldset
              v-for="(language, key) in SUPPORTED_LOCALES"
              :key="key"
            >
              <input
                :id="`${key}`"
                v-model="locale"
                type="radio"
                name="language"
                :value="key"
              >
              <label :for="`${key}`">{{ language }}</label>
            </fieldset>
          </div>
        </semantic-modal>
        <semantic-modal
          ref="themeModal"
          v-model:show="showThemeModal"
          :fullscreen="false"
        >
          <i
            role="button"
            class="left chevron back inside icon"
            @click.prevent.exact="showUserModal = !showUserModal"
          />
          <div class="header">
            <h3 class="title">
              {{ labels.theme }}
            </h3>
          </div>
          <div class="content">
            <fieldset
              v-for="th in themes"
              :key="th.key"
            >
              <input
                :id="th.key"
                v-model="theme"
                type="radio"
                name="theme"
                :value="th.key"
              >
              <label :for="th.key">{{ th.name }}</label>
            </fieldset>
          </div>
        </semantic-modal>
        <div class="item collapse-button-wrapper">
          <button
            :class="['ui', 'basic', 'big', {'vibrant': !isCollapsed}, 'inverted icon', 'collapse', 'button']"
            @click="isCollapsed = !isCollapsed"
          >
            <i class="sidebar icon" />
          </button>
        </div>
      </nav>
    </header>
    <div class="ui basic search-wrapper segment">
      <search-bar @search="isCollapsed = false" />
    </div>
    <div
      v-if="!$store.state.auth.authenticated"
      class="ui basic signup segment"
    >
      <router-link
        class="ui fluid tiny primary button"
        :to="{name: 'login'}"
      >
        {{ $t('components.Sidebar.link.login') }}
      </router-link>
      <div class="ui small hidden divider" />
      <router-link
        class="ui fluid tiny button"
        :to="{path: '/signup'}"
      >
        {{ $t('components.Sidebar.link.createAccount') }}
      </router-link>
    </div>
    <nav
      class="secondary"
      role="navigation"
      aria-labelledby="navigation-label"
    >
      <h1
        id="navigation-label"
        class="visually-hidden"
      >
        {{ $t('components.Sidebar.header.main') }}
      </h1>
      <div class="ui small hidden divider" />
      <section
        :aria-label="labels.mainMenu"
        class="ui bottom attached active tab"
      >
        <nav
          class="ui vertical large fluid inverted menu"
          role="navigation"
          :aria-label="labels.mainMenu"
        >
          <div :class="[{ collapsed: expanded !== 'explore' }, 'collapsible item']">
            <h2
              class="header"
              role="button"
              tabindex="0"
              @click="expanded = 'explore'"
              @focus="expanded = 'explore'"
            >
              {{ $t('components.Sidebar.header.explore') }}
              <i
                v-if="expanded !== 'explore'"
                class="angle right icon"
              />
            </h2>
            <div class="menu">
              <router-link
                class="item"
                :to="{name: 'search'}"
              >
                <i class="search icon" />
                {{ $t('components.Sidebar.link.search') }}
              </router-link>
              <router-link
                class="item"
                :to="{name: 'library.index'}"
                active-class="_active"
              >
                <i class="music icon" />
                {{ $t('components.Sidebar.link.browse') }}
              </router-link>
              <router-link
                class="item"
                :to="{name: 'library.podcasts.browse'}"
              >
                <i class="podcast icon" />
                {{ $t('components.Sidebar.link.podcasts') }}
              </router-link>
              <router-link
                class="item"
                :to="{name: 'library.albums.browse'}"
              >
                <i class="compact disc icon" />
                {{ $t('components.Sidebar.link.albums') }}
              </router-link>
              <router-link
                class="item"
                :to="{name: 'library.artists.browse'}"
              >
                <i class="user icon" />
                {{ $t('components.Sidebar.link.artists') }}
              </router-link>
              <router-link
                class="item"
                :to="{name: 'library.playlists.browse'}"
              >
                <i class="list icon" />
                {{ $t('components.Sidebar.link.playlists') }}
              </router-link>
              <router-link
                class="item"
                :to="{name: 'library.radios.browse'}"
              >
                <i class="feed icon" />
                {{ $t('components.Sidebar.link.radios') }}
              </router-link>
            </div>
          </div>
          <div
            v-if="$store.state.auth.authenticated"
            :class="[{ collapsed: expanded !== 'myLibrary' }, 'collapsible item']"
          >
            <h3
              class="header"
              role="button"
              tabindex="0"
              @click="expanded = 'myLibrary'"
              @focus="expanded = 'myLibrary'"
            >
              {{ $t('components.Sidebar.header.library') }}
              <i
                v-if="expanded !== 'myLibrary'"
                class="angle right icon"
              />
            </h3>
            <div class="menu">
              <router-link
                class="item"
                :to="{name: 'library.me'}"
              >
                <i class="music icon" />
                {{ $t('components.Sidebar.link.browse') }}
              </router-link>
              <router-link
                class="item"
                :to="{name: 'library.albums.me'}"
              >
                <i class="compact disc icon" />
                {{ $t('components.Sidebar.link.albums') }}
              </router-link>
              <router-link
                class="item"
                :to="{name: 'library.artists.me'}"
              >
                <i class="user icon" />
                {{ $t('components.Sidebar.link.artists') }}
              </router-link>
              <router-link
                class="item"
                :to="{name: 'library.playlists.me'}"
              >
                <i class="list icon" />
                {{ $t('components.Sidebar.link.playlists') }}
              </router-link>
              <router-link
                class="item"
                :to="{name: 'library.radios.me'}"
              >
                <i class="feed icon" />
                {{ $t('components.Sidebar.link.radios') }}
              </router-link>
              <router-link
                class="item"
                :to="{name: 'favorites'}"
              >
                <i class="heart icon" />
                {{ $t('components.Sidebar.link.favorites') }}
              </router-link>
            </div>
          </div>
          <router-link
            v-if="$store.state.auth.authenticated"
            class="header item"
            :to="{name: 'subscriptions'}"
          >
            {{ $t('components.Sidebar.link.channels') }}
          </router-link>
          <div class="item">
            <h3 class="header">
              {{ $t('components.Sidebar.header.more') }}
            </h3>
            <div class="menu">
              <router-link
                class="item"
                to="/about"
                active-class="router-link-exact-active active"
              >
                <i class="info icon" />
                {{ $t('components.Sidebar.link.about') }}
              </router-link>
            </div>
          </div>
          <div
            v-if="!isProduction"
            class="item"
          >
            <a
              role="button"
              href=""
              class="link item"
              @click.prevent="emit('show:set-instance-modal')"
            >{{ $t('components.Sidebar.link.switchInstance') }}</a>
          </div>
        </nav>
      </section>
    </nav>
  </aside>
</template>

<style>
[type="radio"] {
  position: absolute;
  opacity: 0;
  cursor: pointer;
  height: 0;
  width: 0;
}
[type="radio"] + label::after {
  content: "";
  font-size: 1.4em;
}
[type="radio"]:checked + label::after {
  margin-left: 10px;
  content: "\2713"; /* Checkmark */
  font-size: 1.4em;
}
[type="radio"]:checked + label {
  font-weight: bold;
}
fieldset {
  border: none;
}
.back {
  font-size: 1.25em !important;
  position: absolute;
  top: 0.5rem;
  left: 0.5rem;
  width: 2.25rem !important;
  height: 2.25rem !important;
  padding: 0.625rem 0 0 0;
}
</style>
