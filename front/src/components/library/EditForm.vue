<template>
  <div v-if="submittedMutation">
    <div class="ui positive message">
      <h4 class="header">
        <translate translate-context="Content/Library/Paragraph">
          Your edit was successfully submitted.
        </translate>
      </h4>
    </div>
    <edit-card
      :obj="submittedMutation"
      :current-state="currentState"
    />
    <button
      class="ui button"
      @click.prevent="submittedMutation = null"
    >
      <translate translate-context="Content/Library/Button.Label">
        Submit another edit
      </translate>
    </button>
  </div>
  <div v-else>
    <edit-list
      :filters="editListFilters"
      :url="mutationsUrl"
      :obj="object"
      :current-state="currentState"
    >
      <div>
        <template v-if="showPendingReview">
          <translate translate-context="Content/Library/Paragraph">
            Recent edits awaiting review
          </translate>
          <button
            class="ui tiny basic right floated button"
            @click.prevent="showPendingReview = false"
          >
            <translate translate-context="Content/Library/Button.Label">
              Show all edits
            </translate>
          </button>
        </template>
        <template v-else>
          <translate translate-context="Content/Library/Paragraph">
            Recent edits
          </translate>
          <button
            class="ui tiny basic right floated button"
            @click.prevent="showPendingReview = true"
          >
            <translate translate-context="Content/Library/Button.Label">
              Restrict to unreviewed edits
            </translate>
          </button>
        </template>
      </div>
      <template #empty-state>
        <empty-state>
          <translate translate-context="Content/Library/Paragraph">
            Suggest a change using the form below.
          </translate>
        </empty-state>
      </template>
    </edit-list>
    <form
      class="ui form"
      @submit.prevent="submit()"
    >
      <div class="ui hidden divider" />
      <div
        v-if="errors.length > 0"
        role="alert"
        class="ui negative message"
      >
        <h4 class="header">
          <translate translate-context="Content/Library/Error message.Title">
            Error while submitting edit
          </translate>
        </h4>
        <ul class="list">
          <li
            v-for="(error, key) in errors"
            :key="key"
          >
            {{ error }}
          </li>
        </ul>
      </div>
      <div
        v-if="!canEdit"
        class="ui message"
      >
        <translate translate-context="Content/Library/Paragraph">
          You don't have the permission to edit this object, but you can suggest changes. Once submitted, suggestions will be reviewed before approval.
        </translate>
      </div>
      <template v-if="values">
        <div
          v-for="fieldConfig in config.fields"
          :key="fieldConfig.id"
          class="ui field"
        >
          <template v-if="fieldConfig.type === 'text'">
            <label :for="fieldConfig.id">{{ fieldConfig.label }}</label>
            <input
              :id="fieldConfig.id"
              v-model="values[fieldConfig.id]"
              :type="fieldConfig.inputType || 'text'"
              :required="fieldConfig.required"
              :name="fieldConfig.id"
            >
          </template>
          <template v-else-if="fieldConfig.type === 'license'">
            <label :for="fieldConfig.id">{{ fieldConfig.label }}</label>

            <select
              :id="fieldConfig.id"
              ref="license"
              v-model="values[fieldConfig.id]"
              :required="fieldConfig.required"
              class="ui fluid search dropdown"
            >
              <option :value="null">
                <translate translate-context="*/*/*">
                  N/A
                </translate>
              </option>
              <option
                v-for="license in licenses"
                :key="license.code"
                :value="license.code"
              >
                {{ license.name }}
              </option>
            </select>
            <button
              class="ui tiny basic left floated button"
              form="noop"
              @click.prevent="values[fieldConfig.id] = null"
            >
              <i class="x icon" />
              <translate translate-context="Content/Library/Button.Label">
                Clear
              </translate>
            </button>
          </template>
          <template v-else-if="fieldConfig.type === 'content'">
            <label :for="fieldConfig.id">{{ fieldConfig.label }}</label>
            <content-form
              v-model="values[fieldConfig.id].text"
              :field-id="fieldConfig.id"
              :rows="3"
            />
          </template>
          <template v-else-if="fieldConfig.type === 'attachment'">
            <attachment-input
              :id="fieldConfig.id"
              v-model="values[fieldConfig.id]"
              :initial-value="initialValues[fieldConfig.id]"
              :required="fieldConfig.required"
              :name="fieldConfig.id"
              @delete="values[fieldConfig.id] = initialValues[fieldConfig.id]"
            >
              <span>{{ fieldConfig.label }}</span>
            </attachment-input>
          </template>
          <template v-else-if="fieldConfig.type === 'tags'">
            <label :for="fieldConfig.id">{{ fieldConfig.label }}</label>
            <tags-selector
              :id="fieldConfig.id"
              ref="tags"
              v-model="values[fieldConfig.id]"
              required="fieldConfig.required"
            />
            <button
              class="ui tiny basic left floated button"
              form="noop"
              @click.prevent="values[fieldConfig.id] = []"
            >
              <i class="x icon" />
              <translate translate-context="Content/Library/Button.Label">
                Clear
              </translate>
            </button>
          </template>
          <div v-if="fieldValuesChanged(fieldConfig.id)">
            <button
              class="ui tiny basic right floated reset button"
              form="noop"
              @click.prevent="resetField(fieldConfig.id)"
            >
              <i class="undo icon" />
              <translate translate-context="Content/Library/Button.Label">
                Reset to initial value
              </translate>
            </button>
          </div>
        </div>
      </template>
      <div class="field">
        <label for="summary"><translate translate-context="*/*/*">Summary (optional)</translate></label>
        <textarea
          id="change-summary"
          v-model="summary"
          name="change-summary"
          rows="3"
          :placeholder="labels.summaryPlaceholder"
        />
      </div>
      <router-link
        v-if="objectType === 'track'"
        class="ui left floated button"
        :to="{name: 'library.tracks.detail', params: {id: object.id }}"
      >
        <translate translate-context="*/*/Button.Label/Verb">
          Cancel
        </translate>
      </router-link>
      <button
        :class="['ui', {'loading': isLoading}, 'right', 'floated', 'success', 'button']"
        type="submit"
        :disabled="isLoading || !mutationPayload"
      >
        <translate
          v-if="canEdit"
          key="1"
          translate-context="Content/Library/Button.Label/Verb"
        >
          Submit and apply edit
        </translate>
        <translate
          v-else
          key="2"
          translate-context="Content/Library/Button.Label/Verb"
        >
          Submit suggestion
        </translate>
      </button>
    </form>
  </div>
