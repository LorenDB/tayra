<template>
  <main class="page-admin-domain-detail">
    <div
      v-if="isLoading"
      class="ui vertical segment"
    >
      <div :class="['ui', 'centered', 'active', 'inline', 'loader']" />
    </div>
    <template v-if="object">
      <section
        v-title="object.name"
        :class="['ui', 'head', 'vertical', 'stripe', 'segment']"
      >
        <div class="ui stackable two column grid">
          <div class="ui column">
            <div class="segment-content">
              <h2 class="ui header">
                <i class="circular inverted cloud icon" />
                <div class="content">
                  {{ object.name }}
                  <div class="sub header">
                    <a
                      :href="externalUrl"
                      target="_blank"
                      rel="noopener noreferrer"
                      class="logo-wrapper"
                    >
                      <translate translate-context="Content/Moderation/Link/Verb">Open website</translate>&nbsp;
                      <i class="external icon" />
                    </a>
                  </div>
                </div>
              </h2>
              <div class="header-buttons">
                <div class="ui icon buttons">
                  <a
                    v-if="$store.state.auth.profile.is_superuser"
                    class="ui labeled icon button"
                    :href="$store.getters['instance/absoluteUrl'](`/api/admin/federation/domain/${object.name}`)"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    <i class="wrench icon" />
                    <translate translate-context="Content/Moderation/Link/Verb">View in Django's admin</translate>&nbsp;
                  </a>
                </div>
                <div
                  v-if="allowListEnabled"
                  class="ui icon buttons"
                >
                  <button
                    v-if="object.allowed"
                    :class="['ui', 'labeled', {loading: isLoadingAllowList}, 'icon', 'button']"
                    @click.prevent="setAllowList(false)"
                  >
                    <i class="x icon" />
                    <translate translate-context="Content/Moderation/Action/Verb">
                      Remove from allow-list
                    </translate>
                  </button>
                  <button
                    v-else
                    :class="['ui', 'labeled', {loading: isLoadingAllowList}, 'icon', 'button']"
                    @click.prevent="setAllowList(true)"
                  >
                    <i class="check icon" />
                    <translate translate-context="Content/Moderation/Action/Verb">
                      Add to allow-list
                    </translate>
                  </button>
                </div>
              </div>
            </div>
          </div>
          <div class="ui column">
            <div class="ui compact clearing placeholder segment component-placeholder">
              <template v-if="isLoadingPolicy">
                <div class="paragraph">
                  <div class="line" />
                  <div class="line" />
                  <div class="line" />
                  <div class="line" />
                  <div class="line" />
                </div>
              </template>
              <template v-else-if="!policy && !showPolicyForm">
                <header class="ui header">
                  <h3>
                    <i class="shield icon" />
                    <translate translate-context="Content/Moderation/Card.Title">
                      You don't have any rule in place for this domain.
                    </translate>
                  </h3>
                </header>
                <p>
                  <translate translate-context="Content/Moderation/Card.Paragraph">
                    Moderation policies help you control how your instance interact with a given domain or account.
                  </translate>
                </p>
                <button
                  class="ui primary button"
                  @click="showPolicyForm = true"
                >
                  Add a moderation policy
                </button>
              </template>
              <instance-policy-card
                v-else-if="policy && !showPolicyForm"
                :object="policy"
                @update="showPolicyForm = true"
              >
                <header class="ui header">
                  <h3>
                    <translate translate-context="Content/Moderation/Card.Title">
                      This domain is subject to specific moderation rules
                    </translate>
                  </h3>
                </header>
              </instance-policy-card>
              <instance-policy-form
                v-else-if="showPolicyForm"
                :object="policy"
                type="domain"
                :target="object.name"
                @cancel="showPolicyForm = false"
                @save="updatePolicy"
                @delete="policy = null; showPolicyForm = false"
              />
            </div>
          </div>
        </div>
      </section>
      <div class="ui vertical stripe segment">
        <div class="ui stackable three column grid">
          <div class="column">
            <section>
              <h3 class="ui header">
                <i class="info icon" />
                <div class="content">
                  <translate translate-context="Content/Moderation/Title">
                    Instance data
                  </translate>
                </div>
              </h3>
              <table class="ui very basic table">
                <tbody>
                  <tr v-if="allowListEnabled">
                    <td>
                      <translate translate-context="Content/Moderation/*/Adjective">
                        Is present on allow-list
                      </translate>
                    </td>
                    <td>
                      <translate
                        v-if="object.allowed"
                        translate-context="*/*/*"
                      >
                        Yes
                      </translate>
                      <translate
                        v-else
                        translate-context="*/*/*"
                      >
                        No
                      </translate>
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <translate translate-context="Content/*/Table.Label">
                        Last checked
                      </translate>
                    </td>
                    <td>
                      <human-date
                        v-if="object.nodeinfo_fetch_date"
                        :date="object.nodeinfo_fetch_date"
                      />
                      <translate
                        v-else
                        translate-context="*/*/*"
                      >
                        N/A
                      </translate>
                    </td>
                  </tr>

                  <template v-if="object.nodeinfo && object.nodeinfo.status === 'ok'">
                    <tr>
                      <td>
                        <translate translate-context="Content/Moderation/Table.Label">
                          Software
                        </translate>
                      </td>
                      <td>
                        {{ get(object, 'nodeinfo.payload.software.name', $pgettext('*/*/*', 'N/A')) }} ({{ get(object, 'nodeinfo.payload.software.version', $pgettext('*/*/*', 'N/A')) }})
                      </td>
                    </tr>
                    <tr>
                      <td>
                        <translate translate-context="*/*/*/Noun">
                          Name
                        </translate>
                      </td>
                      <td>
                        {{ get(object, 'nodeinfo.payload.metadata.nodeName', $pgettext('*/*/*', 'N/A')) }}
                      </td>
                    </tr>
                    <tr>
                      <td>
                        <translate translate-context="Content/*/*">
                          Total users
                        </translate>
                      </td>
                      <td>
                        {{ get(object, 'nodeinfo.payload.usage.users.total', $pgettext('*/*/*', 'N/A')) }}
                      </td>
                    </tr>
                  </template>
                  <template v-if="object.nodeinfo && object.nodeinfo.status === 'error'">
                    <tr>
                      <td>
                        <translate translate-context="*/*/*">
                          Status
                        </translate>
                      </td>
                      <td>
                        <translate translate-context="Content/Moderation/Table">
                          Error while fetching node info
                        </translate>&nbsp;

                        <span :data-tooltip="object.nodeinfo.error"><i class="question circle icon" /></span>
                      </td>
                    </tr>
                  </template>
                </tbody>
              </table>
              <ajax-button
                method="get"
                :url="'manage/federation/domains/' + object.name + '/nodeinfo/'"
                @action-done="refreshNodeInfo"
              >
                <translate translate-context="Content/Moderation/Button.Label/Verb">
                  Refresh node info
                </translate>
              </ajax-button>
            </section>
          </div>
          <div class="column">
            <section>
              <h3 class="ui header">
                <i class="feed icon" />
                <div class="content">
                  <translate translate-context="Content/Moderation/Title">
                    Activity
                  </translate>&nbsp;
                  <span :data-tooltip="labels.statsWarning"><i class="question circle icon" /></span>
                </div>
              </h3>
              <div
                v-if="isLoadingStats"
                class="ui placeholder"
              >
                <div class="full line" />
                <div class="short line" />
                <div class="medium line" />
                <div class="long line" />
              </div>
              <table
                v-else
                class="ui very basic table"
              >
                <tbody>
                  <tr>
                    <td>
                      <translate translate-context="Content/Moderation/Table.Label/Short (Value is a date)">
                        First seen
                      </translate>
                    </td>
                    <td>
                      <human-date :date="object.creation_date" />
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link
                        :to="{name: 'manage.moderation.accounts.list', query: {q: 'domain:' + object.name }}"
                      >
                        <translate translate-context="Content/Moderation/Table.Label.Link">
                          Known accounts
                        </translate>
                      </router-link>
                    </td>
                    <td>
                      {{ stats.actors }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <translate translate-context="Content/Moderation/Table.Label/Noun">
                        Emitted messages
                      </translate>
                    </td>
                    <td>
                      {{ stats.outbox_activities }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <translate translate-context="Content/Moderation/Table.Label/Noun">
                        Received library follows
                      </translate>
                    </td>
                    <td>
                      {{ stats.received_library_follows }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <translate translate-context="Content/Moderation/Table.Label/Noun">
                        Emitted library follows
                      </translate>
                    </td>
                    <td>
                      {{ stats.emitted_library_follows }}
                    </td>
                  </tr>
                </tbody>
              </table>
            </section>
          </div>
          <div class="column">
            <section>
              <h3 class="ui header">
                <i class="music icon" />
                <div class="content">
                  <translate translate-context="Content/Moderation/Title">
                    Audio content
                  </translate>&nbsp;
                  <span :data-tooltip="labels.statsWarning"><i class="question circle icon" /></span>
                </div>
              </h3>
              <div
                v-if="isLoadingStats"
                class="ui placeholder"
              >
                <div class="full line" />
                <div class="short line" />
                <div class="medium line" />
                <div class="long line" />
              </div>
              <table
                v-else
                class="ui very basic table"
              >
                <tbody>
                  <tr>
                    <td>
                      <translate translate-context="Content/Moderation/Table.Label/Noun">
                        Cached size
                      </translate>
                    </td>
                    <td>
                      {{ stats.media_downloaded_size | humanSize }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <translate translate-context="Content/Moderation/Table.Label">
                        Total size
                      </translate>
                    </td>
                    <td>
                      {{ stats.media_total_size | humanSize }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.channels', query: {q: getQuery('domain', object.name) }}">
                        <translate translate-context="*/*/*">
                          Channels
                        </translate>
                      </router-link>
                    </td>
                    <td>
                      {{ stats.channels }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.libraries', query: {q: getQuery('domain', object.name) }}">
                        <translate translate-context="*/*/*/Noun">
                          Libraries
                        </translate>
                      </router-link>
                    </td>
                    <td>
                      {{ stats.libraries }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.uploads', query: {q: getQuery('domain', object.name) }}">
                        <translate translate-context="*/*/*">
                          Uploads
                        </translate>
                      </router-link>
                    </td>
                    <td>
                      {{ stats.uploads }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.artists', query: {q: getQuery('domain', object.name) }}">
                        <translate translate-context="*/*/*/Noun">
                          Artists
                        </translate>
                      </router-link>
                    </td>
                    <td>
                      {{ stats.artists }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.albums', query: {q: getQuery('domain', object.name) }}">
                        <translate translate-context="*/*/*">
                          Albums
                        </translate>
                      </router-link>
                    </td>
                    <td>
                      {{ stats.albums }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.tracks', query: {q: getQuery('domain', object.name) }}">
                        <translate translate-context="*/*/*">
                          Tracks
                        </translate>
                      </router-link>
                    </td>
                    <td>
                      {{ stats.tracks }}
                    </td>
                  </tr>
                </tbody>
              </table>
            </section>
          </div>
        </div>
      </div>
    </template>
  </main>
</template>

<script>
import axios from 'axios'
import { get } from 'lodash-es'

import InstancePolicyForm from '~/components/manage/moderation/InstancePolicyForm.vue'
import InstancePolicyCard from '~/components/manage/moderation/InstancePolicyCard.vue'

export default {
  components: {
    InstancePolicyForm,
    InstancePolicyCard
  },
  props: { id: { type: String, required: true }, allowListEnabled: { type: Boolean, required: true } },
  data () {
    return {
      get,
      isLoading: true,
      isLoadingStats: false,
      isLoadingPolicy: false,
      isLoadingAllowList: false,
      policy: null,
      object: null,
      stats: null,
      showPolicyForm: false,
      permissions: []
    }
  },
  computed: {
    labels () {
      return {
        statsWarning: this.$pgettext('Content/Moderation/Help text', 'Statistics are computed from known activity and content on your instance, and do not reflect general activity for this domain')
      }
    },
    externalUrl () {
      return `https://${this.object.name}`
    }
  },
  created () {
    this.fetchData()
    this.fetchStats()
  },
  methods: {
    fetchData () {
      const self = this
      this.isLoading = true
      const url = 'manage/federation/domains/' + this.id + '/'
      axios.get(url).then(response => {
        self.object = response.data
        self.isLoading = false
        if (self.object.instance_policy) {
          self.fetchPolicy(self.object.instance_policy)
        }
      })
    },
    fetchStats () {
      const self = this
      this.isLoadingStats = true
      const url = 'manage/federation/domains/' + this.id + '/stats/'
      axios.get(url).then(response => {
        self.stats = response.data
        self.isLoadingStats = false
      })
    },
    fetchPolicy (id) {
      const self = this
      this.isLoadingPolicy = true
      const url = `manage/moderation/instance-policies/${id}/`
      axios.get(url).then(response => {
        self.policy = response.data
        self.isLoadingPolicy = false
      })
    },
    setAllowList (value) {
      const self = this
      this.isLoadingAllowList = true
      const url = `manage/federation/domains/${this.id}/`
      axios.patch(url, { allowed: value }).then(response => {
        self.object = response.data
        self.isLoadingAllowList = false
      })
    },
    refreshNodeInfo (data) {
      this.object.nodeinfo = data
      this.object.nodeinfo_fetch_date = new Date()
    },
    updatePolicy (policy) {
      this.policy = policy
      this.showPolicyForm = false
    },
    getQuery (field, value) {
      return `${field}:"${value}"`
    }
  }
}
</script>
