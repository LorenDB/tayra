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
                    v-if="$store.state.ui.notifications.pendingReviewReports + $store.state.ui.notifications.pendingReviewRequests> 0"
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
          </a>
        </template>
        <user-modal
          v-model:show="showUserModal"
          @show-theme-modal-event="showThemeModal=true"
          @show-language-modal-event="showLanguageModal=true"
        />
        <modal
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
                :id="key"
                v-model="languageSelection"
                type="radio"
                name="language"
                :value="key"
              >
              <label :for="key">{{ language }}</label>
            </fieldset>
          </div>
        </modal>
        <modal
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
        </modal>
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
        :class="['ui', 'bottom', 'attached', {active: selectedTab === 'library'}, 'tab']"
        :aria-label="labels.mainMenu"
      >
        <nav
          class="ui vertical large fluid inverted menu"
          role="navigation"
          :aria-label="labels.mainMenu"
        >
          <div :class="[{collapsed: !exploreExpanded}, 'collapsible item']">
            <h2
              class="header"
              role="button"
              tabindex="0"
              @click="exploreExpanded = true"
              @focus="exploreExpanded = true"
            >
              <translate translate-context="*/*/*/Verb">
                Explore
              </translate>
              <i
                v-if="!exploreExpanded"
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
            :class="[{collapsed: !myLibraryExpanded}, 'collapsible item']"
          >
            <h3
              class="header"
              role="button"
              tabindex="0"
              @click="myLibraryExpanded = true"
              @focus="myLibraryExpanded = true"
            >
              <translate translate-context="*/*/*/Noun">
                My Library
              </translate>
              <i
                v-if="!myLibraryExpanded"
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
            v-if="!production"
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

<script>
import { mapState, mapActions, mapGetters } from 'vuex'
import UserModal from '~/components/common/UserModal.vue'
import Logo from '~/components/Logo.vue'
import SearchBar from '~/components/audio/SearchBar.vue'
import UserMenu from '~/components/common/UserMenu.vue'
import Modal from '~/components/semantic/Modal.vue'

import $ from 'jquery'
import useThemeList from '~/composables/useThemeList'
import useTheme from '~/composables/useTheme'
import { useRoute } from 'vue-router'
import { computed } from 'vue'

