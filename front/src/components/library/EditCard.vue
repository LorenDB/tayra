<template>
  <div class="ui fluid card">
    <div class="content">
      <h4 class="header">
        <router-link :to="detailUrl">
          <translate
            translate-context="Content/Library/Card/Short"
            :translate-params="{id: obj.uuid.substring(0, 8)}"
          >
            Modification %{ id }
          </translate>
        </router-link>
      </h4>
      <div class="meta">
        <router-link
          v-if="obj.target && obj.target.type === 'track'"
          :to="{name: 'library.tracks.detail', params: {id: obj.target.id }}"
        >
          <i class="music icon" />
          <translate
            translate-context="Content/Library/Card/Short"
            :translate-params="{id: obj.target.id, name: obj.target.repr}"
          >
            Track #%{ id } - %{ name }
          </translate>
        </router-link>
        <br>
        <human-date
          :date="obj.creation_date"
          :icon="true"
        />

        <span class="right floated">
          <span v-if="obj.is_approved && obj.is_applied">
            <i class="success check icon" />
            <translate translate-context="Content/Library/Card/Short">Approved and applied</translate>
          </span>
          <span v-else-if="obj.is_approved">
            <i class="success check icon" />
            <translate translate-context="Content/*/*/Short">Approved</translate>
          </span>
          <span v-else-if="obj.is_approved === null">
            <i class="warning hourglass icon" />
            <translate translate-context="Content/Admin/*/Noun">Pending review</translate>
          </span>
          <span v-else-if="obj.is_approved === false">
            <i class="danger x icon" />
            <translate translate-context="Content/Library/*/Short">Rejected</translate>
          </span>
        </span>
      </div>
    </div>
    <div
      v-if="obj.summary"
      class="content"
    >
      {{ obj.summary }}
    </div>
    <div class="content">
      <table
        v-if="obj.type === 'update'"
        class="ui celled very basic fixed stacking table"
      >
        <thead>
          <tr>
            <th>
              <translate translate-context="Content/Library/Card.Table.Header/Short">
                Field
              </translate>
            </th>
            <th>
              <translate translate-context="Content/Library/Card.Table.Header/Short">
                Old value
              </translate>
            </th>
            <th>
              <translate translate-context="Content/Library/Card.Table.Header/Short">
                New value
              </translate>
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="field in updatedFields"
            :key="field.id"
          >
            <td>{{ field.id }}</td>

            <td v-if="field.diff">
              <template v-if="field.config.type === 'attachment' && field.oldRepr">
                <img
                  class="ui image"
                  alt=""
                  :src="$store.getters['instance/absoluteUrl'](`api/v1/attachments/${field.oldRepr}/proxy?next=medium_square_crop`)"
                >
              </template>
              <template v-else>
                <span
                  v-for="(part, key) in field.diff.filter(p => !p.added)"
                  :key="key"
                  :class="['diff', {removed: part.removed}]"
                >
                  {{ part.value }}
                </span>
              </template>
            </td>
            <td v-else>
              <translate translate-context="*/*/*">
                N/A
              </translate>
            </td>

            <td
              v-if="field.diff"
              :title="field.newRepr"
            >
              <template v-if="field.config.type === 'attachment' && field.newRepr">
                <img
                  class="ui image"
                  alt=""
                  :src="$store.getters['instance/absoluteUrl'](`api/v1/attachments/${field.newRepr}/proxy?next=medium_square_crop`)"
                >
              </template>
              <template v-else>
                <span
                  v-for="(part, key) in field.diff.filter(p => !p.removed)"
                  :key="key"
                  :class="['diff', {added: part.added}]"
                >
                  {{ part.value }}
                </span>
              </template>
            </td>
            <td
              v-else
              :title="field.newRepr"
            >
              <template v-if="field.config.type === 'attachment' && field.newRepr">
                <img
                  class="ui image"
                  alt=""
                  :src="$store.getters['instance/absoluteUrl'](`api/v1/attachments/${field.newRepr}/proxy?next=medium_square_crop`)"
                >
              </template>
              <template v-else>
                {{ field.newRepr }}
              </template>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    <div
      v-if="obj.created_by"
      class="extra content"
    >
      <actor-link :actor="obj.created_by" />
    </div>
    <div
      v-if="canDelete || canApprove"
      class="ui bottom attached buttons"
    >
      <button
        v-if="canApprove && obj.is_approved !== true"
        :class="['ui', {loading: isLoading}, 'success', 'basic', 'button']"
        @click="approve(true)"
      >
        <translate translate-context="Content/*/Button.Label/Verb">
          Approve
        </translate>
      </button>
      <button
        v-if="canApprove && obj.is_approved === null"
        :class="['ui', {loading: isLoading}, 'warning', 'basic', 'button']"
        @click="approve(false)"
      >
        <translate translate-context="Content/Library/Button.Label">
          Reject
        </translate>
      </button>
      <dangerous-button
        v-if="canDelete"
        :class="['ui', {loading: isLoading}, 'basic danger button']"
        :action="remove"
      >
        <translate translate-context="*/*/*/Verb">
          Delete
        </translate>
        <template #modal-header>
          <p>
            <translate translate-context="Popup/Library/Title">
              Delete this suggestion?
            </translate>
          </p>
        </template>
        <template #modal-content>
          <div>
            <p>
              <translate translate-context="Popup/Library/Paragraph">
                The suggestion will be completely removed, this action is irreversible.
              </translate>
            </p>
          </div>
        </template>
        <template #modal-confirm>
          <p>
            <translate translate-context="*/*/*/Verb">
              Delete
            </translate>
          </p>
        </template>
      </dangerous-button>
    </div>
  </div>
