<script setup lang="ts">
import type { Form } from '~/types'

import SignupForm from '~/components/auth/SignupForm.vue'
import { useVModel } from '@vueuse/core'
import { computed, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { arrayMove } from '~/utils'

interface Events {
  (e: 'update:modelValue', value: Form): void
}

interface Props {
  modelValue: Form
  signupApprovalEnabled?: boolean
}

const emit = defineEmits<Events>()
const props = withDefaults(defineProps<Props>(), {
  signupApprovalEnabled: false
})

const value = useVModel(props, 'modelValue', emit, { deep: true })

const maxFields = ref(10)
const isPreviewing = ref(false)

const { t } = useI18n()
const labels = computed(() => ({
  delete: t('Delete'),
  up: t('Move up'),
  down: t('Move down')
}))

if (!value.value?.fields) {
  value.value = {
    help_text: {
      text: '',
      content_type: 'text/markdown'
    },
    fields: []
  }
}

const addField = () => {
  value.value.fields.push({
    label: t('Additional field') + ' ' + (value.value.fields.length + 1),
    required: true,
    input_type: 'short_text'
  })
}

const remove = (idx: number) => {
  value.value.fields.splice(idx, 1)
}

const move = (idx: number, increment: number) => {
  if (idx + increment >= value.value.fields.length) return
  if (idx === 0 && increment < 0) return
  arrayMove(value.value.fields, idx, idx + increment)
}
</script>

<template>
  <div>
    <div class="ui top attached tabular menu">
      <button
        :class="[{active: !isPreviewing}, 'item']"
        @click.stop.prevent="isPreviewing = false"
      >
        Edit form
      </button>
      <button
        :class="[{active: isPreviewing}, 'item']"
        @click.stop.prevent="isPreviewing = true"
      >
        Preview form
      </button>
    </div>
    <div
      v-if="isPreviewing"
      class="ui bottom attached segment"
    >
      <signup-form
        :customization="value"
        :signup-approval-enabled="signupApprovalEnabled"
        :fetch-description-html="true"
      />
      <div class="ui clearing hidden divider" />
    </div>
    <div
      v-else
      class="ui bottom attached segment"
    >
      <div class="field">
        <label for="help-text">
          Help text
        </label>
        <p>
          An optional text to be displayed at the start of the sign-up form.
        </p>
        <content-form
          v-if="value.help_text"
          v-model="value.help_text.text"
          field-id="help-text"
          :permissive="true"
        />
      </div>
      <div class="field">
        <label>
          Additional fields
        </label>
        <p>
          Additional form fields to be displayed in the form. Only shown if manual sign-up validation is enabled.
        </p>
        <table v-if="value.fields?.length > 0">
          <thead>
            <tr>
              <th>
                Field label
              </th>
              <th>
                Field type
              </th>
              <th>
                Required
              </th>
              <th><span class="visually-hidden">Actions</span></th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="(field, idx) in value.fields"
              :key="idx"
            >
              <td>
                <input
                  v-model="field.label"
                  type="text"
                  required
                >
              </td>
              <td>
                <select v-model="field.input_type">
                  <option value="short_text">
                    Short text
                  </option>
                  <option value="long_text">
                    Long text
                  </option>
                </select>
              </td>
              <td>
                <select v-model="field.required">
                  <option :value="true">
                    Yes
                  </option>
                  <option :value="false">
                    No
                  </option>
                </select>
              </td>
              <td>
                <i
                  :disabled="idx === 0 || null"
                  role="button"
                  :title="labels.up"
                  :class="['up', 'arrow', { disabled: idx === 0 }, 'icon']"
                  @click="move(idx, -1)"
                />
                <i
                  :disabled="idx >= value.fields.length - 1 || null"
                  role="button"
                  :title="labels.down"
                  :class="['down', 'arrow', { disabled: idx >= value.fields.length - 1 }, 'icon']"
                  @click="move(idx, 1)"
                />
                <i
                  role="button"
                  :title="labels.delete"
                  class="x icon"
                  @click="remove(idx)"
                />
              </td>
            </tr>
          </tbody>
        </table>
        <div class="ui hidden divider" />
        <button
          v-if="value.fields?.length < maxFields"
          class="ui basic button"
          @click.stop.prevent="addField"
        >
          Add a new field
        </button>
      </div>
    </div>
    <div class="ui hidden divider" />
  </div>
</template>
