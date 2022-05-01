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
                  v-for="(part, key) in field.diff"
                  v-if="!part.added"
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
                  v-for="(part, key) in field.diff"
                  v-if="!part.removed"
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

import edits from '~/edits.js'

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
  data () {
    return {
      isLoading: false
    }
  },
  computed: {
    configs: edits.getConfigs,
    canApprove: edits.getCanApprove,
    canDelete: edits.getCanDelete,
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
      return fields.map((f) => {
        const fieldConfig = edits.getFieldConfig(self.configs, this.obj.target.type, f)
        const dummyRepr = (v) => { return v }
        const getValueRepr = fieldConfig.getValueRepr || dummyRepr
        const d = {
          id: f,
          config: fieldConfig
        }
        if (previousState && previousState[f]) {
          d.old = previousState[f]
          d.oldRepr = castValue(getValueRepr(d.old.value))
        }
        d.new = payload[f]
        d.newRepr = castValue(getValueRepr(d.new))
        if (d.old) {
          // we compute the diffs between the old and new values
          d.diff = diffWordsWithSpace(d.oldRepr, d.newRepr)
        }
        return d
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