export default {
  name: 'Sidebar',
  components: {
    SearchBar,
    Logo,
    UserMenu,
    UserModal,
    Modal
  },
  props: {
    width: { type: Number, required: true }
  },
  setup () {
    const theme = useTheme()
    const themes = useThemeList()

    const route = useRoute()
    const url = computed(() => route.path)

    return {
      theme,
      themes,
      url
    }
  },
  data () {
    return {
      selectedTab: 'library',
      isCollapsed: true,
      fetchInterval: null,
      exploreExpanded: false,
      myLibraryExpanded: false,
      showUserModal: false,
      showLanguageModal: false,
      showThemeModal: false,
      languageSelection: this.$language.current
    }
  },
  destroy () {
    if (this.fetchInterval) {
      clearInterval(this.fetchInterval)
    }
  },
  computed: {
    ...mapState({
      queue: state => state.queue
    }),
    ...mapGetters({
      additionalNotifications: 'ui/additionalNotifications'
    }),
    labels () {
      const mainMenu = this.$pgettext('Sidebar/*/Hidden text', 'Main menu')
      const selectTrack = this.$pgettext('Sidebar/Player/Hidden text', 'Play this track')
      const pendingFollows = this.$pgettext('Sidebar/Notifications/Hidden text', 'Pending follow requests')
      const pendingReviewEdits = this.$pgettext('Sidebar/Moderation/Hidden text', 'Pending review edits')
      const language = this.$pgettext(
        'Sidebar/Settings/Dropdown.Label/Short, Verb',
        'Language')
      const theme = this.$pgettext(
        'Sidebar/Settings/Dropdown.Label/Short, Verb',
        'Theme')
      return {
        pendingFollows,
        mainMenu,
        selectTrack,
        pendingReviewEdits,
        language,
        theme,
        addContent: this.$pgettext('*/Library/*/Verb', 'Add content'),
        administration: this.$pgettext('Sidebar/Admin/Title/Noun', 'Administration')
      }
    },
    logoUrl () {
      if (this.$store.state.auth.authenticated) {
        return 'library.index'
      } else {
        return 'index'
      }
    },
    focusedMenu () {
      const mapping = {
        search: 'exploreExpanded',
        'library.index': 'exploreExpanded',
        'library.podcasts.browse': 'exploreExpanded',
        'library.albums.browse': 'exploreExpanded',
        'library.albums.detail': 'exploreExpanded',
        'library.artists.browse': 'exploreExpanded',
        'library.artists.detail': 'exploreExpanded',
        'library.tracks.detail': 'exploreExpanded',
        'library.playlists.browse': 'exploreExpanded',
        'library.playlists.detail': 'exploreExpanded',
        'library.radios.browse': 'exploreExpanded',
        'library.radios.detail': 'exploreExpanded',
        'library.me': 'myLibraryExpanded',
        'library.albums.me': 'myLibraryExpanded',
        'library.artists.me': 'myLibraryExpanded',
        'library.playlists.me': 'myLibraryExpanded',
        'library.radios.me': 'myLibraryExpanded',
        favorites: 'myLibraryExpanded'
      }
      const m = mapping[this.$route.name]
      if (m) {
        return m
      }

      if (this.$store.state.auth.authenticated) {
        return 'myLibraryExpanded'
      } else {
        return 'exploreExpanded'
      }
    },
    moderationNotifications () {
      return (
        this.$store.state.ui.notifications.pendingReviewEdits +
        this.$store.state.ui.notifications.pendingReviewReports +
        this.$store.state.ui.notifications.pendingReviewRequests
      )
    },
    production () {
      return import.meta.env.PROD
    }
  },
  watch: {
    url: function () {
      this.isCollapsed = true
    },
    '$store.state.moderation.lastUpdate': function () {
      this.applyContentFilters()
    },
    '$store.state.auth.authenticated': {
      immediate: true,
      handler (v) {
        if (v) {
          this.$nextTick(() => {
            this.setupDropdown('.user-dropdown')
            this.setupDropdown('.admin-dropdown')
          })
        } else {
          this.$nextTick(() => {
            this.setupDropdown('.user-dropdown')
          })
        }
      }
    },
    '$store.state.auth.availablePermissions': {
      immediate: true,
      handler (v) {
        this.$nextTick(() => {
          this.setupDropdown('.admin-dropdown')
        })
      },
      deep: true
    },
    focusedMenu: {
      immediate: true,
      handler (n) {
        if (n) {
          this[n] = true
        }
      }
    },
    myLibraryExpanded (v) {
      if (v) {
        this.exploreExpanded = false
      }
    },
    exploreExpanded (v) {
      if (v) {
        this.myLibraryExpanded = false
      }
    },
    languageSelection: function (v) {
      this.$store.dispatch('ui/currentLanguage', v)
      this.$refs.languageModal.closeModal()
    }
  },
  mounted () {
    this.$nextTick(() => {
      document.getElementById('fake-sidebar').classList.add('loaded')
    })
  },
  methods: {
    ...mapActions({
      cleanTrack: 'queue/cleanTrack'
    }),
    applyContentFilters () {
      const artistIds = this.$store.getters['moderation/artistFilters']().map((f) => {
        return f.target.id
      })

      if (artistIds.length === 0) {
        return
      }
      const self = this
      const tracks = this.tracks.slice().reverse()
      tracks.forEach(async (t, i) => {
        // we loop from the end because removing index from the start can lead to removing the wrong tracks
        const realIndex = tracks.length - i - 1
        const matchArtist = artistIds.indexOf(t.artist.id) > -1
        if (matchArtist) {
          return await self.cleanTrack(realIndex)
        }
        if (t.album && artistIds.indexOf(t.album.artist.id) > -1) {
          return await self.cleanTrack(realIndex)
        }
      })
    },
    setupDropdown (selector) {
      const self = this
      $(self.$el).find(selector).dropdown({
        selectOnKeydown: false,
        action: function (text, value, $el) {
          // used ton ensure focusing the dropdown and clicking via keyboard
          // works as expected
          const link = $($el).closest('a')
          const url = link.attr('href')
          if (url) {
            if (url.startsWith('http')) {
              window.open(url, '_blank').focus()
            } else {
              self.$router.push(url)
            }
          }

          $(self.$el).find(selector).dropdown('hide')
        }
      })
    }
  }
}
</script>
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
