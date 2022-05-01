<template>
  <main v-title="labels.title">
    <div class="ui vertical stripe segment container">
      <div
        v-if="isLoading"
        class="ui centered active inline loader"
      />
      <div
        v-else-if="object"
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
                v-if="object.actor.domain != $store.getters['instance/domain']"
                :href="object.fid"
                target="_blank"
                class="basic item"
              >
                <i class="external icon" />
                <translate
                  :translate-params="{domain: object.actor.domain}"
                  translate-context="Content/*/Button.Label/Verb"
                >View on %{ domain }</translate>
              </a>
              <div
                v-for="obj in getReportableObjs({library: object})"
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
                :to="{name: 'manage.library.libraries.detail', params: {id: object.uuid}}"
              >
                <i class="wrench icon" />
                <translate translate-context="Content/Moderation/Link">
                  Open in moderation interface
                </translate>
              </router-link>
            </div>
          </button>
          <h1 class="ui header">
            <div class="ui hidden divider" />
            <div class="ellipsis content">
              <i class="layer group small icon" />
              <span>{{ object.name }}</span>
              <div class="ui very small hidden divider" />
              <div
                class="sub header ellipsis"
                :title="object.full_username"
              >
                <actor-link
                  :avatar="false"
                  :actor="object.actor"
                  :truncate-length="0"
                >
                  <translate
                    translate-context="*/*/*"
                    :translate-params="{username: object.actor.full_username}"
                  >
                    Owned by %{ username }
                  </translate>
                </actor-link>
              </div>
            </div>
          </h1>
          <p>
            <span
              v-if="object.privacy_level === 'me'"
              :title="labels.tooltips.me"
            >
              <i class="lock icon" />
              {{ labels.visibility.me }}
            </span>
            <span
              v-else-if="object.privacy_level === 'instance'"
              :title="labels.tooltips.instance"
            >
              <i class="lock open icon" />
              {{ labels.visibility.instance }}
            </span>
            <span
              v-else-if="object.privacy_level === 'everyone'"
              :title="labels.tooltips.everyone"
            >
              <i class="globe icon" />
              {{ labels.visibility.everyone }}
            </span> ·
            <i class="music icon" />
            <translate
              translate-context="*/*/*"
              :translate-params="{count: object.uploads_count}"
              :translate-n="object.uploads_count"
              translate-plural="%{ count } tracks"
            >
              %{ count } track
            </translate>
            <span v-if="object.size">
              · <i class="database icon" />
              {{ humanSize(object.size) }}
            </span>
          </p>

          <div class="header-buttons">
            <div class="ui small buttons">
              <radio-button
                :disabled="!isPlayable"
                type="library"
                :object-id="object.uuid"
              />
            </div>
            <div
              v-if="!isOwner"
              class="ui small buttons"
            >
              <library-follow-button
                v-if="$store.state.auth.authenticated"
                :library="object"
              />
            </div>
          </div>

          <template v-if="$store.getters['ui/layoutVersion'] === 'large'">
            <rendered-description
              :content="object.description ? {html: object.description} : null"
              :update-url="`channels/${object.uuid}/`"
              :can-update="false"
            />
            <div class="ui hidden divider" />
          </template>
          <div class="ui form">
            <div class="field">
              <label for="copy-input">
                <translate translate-context="Content/Library/Title">Sharing link</translate>
              </label>
              <p>
                <translate translate-context="Content/Library/Paragraph">
                  Share this link with other users so they can request access to this library by copy-pasting it in their pod search bar.
                </translate>
              </p>
              <copy-input :value="object.fid" />
            </div>
          </div>
        </div>
        <div class="ui eleven wide column">
          <div class="ui head vertical stripe segment">
            <div class="ui container">
              <div class="ui secondary pointing center aligned menu">
                <router-link
                  class="item"

                  :to="{name: 'library.detail'}"
                >
                  <translate translate-context="*/*/*">
                    Artists
                  </translate>
                </router-link>
                <router-link
                  class="item"

                  :to="{name: 'library.detail.albums'}"
                >
                  <translate translate-context="*/*/*">
                    Albums
                  </translate>
                </router-link>
                <router-link
                  class="item"

                  :to="{name: 'library.detail.tracks'}"
                >
                  <translate translate-context="*/*/*">
                    Tracks
                  </translate>
                </router-link>
                <router-link
                  v-if="isOwner"
                  class="item"

                  :to="{name: 'library.detail.upload'}"
                >
                  <i class="upload icon" />
                  <translate translate-context="Content/Library/Card.Button.Label/Verb">
                    Upload
                  </translate>
                </router-link>
                <router-link
                  v-if="isOwner"
                  class="item"

                  :to="{name: 'library.detail.edit'}"
                >
                  <i class="pencil icon" />
                  <translate translate-context="Content/*/Button.Label/Verb">
                    Edit
                  </translate>
                </router-link>
              </div>
              <div class="ui hidden divider" />
              <router-view
                :is-owner="isOwner"
                :object="object"
                @updated="fetchData"
                @uploads-finished="object.uploads_count += $event"
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
import LibraryFollowButton from '~/components/audio/LibraryFollowButton.vue'
import ReportMixin from '~/components/mixins/Report.vue'
import RadioButton from '~/components/radios/Button.vue'
import { humanSize } from '~/utils/filters'

export default {
  components: {
    RadioButton,
    LibraryFollowButton
  },
  mixins: [ReportMixin],
  beforeRouteUpdate (to, from, next) {
    to.meta.preserveScrollPosition = true
    next()
  },
  props: { id: { type: String, required: true } },
  setup () {
    return { humanSize }
  },
  data () {
    return {
      isLoading: true,
      object: null,
      latestTracks: null
    }
  },
  computed: {
    isOwner () {
      return this.$store.state.auth.authenticated && this.object.actor.full_username === this.$store.state.auth.fullUsername
    },
    labels () {
      return {
        title: this.$pgettext('*/*/*', 'Library'),
        visibility: {
          me: this.$pgettext('Content/Library/Card.Help text', 'Private'),
          instance: this.$pgettext('Content/Library/Card.Help text', 'Restricted'),
          everyone: this.$pgettext('Content/Library/Card.Help text', 'Public')
        },
        tooltips: {
          me: this.$pgettext('Content/Library/Card.Help text', 'This library is private and your approval from its owner is needed to access its content'),
          instance: this.$pgettext('Content/Library/Card.Help text', 'This library is restricted to users on this pod only'),
          everyone: this.$pgettext('Content/Library/Card.Help text', 'This library is public and you can access its content freely')
        }
      }
    },
    isPlayable () {
      return this.object.uploads_count > 0 && (
        this.isOwner ||
        this.object.privacy_level === 'everyone' ||
        (this.object.privacy_level === 'instance' && this.$store.state.auth.authenticated && this.object.actor.domain === this.$store.getters['instance/domain']) ||
        (this.$store.getters['libraries/follow'](this.object.uuid) || {}).approved === true
      )
    }
  },
  watch: {
    id () {
      this.fetchData()
    }
  },
  async created () {
    await this.fetchData()
    const authenticated = this.$store.state.auth.authenticated
    if (!authenticated && this.$store.getters['instance/domain'] !== this.object.actor.domain) {
      this.$router.push({ name: 'login', query: { next: this.$route.fullPath } })
    }
  },
  methods: {
    async fetchData () {
      const self = this
      this.isLoading = true
      const libraryPromise = axios.get(`libraries/${this.id}`).then(response => {
        self.object = response.data
      })
      await libraryPromise
      self.isLoading = false
    }
  }
}
</script>
