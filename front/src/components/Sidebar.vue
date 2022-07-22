<script setup lang="ts">
import type { RouteRecordName } from 'vue-router'

import UserModal from '~/components/common/UserModal.vue'
import Logo from '~/components/Logo.vue'
import SearchBar from '~/components/audio/SearchBar.vue'
import UserMenu from '~/components/common/UserMenu.vue'
import SemanticModal from '~/components/semantic/Modal.vue'

import useThemeList from '~/composables/useThemeList'
import useTheme from '~/composables/useTheme'
import { useRoute } from 'vue-router'
import { computed, ref, watch, watchEffect, onMounted } from 'vue'
import { useGettext } from 'vue3-gettext'
import { useStore } from '~/store'
import { setupDropdown } from '~/utils/fomantic'
import { useCurrentElement } from '@vueuse/core'

interface Props {
  width: number
}

defineProps<Props>()

const store = useStore()
const theme = useTheme()
const themes = useThemeList()
const { $pgettext } = useGettext()

const route = useRoute()
const isCollapsed = ref(true)
watch(() => route.path, () => (isCollapsed.value = true))

const additionalNotifications = computed(() => store.getters['ui/additionalNotifications'])
const logoUrl = computed(() => store.state.auth.authenticated ? 'library.index' : 'index')

