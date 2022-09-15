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
  delete: t('components.admin.SignupFormBuilder.deleteLabel'),
  up: t('components.admin.SignupFormBuilder.moveUpLabel'),
  down: t('components.admin.SignupFormBuilder.moveDownLabel')
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
    label: t('components.admin.SignupFormBuilder.additionalFieldInput') + ' ' + (value.value.fields.length + 1),
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
        {{ $t('components.admin.SignupFormBuilder.editForm') }}
      </button>
      <button
        :class="[{active: isPreviewing}, 'item']"
        @click.stop.prevent="isPreviewing = true"
      >
      {{ $t('components.admin.SignupFormBuilder.previewForm') }}
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
          {{ $t('components.admin.SignupFormBuilder.helpTextLabel') }}
        </label>
        <p>
          {{ $t('components.admin.SignupFormBuilder.helpTextMessage') }}
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
          {{ $t('components.admin.SignupFormBuilder.additionalFieldsLabel') }}
        </label>
        <p>
          {{ $t('components.admin.SignupFormBuilder.additionalFieldsMessage') }}
        </p>
        <table v-if="value.fields?.length > 0">
          <thead>
            <tr>
              <th>
                {{ $t('components.admin.SignupFormBuilder.fieldLabelTableHeader') }}
              </th>
              <th>
                {{ $t('components.admin.SignupFormBuilder.fieldTypeTableHeader') }}
              </th>
              <th>
                {{ $t('components.admin.SignupFormBuilder.requiredTableHeader') }}
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
                    {{ $t('components.admin.SignupFormBuilder.shortTextInput') }}
                  </option>
                  <option value="long_text">
                    {{ $t('components.admin.SignupFormBuilder.longTextInput') }}
                  </option>
                </select>
              </td>
              <td>
                <select v-model="field.required">
                  <option :value="true">
                    {{ $t('components.admin.SignupFormBuilder.requiredTrue') }}
                  </option>
                  <option :value="false">
                    {{ $t('components.admin.SignupFormBuilder.requiredFalse') }}
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
          {{ $t('components.admin.SignupFormBuilder.addFieldButton') }}
        </button>
      </div>
    </div>
    <div class="ui hidden divider" />
  </div>
</template>
