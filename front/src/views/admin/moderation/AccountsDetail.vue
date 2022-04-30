<template>
  <main class="page-admin-account-detail">
    <div
      v-if="isLoading"
      class="ui vertical segment"
    >
      <div :class="['ui', 'centered', 'active', 'inline', 'loader']" />
    </div>
    <template v-if="object">
      <section
        v-title="object.full_username"
        :class="['ui', 'head', 'vertical', 'stripe', 'segment']"
      >
        <div class="ui stackable two column grid">
          <div class="ui column">
            <div class="segment-content">
              <h2 class="ui header">
                <i class="circular inverted user icon" />
                <div class="content">
                  {{ object.full_username }}
                  <div class="sub header">
                    <template v-if="object.user">
                      <span class="ui tiny accent label">
                        <i class="home icon" />
                        <translate translate-context="Content/Moderation/*/Short, Noun">Local account</translate>
                      </span>
                      &nbsp;
                    </template>
                    <a
                      :href="object.url || object.fid"
                      target="_blank"
                      rel="noopener noreferrer"
                    >
                      <translate translate-context="Content/Moderation/Link/Verb">Open profile</translate>&nbsp;
                      <i class="external icon" />
                    </a>
                  </div>
                </div>
              </h2>
              <div class="header-buttons">
                <div class="ui icon buttons">
                  <a
                    v-if="object.user && $store.state.auth.profile && $store.state.auth.profile.is_superuser"
                    class="ui labeled icon button"
                    :href="$store.getters['instance/absoluteUrl'](`/api/admin/users/user/${object.user.id}`)"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    <i class="wrench icon" />
                    <translate translate-context="Content/Moderation/Link/Verb">View in Django's admin</translate>&nbsp;
                  </a>
                  <a
                    v-else-if="$store.state.auth.profile && $store.state.auth.profile.is_superuser"
                    class="ui labeled icon button"
                    :href="$store.getters['instance/absoluteUrl'](`/api/admin/federation/actor/${object.id}`)"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    <i class="wrench icon" />
                    <translate translate-context="Content/Moderation/Link/Verb">View in Django's admin</translate>&nbsp;
                  </a>
                  <button
                    v-dropdown
                    class="ui floating dropdown icon button"
                  >
                    <i class="dropdown icon" />
                    <div class="menu">
                      <a
                        class="basic item"
                        :href="object.url || object.fid"
                        target="_blank"
                        rel="noopener noreferrer"
                      >
                        <i class="external icon" />
                        <translate translate-context="Content/Moderation/Link/Verb">Open remote profile</translate>&nbsp;
                      </a>
                    </div>
                  </button>
                </div>
              </div>
            </div>
          </div>
          <div class="ui column">
            <div
              v-if="!object.user"
              class="ui compact clearing placeholder segment component-placeholder"
            >
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
                      You don't have any rule in place for this account.
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
                  <translate translate-context="Content/Moderation/Button/Verb">
                    Add a moderation policy
                  </translate>
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
                type="actor"
                :target="object.full_username"
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
                    Account data
                  </translate>
                </div>
              </h3>
              <table class="ui very basic table">
                <tbody>
                  <tr>
                    <td>
                      <translate translate-context="Content/*/*">
                        Username
                      </translate>
                    </td>
                    <td>
                      {{ object.preferred_username }}
                    </td>
                  </tr>
                  <tr v-if="!object.user">
                    <td>
                      <router-link :to="{name: 'manage.moderation.domains.detail', params: {id: object.domain }}">
                        <translate translate-context="Content/Moderation/*/Noun">
                          Domain
                        </translate>
                      </router-link>
                    </td>
                    <td>
                      {{ object.domain }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <translate translate-context="'Content/*/*/Noun'">
                        Display name
                      </translate>
                    </td>
                    <td>
                      {{ object.name }}
                    </td>
                  </tr>
                  <tr v-if="object.user">
                    <td>
                      <translate translate-context="Content/*/*">
                        Email address
                      </translate>
                    </td>
                    <td>
                      {{ object.user.email }}
                    </td>
                  </tr>
                  <tr v-if="object.user">
                    <td>
                      <translate translate-context="Content/*/*/Noun">
                        Login status
                      </translate>
                    </td>
                    <td>
                      <div
                        v-if="object.user.username != $store.state.auth.profile.username"
                        class="ui toggle checkbox"
                      >
                        <input
                          id="is-active"
                          v-model="object.user.is_active"
                          type="checkbox"
                          @change="updateUser('is_active')"
                        >
                        <label for="is-active">
                          <translate
                            v-if="object.user.is_active"
                            key="1"
                            translate-context="*/*/*/State of feature"
                          >Enabled</translate>
                          <translate
                            v-else
                            key="2"
                            translate-context="*/*/*/State of feature"
                          >Disabled</translate>
                        </label>
                      </div>
                      <translate
                        v-else-if="object.user.is_active"
                        key="1"
                        translate-context="*/*/*/State of feature"
                      >
                        Enabled
                      </translate>
                      <translate
                        v-else
                        key="2"
                        translate-context="*/*/*/State of feature"
                      >
                        Disabled
                      </translate>
                    </td>
                  </tr>
                  <tr v-if="object.user">
                    <td>
                      <translate translate-context="Content/*/*/Noun">
                        Permissions
                      </translate>
                    </td>
                    <td>
                      <select
                        v-model="permissions"
                        multiple
                        class="ui search selection dropdown"
                        @change="updateUser('permissions')"
                      >
                        <option
                          v-for="(p, key) in allPermissions"
                          :key="key"
                          :value="p.code"
                        >
                          {{ p.label }}
                        </option>
                      </select>
                      <action-feedback :is-loading="updating.permissions" />
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <translate translate-context="Content/Track/Table.Label/Noun">
                        Type
                      </translate>
                    </td>
                    <td>
                      {{ object.type }}
                    </td>
                  </tr>
                  <tr v-if="!object.user">
                    <td>
                      <translate translate-context="Content/*/Table.Label">
                        Last checked
                      </translate>
                    </td>
                    <td>
                      <human-date
                        v-if="object.last_fetch_date"
                        :date="object.last_fetch_date"
                      />
                      <translate
                        v-else
                        translate-context="*/*/*"
                      >
                        N/A
                      </translate>
                    </td>
                  </tr>
                  <tr v-if="object.user">
                    <td>
                      <translate translate-context="Content/Admin/Table.Label/Noun">
                        Sign-up date
                      </translate>
                    </td>
                    <td>
                      <human-date :date="object.user.date_joined" />
                    </td>
                  </tr>
                  <tr v-if="object.user">
                    <td>
                      <translate translate-context="Content/Profile/Table.Label/Short, Noun (Value is a date)">
                        Last activity
                      </translate>
                    </td>
                    <td>
                      <human-date :date="object.user.last_activity" />
                    </td>
                  </tr>
                </tbody>
              </table>
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
                  <tr v-if="!object.user">
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
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.moderation.reports.list', query: {q: getQuery('target', `account:${object.full_username}`) }}">
                        <translate translate-context="Content/Moderation/Table.Label/Noun">
                          Linked reports
                        </translate>
                      </router-link>
                    </td>
                    <td>
                      {{ stats.reports }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.moderation.requests.list', query: {q: getQuery('submitter', `${object.full_username}`) }}">
                        <translate translate-context="Content/Moderation/Table.Label/Noun">
                          Requests
                        </translate>
                      </router-link>
                    </td>
                    <td>
                      {{ stats.requests }}
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
                  <tr v-if="!object.user">
                    <td>
                      <translate translate-context="Content/Moderation/Table.Label/Noun">
                        Cached size
                      </translate>
                    </td>
                    <td>
                      {{ stats.media_downloaded_size | humanSize }}
                    </td>
                  </tr>
                  <tr v-if="object.user">
                    <td>
                      <translate translate-context="*/*/*">
                        Upload quota
                      </translate>
                      <span :data-tooltip="labels.uploadQuota"><i class="question circle icon" /></span>
                    </td>
                    <td>
                      <div class="ui right labeled input">
                        <input
                          v-model.number="object.user.upload_quota"
                          step="100"
                          name="quota"
                          type="number"
                          @change="updateUser('upload_quota', true)"
                        >
                        <div class="ui basic label">
                          <translate translate-context="Content/*/*/Unit">
                            MB
                          </translate>&#32;
                        </div>
                        <action-feedback
                          class="ui basic label"
                          size="tiny"
                          :is-loading="updating.upload_quota"
                        />
                      </div>
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
                      <router-link :to="{name: 'manage.channels', query: {q: getQuery('account', object.full_username) }}">
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
                      <router-link :to="{name: 'manage.library.libraries', query: {q: getQuery('account', object.full_username) }}">
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
                      <router-link :to="{name: 'manage.library.uploads', query: {q: getQuery('account', object.full_username) }}">
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
                      <translate translate-context="*/*/*/Noun">
                        Artists
                      </translate>
                    </td>
                    <td>
                      {{ stats.artists }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <translate translate-context="*/*/*">
                        Albums
                      </translate>
                    </td>
                    <td>
                      {{ stats.albums }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <translate translate-context="*/*/*">
                        Tracks
                      </translate>
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
import $ from 'jquery'

import InstancePolicyForm from '~/components/manage/moderation/InstancePolicyForm.vue'
import InstancePolicyCard from '~/components/manage/moderation/InstancePolicyCard.vue'
import useLogger from '~/composables/useLogger'

const logger = useLogger()

export default {
  components: {
    InstancePolicyForm,
    InstancePolicyCard
  },
  props: { id: { type: Number, required: true } },
  data () {
    return {
      isLoading: true,
      isLoadingStats: false,
      isLoadingPolicy: false,
      object: null,
      stats: null,
      showPolicyForm: false,
      permissions: [],
      updating: {
        permissions: false,
        upload_quota: false
      }
    }
  },
  computed: {
    labels () {
      return {
        statsWarning: this.$pgettext('Content/Moderation/Help text', 'Statistics are computed from known activity and content on your instance, and do not reflect general activity for this account'),
        uploadQuota: this.$pgettext('Content/Moderation/Help text', 'Determine how much content the user can upload. Leave empty to use the default value of the instance.')
      }
    },
    allPermissions () {
      return [
        {
          code: 'library',
          label: this.$pgettext('*/*/*/Noun', 'Library')
        },
        {
          code: 'moderation',
          label: this.$pgettext('*/Moderation/*', 'Moderation')
        },
        {
          code: 'settings',
          label: this.$pgettext('*/*/*/Noun', 'Settings')
        }
      ]
    }
  },
  watch: {
    object () {
      this.$nextTick(() => {
        $(this.$el).find('select.dropdown').dropdown()
      })
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
      const url = 'manage/accounts/' + this.id + '/'
      axios.get(url).then(response => {
        self.object = response.data
        self.isLoading = false
        if (self.object.instance_policy) {
          self.fetchPolicy(self.object.instance_policy)
        }
        if (response.data.user) {
          self.allPermissions.forEach(p => {
            if (self.object.user.permissions[p.code]) {
              self.permissions.push(p.code)
            }
          })
        }
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
    fetchStats () {
      const self = this
      this.isLoadingStats = true
      const url = 'manage/accounts/' + this.id + '/stats/'
      axios.get(url).then(response => {
        self.stats = response.data
        self.isLoadingStats = false
      })
    },
    refreshNodeInfo (data) {
      this.object.nodeinfo = data
      this.object.nodeinfo_fetch_date = new Date()
    },

    updateUser (attr, toNull) {
      let newValue = this.object.user[attr]
      if (toNull && !newValue) {
        newValue = null
      }
      const self = this
      this.updating[attr] = true
      const params = {}
      if (attr === 'permissions') {
        params.permissions = {}
        this.allPermissions.forEach(p => {
          params.permissions[p.code] = this.permissions.indexOf(p.code) > -1
        })
      } else {
        params[attr] = newValue
      }
      axios.patch(`manage/users/users/${this.object.user.id}/`, params).then(
        response => {
          logger.info(
            `${attr} was updated succcessfully to ${newValue}`
          )
          self.updating[attr] = false
        },
        error => {
          logger.error(
            `Error while setting ${attr} to ${newValue}`,
            error
          )
          self.updating[attr] = false
        }
      )
    },
    getQuery (field, value) {
      return `${field}:"${value}"`
    }
  }
}
</script>
