<script setup lang="ts">
import type { EditObject, EditObjectType } from '~/composables/moderation/useEditConfigs'
import type { BackendError, License, ReviewState } from '~/types'

import { computed, onMounted, reactive, ref, watchEffect } from 'vue'
import { isEqual, clone } from 'lodash-es'
import { useGettext } from 'vue3-gettext'
import { useStore } from '~/store'

import axios from 'axios'
import $ from 'jquery'

import AttachmentInput from '~/components/common/AttachmentInput.vue'
import useEditConfigs from '~/composables/moderation/useEditConfigs'
import TagsSelector from '~/components/library/TagsSelector.vue'
import EditList from '~/components/library/EditList.vue'
import EditCard from '~/components/library/EditCard.vue'

interface Props {
  objectType: EditObjectType
  object: EditObject
  licenses: License[]
}

const props = defineProps<Props>()

const { $pgettext } = useGettext()
const configs = useEditConfigs()
const store = useStore()

const config = computed(() => configs[props.objectType])
const currentState = computed(() => config.value.fields.reduce((state: ReviewState, field) => {
  state[field.id] = { value: field.getValue(props.object) }
  return state
}, {}))

const canEdit = computed(() => {
  if (!store.state.auth.authenticated) return false

  const isOwner = props.object.attributed_to
    // TODO (wvffle): Is it better to compare ids? Is full_username unique?
    && store.state.auth.fullUsername === props.object.attributed_to.full_username

  return isOwner || store.state.auth.availablePermissions.library
})

const labels = computed(() => ({
  summaryPlaceholder: $pgettext('*/*/Placeholder', 'A short summary describing your changes.')
}))

const mutationsUrl = computed(() => props.objectType === 'track'
  ? `tracks/${props.object.id}/mutations/`
  : props.objectType === 'album'
    ? `albums/${props.object.id}/mutations/`
    : props.objectType === 'artist'
      ? `artists/${props.object.id}/mutations/`
      : ''
)

const mutationPayload = computed(() => {
  const changedFields = config.value.fields.filter(f => {
    return !isEqual(values[f.id], initialValues[f.id])
  })

  if (changedFields.length === 0) {
    return {}
  }

  const data = {
    type: 'update',
    payload: {} as Record<string, unknown>,
    summary: summary.value
  }

  for (const field of changedFields) {
    data.payload[field.id] = values[field.id]
  }

  return data
})

const showPendingReview = ref(true)
const editListFilters = computed(() => showPendingReview.value
  ? { is_approved: 'null' }
  : {}
)

const values = reactive({} as Record<string, any>)
const initialValues = reactive({} as Record<string, any>)
for (const { id, getValue } of config.value.fields) {
  values[id] = clone(getValue(props.object))
  initialValues[id] = clone(values[id])
}

const license = ref()
watchEffect(() => {
  if (values.license === null) {
    $(license.value).dropdown('clear')
    return
  }

  $(license.value).dropdown('set selected', values.license)
})

onMounted(() => {
  $('.ui.dropdown').dropdown({ fullTextSearch: true })
})

const submittedMutation = ref()
const summary = ref('')

const errors = ref([] as string[])
const isLoading = ref(false)
const submit = async () => {
  const url = mutationsUrl.value
  if (!url) return

  isLoading.value = true
  errors.value = []

  try {
    const response = await axios.post(url, {
      ...mutationPayload.value,
      is_approved: canEdit.value
        ? true
        : undefined
    })

    submittedMutation.value = response.data
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }

  isLoading.value = false
}

const fieldValuesChanged = (fieldId: string) => {
  return !isEqual(values[fieldId], initialValues[fieldId])
}

const resetField = (fieldId: string) => {
  values[fieldId] = clone(initialValues[fieldId])
}
</script>

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
          translate-context="Content/Library/Button.Label/Verb"
        >
          Submit and apply edit
        </translate>
        <translate
          v-else
          translate-context="Content/Library/Button.Label/Verb"
        >
          Submit suggestion
        </translate>
      </button>
    </form>
  </div>
</template>