</template>

<script>
import axios from 'axios'
import { diffWordsWithSpace } from 'diff'

import useEditConfigs from '~/composables/moderation/useEditConfigs'

function castValue (value) {
  if (value === null || value === undefined) {
    return ''
  }
  return String(value)
}

export default {
  props: {
    obj: { type: Object, required: true },
    currentState: { type: Object, required: false, default: function () { return { } } }
  },
  setup () {
    return { configs: useEditConfigs() }
  },
  data () {
    return {
      isLoading: false
    }
  },
  computed: {
    canApprove () {
      if (this.obj.is_applied) return false
      if (!this.$store.state.auth.authenticated) return false
      return this.$store.state.auth.availablePermissions.library
    },
    canDelete () {
      if (this.obj.is_applied || this.obj.is_approved) return false
      if (!this.$store.state.auth.authenticated) return false

      // TODO (wvffle): Is it better to compare ids? Is full_username unique?
      return this.obj.created_by.full_username === this.$store.state.auth.fullUsername
        || this.$store.state.auth.availablePermissions.library
    },
    previousState () {
      if (this.obj.is_applied) {
        // mutation was applied, we use the previous state that is stored
        // on the mutation itself
        return this.obj.previous_state
      }
      // mutation is not applied yet, so we use the current state that was
      // passed to the component, if any
      return this.currentState
    },
    detailUrl () {
      if (!this.obj.target) {
        return ''
      }
      let namespace
      const id = this.obj.target.id
      if (this.obj.target.type === 'track') {
        namespace = 'library.tracks.edit.detail'
      }
      if (this.obj.target.type === 'album') {
        namespace = 'library.albums.edit.detail'
      }
      if (this.obj.target.type === 'artist') {
        namespace = 'library.artists.edit.detail'
      }
      return this.$router.resolve({ name: namespace, params: { id, editId: this.obj.uuid } }).href
    },

    updatedFields () {
      if (!this.obj || !this.obj.target) {
        return []
      }
      const payload = this.obj.payload
      const previousState = this.previousState
      const fields = Object.keys(payload)
      const self = this

      return fields.map((field) => {
        const fieldConfig = this.configs[this.obj.target.type].fields.find(({ id }) => id === field)
        const getValueRepr = fieldConfig.getValueRepr || (v => v)
        const result = {
          id: field,
          config: fieldConfig
        }
        if (previousState?.[field]) {
          result.old = previousState[field]
          // TODO (wvffle): Originally it was using just result.old.value though for some reason it returns me the object as result.old now
          result.oldRepr = castValue(getValueRepr(result.old.value ?? result.old))
        }
        result.new = payload[field]
        result.newRepr = castValue(getValueRepr(result.new))
        if (result.old) {
          // we compute the diffs between the old and new values
          result.diff = diffWordsWithSpace(result.oldRepr, result.newRepr)
        }

        return result
      })
    }
  },
  methods: {
    remove () {
      const self = this
      this.isLoading = true
      axios.delete(`mutations/${this.obj.uuid}/`).then((response) => {
        self.$emit('deleted')
        self.isLoading = false
      }, () => {
        self.isLoading = false
      })
    },
    approve (approved) {
      let url
      if (approved) {
        url = `mutations/${this.obj.uuid}/approve/`
      } else {
        url = `mutations/${this.obj.uuid}/reject/`
      }
      const self = this
      this.isLoading = true
      axios.post(url).then((response) => {
        self.$emit('approved', approved)
        self.isLoading = false
        self.$store.commit('ui/incrementNotifications', { count: -1, type: 'pendingReviewEdits' })
      }, () => {
        self.isLoading = false
      })
    }
  }
}
</script>
