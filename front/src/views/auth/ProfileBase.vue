<template>
  <main
    v-title="labels.usernameProfile"
    class="main pusher page-profile"
  >
    <div
      v-if="isLoading"
      class="ui vertical segment"
    >
      <div class="ui centered active inline loader" />
    </div>
    <div class="ui head vertical stripe segment container">
      <div
        v-if="object"
        class="ui stackable grid"
      >
        <div class="ui five wide column">
          <button
            ref="dropdown"
            v-dropdown="{direction: 'downward'}"
            class="ui pointing dropdown icon small basic right floated button"
            style="position: absolute; right: 1em; top: 1em;"
          >
            <i class="ellipsis vertical icon" />
            <div class="menu">
              <a
                v-if="object.domain != $store.getters['instance/domain']"
                :href="object.fid"
                target="_blank"
                class="basic item"
              >
                <i class="external icon" />
                <translate
                  :translate-params="{domain: object.domain}"
                  translate-context="Content/*/Button.Label/Verb"
                >View on %{ domain }</translate>
              </a>
              <div
                v-for="obj in getReportableObjs({account: object})"
                :key="obj.target.type + obj.target.id"
                role="button"
                class="basic item"
                @click.stop.prevent="$store.dispatch('moderation/report', obj.target)"
              >
                <i class="share icon" /> {{ obj.label }}
              </div>

              <div class="divider" />
              <router-link
                v-if="$store.state.auth.availablePermissions['moderation']"
                class="basic item"
                :to="{name: 'manage.moderation.accounts.detail', params: {id: object.full_username}}"
              >
                <i class="wrench icon" />
                <translate translate-context="Content/Moderation/Link">
                  Open in moderation interface
                </translate>
              </router-link>
            </div>
          </button>
          <h1 class="ui center aligned icon header">
            <i
              v-if="!object.icon"
              class="circular inverted user success icon"
            />
            <img
              v-else
              v-lazy="$store.getters['instance/absoluteUrl'](object.icon.urls.medium_square_crop)"
              alt=""
              class="ui big circular image"
            >
            <div class="ellispsis content">
              <div class="ui very small hidden divider" />
              <span>{{ displayName }}</span>
              <div class="ui very small hidden divider" />
              <div
                class="sub header ellipsis"
                :title="object.full_username"
              >
                {{ object.full_username }}
              </div>
            </div>
            <template v-if="object.full_username === $store.state.auth.fullUsername">
              <div class="ui very small hidden divider" />
              <div class="ui basic success label">
                <translate translate-context="Content/Profile/Button.Paragraph">
                  This is you!
                </translate>
              </div>
            </template>
          </h1>
          <div class="ui small hidden divider" />
          <div v-if="$store.getters['ui/layoutVersion'] === 'large'">
            <rendered-description
              :content="object.summary"
              :field-name="'summary'"
              :update-url="`users/${$store.state.auth.username}/`"
              :can-update="$store.state.auth.authenticated && object.full_username === $store.state.auth.fullUsername"
              @updated="$emit('updated', $event)"
            />
          </div>
        </div>
        <div class="ui eleven wide column">
          <div class="ui head vertical stripe segment">
            <div class="ui container">
              <div class="ui secondary pointing center aligned menu">
                <router-link
                  class="item"
                  :to="{name: 'profile.overview', params: routerParams}"
                >
                  <translate translate-context="Content/Profile/Link">
                    Overview
                  </translate>
                </router-link>
                <router-link
                  class="item"
                  :to="{name: 'profile.activity', params: routerParams}"
                >
                  <translate translate-context="Content/Profile/*">
                    Activity
                  </translate>
                </router-link>
              </div>
              <div class="ui hidden divider" />
              <router-view
                :object="object"
                @updated="fetch"
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  </main>
</template>

<script>
import axios from 'axios'

import ReportMixin from '~/components/mixins/Report.vue'

export default {
  mixins: [ReportMixin],
  beforeRouteUpdate (to, from, next) {
    to.meta.preserveScrollPosition = true
    next()
  },
  props: {
    username: { type: String, required: true },
    domain: { type: String, required: false, default: null }
  },
  data () {
    return {
      object: null,
      isLoading: false
    }
  },
  computed: {
    labels () {
      const msg = this.$pgettext('Head/Profile/Title', "%{ username }'s profile")
      const usernameProfile = this.$gettextInterpolate(msg, {
        username: this.username
      })
      return {
        usernameProfile
      }
    },
    fullUsername () {
      if (this.username && this.domain) {
        return `${this.username}@${this.domain}`
      } else {
        return `${this.username}@${this.$store.getters['instance/domain']}`
      }
    },
    routerParams () {
      if (this.domain) {
        return { username: this.username, domain: this.domain }
      } else {
        return { username: this.username }
      }
    },
    displayName () {
      return this.object.name || this.object.preferred_username
    }
  },
  watch: {
    domain () {
      this.fetch()
    },
    username () {
      this.fetch()
    }
  },
  created () {
    const authenticated = this.$store.state.auth.authenticated
    if (!authenticated && this.domain && this.$store.getters['instance/domain'] !== this.domain) {
      this.$router.push({ name: 'login', query: { next: this.$route.fullPath } })
    } else {
      this.fetch()
    }
  },
  methods: {
    fetch () {
      const self = this
      self.object = null
      self.isLoading = true
      axios.get(`federation/actors/${this.fullUsername}/`).then((response) => {
        self.object = response.data
        self.isLoading = false
      })
    }
  }
}
</script>
