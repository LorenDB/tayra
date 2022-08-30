<script setup lang="ts">
import type { Form } from '~/types'

import SignupForm from '~/components/auth/SignupForm.vue'
import { useVModel } from '@vueuse/core'
import { computed, ref } from 'vue'
import { useGettext } from 'vue3-gettext'
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

const { $pgettext } = useGettext()
const labels = computed(() => ({
  delete: $pgettext('*/*/*', 'Delete'),
  up: $pgettext('*/*/*', 'Move up'),
  down: $pgettext('*/*/*', 'Move down')
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
    label: $pgettext('*/*/Form-builder', 'Additional field') + ' ' + (value.value.fields.length + 1),
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
        <translate translate-context="Content/*/Button.Label/Verb">
          Edit form
        </translate>
      </button>
      <button
        :class="[{active: isPreviewing}, 'item']"
        @click.stop.prevent="isPreviewing = true"
      >
        <translate translate-context="*/Form/Menu.item">
          Preview form
        </translate>
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
          <translate translate-context="*/*/Label">Help text</translate>
        </label>
        <p>
          <translate translate-context="*/*/Help">
            An optional text to be displayed at the start of the sign-up form.
          </translate>
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
          <translate translate-context="*/*/Label">Additional fields</translate>
        </label>
        <p>
          <translate translate-context="*/*/Help">
            Additional form fields to be displayed in the form. Only shown if manual sign-up validation is enabled.
          </translate>
        </p>
        <table v-if="value.fields?.length > 0">
          <thead>
            <tr>
              <th>
                <translate translate-context="*/*/Form-builder,Help">
                  Field label
                </translate>
              </th>
              <th>
                <translate translate-context="*/*/Form-builder,Help">
                  Field type
                </translate>
              </th>
              <th>
                <translate translate-context="*/*/Form-builder,Help">
                  Required
                </translate>
              </th>
              <th><span class="visually-hidden"><translate translate-context="*/*/Form-builder,Help">Actions</translate></span></th>
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
                    <translate translate-context="*/*/Form-builder">
                      Short text
                    </translate>
                  </option>
                  <option value="long_text">
                    <translate translate-context="*/*/Form-builder">
                      Long text
                    </translate>
                  </option>
                </select>
              </td>
              <td>
                <select v-model="field.required">
                  <option :value="true">
                    <translate translate-context="*/*/*">
                      Yes
                    </translate>
                  </option>
                  <option :value="false">
                    <translate translate-context="*/*/*">
                      No
                    </translate>
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
          <translate translate-context="*/*/Form-builder">
            Add a new field
          </translate>
        </button>
      </div>
    </div>
    <div class="ui hidden divider" />
  </div>
</template>