const labels = computed(() => ({
  mainMenu: $pgettext('Sidebar/*/Hidden text', 'Main menu'),
  selectTrack: $pgettext('Sidebar/Player/Hidden text', 'Play this track'),
  pendingFollows: $pgettext('Sidebar/Notifications/Hidden text', 'Pending follow requests'),
  pendingReviewEdits: $pgettext('Sidebar/Moderation/Hidden text', 'Pending review edits'),
  pendingReviewReports: $pgettext('Sidebar/Moderation/Hidden text', 'Pending review reports'),
  language: $pgettext('Sidebar/Settings/Dropdown.Label/Short, Verb', 'Language'),
  theme: $pgettext('Sidebar/Settings/Dropdown.Label/Short, Verb', 'Theme'),
  addContent: $pgettext('*/Library/*/Verb', 'Add content'),
  administration: $pgettext('Sidebar/Admin/Title/Noun', 'Administration')
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

const isProduction = import.meta.env.PROD
const showUserModal = ref(false)
const showLanguageModal = ref(false)
const showThemeModal = ref(false)

const gettext = useGettext()
const languageSelection = ref(gettext.current)
watch(languageSelection, (v) => {
  store.dispatch('ui/currentLanguage', v)
})

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
          <span class="visually-hidden">Home</span>
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
                  <translate translate-context="Sidebar/Admin/Title/Noun">
                    Administration
                  </translate>
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
                  <translate translate-context="*/*/*/Noun">
                    Library
                  </translate>
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
                  <translate translate-context="*/Moderation/*">
                    Moderation
                  </translate>
                </router-link>
                <router-link
                  v-if="$store.state.auth.availablePermissions['settings']"
                  class="item"
                  :to="{name: 'manage.users.users.list'}"
                >
                  <translate translate-context="*/*/*/Noun">
                    Users
                  </translate>
                </router-link>
                <router-link
                  v-if="$store.state.auth.availablePermissions['settings']"
                  class="item"
                  :to="{path: '/manage/settings'}"
                >
                  <translate translate-context="*/*/*/Noun">
                    Settings
                  </translate>
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
                v-if="$store.state.auth.authenticated && $store.state.auth.profile.avatar && $store.state.auth.profile.avatar.urls.medium_square_crop"
                class="ui avatar image"
                alt=""
                :src="$store.getters['instance/absoluteUrl']($store.state.auth.profile.avatar.urls.medium_square_crop)"
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
              v-if="$store.state.auth.authenticated && $store.state.auth.profile?.avatar.urls.medium_square_crop"
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
              v-for="(language, key) in $language.available"
              :key="key"
            >
              <input
                :id="`${key}`"
                v-model="languageSelection"
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
              v-for="t in themes"
              :key="t.key"
            >
              <input
                :id="t.key"
                v-model="theme"
                type="radio"
                name="theme"
                :value="t.key"
              >
              <label :for="t.key">{{ t.name }}</label>
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
        <translate translate-context="*/Login/*/Verb">
          Login
        </translate>
      </router-link>
      <div class="ui small hidden divider" />
      <router-link
        class="ui fluid tiny button"
        :to="{path: '/signup'}"
      >
        <translate translate-context="*/Signup/Link/Verb">
          Create an account
        </translate>
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
        <translate translate-context="*/*/*">
          Main navigation
        </translate>
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
              <translate translate-context="*/*/*/Verb">
                Explore
              </translate>
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
                <i class="search icon" /><translate translate-context="Sidebar/Navigation/List item.Link/Verb">
                  Search
                </translate>
              </router-link>
              <router-link
                class="item"
                :to="{name: 'library.index'}"
                active-class="_active"
              >
                <i class="music icon" /><translate translate-context="Sidebar/Navigation/List item.Link/Verb">
                  Browse
                </translate>
              </router-link>
              <router-link
                class="item"
                :to="{name: 'library.podcasts.browse'}"
              >
                <i class="podcast icon" /><translate translate-context="*/*/*">
                  Podcasts
                </translate>
              </router-link>
              <router-link
                class="item"
                :to="{name: 'library.albums.browse'}"
              >
                <i class="compact disc icon" /><translate translate-context="*/*/*">
                  Albums
                </translate>
              </router-link>
              <router-link
                class="item"
                :to="{name: 'library.artists.browse'}"
              >
                <i class="user icon" /><translate translate-context="*/*/*">
                  Artists
                </translate>
              </router-link>
              <router-link
                class="item"
                :to="{name: 'library.playlists.browse'}"
              >
                <i class="list icon" /><translate translate-context="*/*/*">
                  Playlists
                </translate>
              </router-link>
              <router-link
                class="item"
                :to="{name: 'library.radios.browse'}"
              >
                <i class="feed icon" /><translate translate-context="*/*/*">
                  Radios
                </translate>
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
              <translate translate-context="*/*/*/Noun">
                My Library
              </translate>
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
                <i class="music icon" /><translate translate-context="Sidebar/Navigation/List item.Link/Verb">
                  Browse
                </translate>
              </router-link>
              <router-link
                class="item"
                :to="{name: 'library.albums.me'}"
              >
                <i class="compact disc icon" /><translate translate-context="*/*/*">
                  Albums
                </translate>
              </router-link>
              <router-link
                class="item"
                :to="{name: 'library.artists.me'}"
              >
                <i class="user icon" /><translate translate-context="*/*/*">
                  Artists
                </translate>
              </router-link>
              <router-link
                class="item"
                :to="{name: 'library.playlists.me'}"
              >
                <i class="list icon" /><translate translate-context="*/*/*">
                  Playlists
                </translate>
              </router-link>
              <router-link
                class="item"
                :to="{name: 'library.radios.me'}"
              >
                <i class="feed icon" /><translate translate-context="*/*/*">
                  Radios
                </translate>
              </router-link>
              <router-link
                class="item"
                :to="{name: 'favorites'}"
              >
                <i class="heart icon" /><translate translate-context="Sidebar/Favorites/List item.Link/Noun">
                  Favorites
                </translate>
              </router-link>
            </div>
          </div>
          <router-link
            v-if="$store.state.auth.authenticated"
            class="header item"
            :to="{name: 'subscriptions'}"
          >
            <translate translate-context="*/*/*">
              Channels
            </translate>
          </router-link>
          <div class="item">
            <h3 class="header">
              <translate translate-context="Footer/About/List item.Link">
                More
              </translate>
            </h3>
            <div class="menu">
              <router-link
                class="item"
                to="/about"
                active-class="router-link-exact-active active"
              >
                <i class="info icon" /><translate translate-context="Sidebar/*/List item.Link">
                  About this pod
                </translate>
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
              @click.prevent="$emit('show:set-instance-modal')"
            >Switch instance</a>
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