</template>

<script>
import $ from 'jquery'
import { isEqual, clone } from 'lodash-es'
import axios from 'axios'
import AttachmentInput from '~/components/common/AttachmentInput.vue'
import EditList from '~/components/library/EditList.vue'
import EditCard from '~/components/library/EditCard.vue'
import TagsSelector from '~/components/library/TagsSelector.vue'
import edits from '~/edits.js'

export default {
  components: {
    EditList,
    EditCard,
    TagsSelector,
    AttachmentInput
  },
  props: {
    objectType: { type: String, required: true },
    object: { type: Object, required: true },
    licenses: { type: Array, required: true }
  },
  data () {
    return {
      isLoading: false,
      errors: [],
      values: {},
      initialValues: {},
      summary: '',
      submittedMutation: null,
      showPendingReview: true
    }
  },
  computed: {
    configs: edits.getConfigs,
    config: edits.getConfig,
    currentState: edits.getCurrentState,
    canEdit: edits.getCanEdit,
    labels () {
      return {
        summaryPlaceholder: this.$pgettext('*/*/Placeholder', 'A short summary describing your changes.')
      }
    },
    mutationsUrl () {
      if (this.objectType === 'track') {
        return `tracks/${this.object.id}/mutations/`
      }
      if (this.objectType === 'album') {
        return `albums/${this.object.id}/mutations/`
      }
      if (this.objectType === 'artist') {
        return `artists/${this.object.id}/mutations/`
      }
      return null
    },
    mutationPayload () {
      const self = this
      const changedFields = this.config.fields.filter(f => {
        return !isEqual(self.values[f.id], self.initialValues[f.id])
      })
      if (changedFields.length === 0) {
        return null
      }
      const payload = {
        type: 'update',
        payload: {},
        summary: this.summary
      }
      changedFields.forEach((f) => {
        payload.payload[f.id] = self.values[f.id]
      })
      return payload
    },
    editListFilters () {
      if (this.showPendingReview) {
        return { is_approved: 'null' }
      } else {
        return {}
      }
    }
  },
  watch: {
    'values.license' (newValue) {
      if (newValue === null) {
        $(this.$refs.license).dropdown('clear')
      } else {
        $(this.$refs.license).dropdown('set selected', newValue)
      }
    }
  },
  created () {
    this.setValues()
  },
  mounted () {
    $('.ui.dropdown').dropdown({ fullTextSearch: true })
  },

  methods: {
    setValues () {
      const self = this
      this.config.fields.forEach(f => {
        self.$set(self.values, f.id, clone(f.getValue(self.object)))
        self.$set(self.initialValues, f.id, clone(self.values[f.id]))
      })
    },
    submit () {
      const self = this
      self.isLoading = true
      self.errors = []
      const payload = clone(this.mutationPayload || {})
      if (this.canEdit) {
        payload.is_approved = true
      }
      return axios.post(this.mutationsUrl, payload).then(
        response => {
          self.isLoading = false
          self.submittedMutation = response.data
        },
        error => {
          self.errors = error.backendErrors
          self.isLoading = false
        }
      )
    },
    fieldValuesChanged (fieldId) {
      return !isEqual(this.values[fieldId], this.initialValues[fieldId])
    },
    resetField (fieldId) {
      this.values[fieldId] = clone(this.initialValues[fieldId])
    }
  }

}
</script>
