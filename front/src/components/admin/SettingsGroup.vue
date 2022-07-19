<script setup lang="ts">
import type { BackendError, SettingsGroup, SettingsDataEntry, FunctionRef, Form } from '~/types'
import axios from 'axios'
import SignupFormBuilder from '~/components/admin/SignupFormBuilder.vue'
import useFormData from '~/composables/useFormData'
import { ref, computed, reactive } from 'vue'
import { useStore } from '~/store'
import useLogger from '~/composables/useLogger'

interface Props {
  group: SettingsGroup
  settingsData: SettingsDataEntry[]
}

const props = defineProps<Props>()

const values = reactive({} as Record<string, unknown | Form | string>)
const result = ref<boolean | null>(null)
const errors = ref([] as string[])

const fileRefs = reactive({} as Record<string, HTMLInputElement>)
const setFileRef = (identifier: string) => (el: FunctionRef) => {
  console.log(el)
  fileRefs[identifier] = el as HTMLInputElement
}

const logger = useLogger()
const store = useStore()

const settings = computed(() => {
  const byIdentifier = props.settingsData.reduce((acc, entry) => {
    acc[entry.identifier] = entry
    return acc
  }, {} as Record<string, SettingsDataEntry>)

  return props.group.settings.map(entry => {
    return { ...byIdentifier[entry.name], fieldType: entry.fieldType, fieldParams: entry.fieldParams || {} }
  })
})

const fileSettings = computed(() => settings.value.filter(setting => setting.field.widget.class === 'ImageWidget'))

for (const setting of settings.value) {
  values[setting.identifier] = setting.value
}

const isLoading = ref(false)
const save = async () => {
  errors.value = []
  result.value = null

  let postData: unknown = values
  let contentType = 'application/json'

  if (fileSettings.value.length > 0) {
    const fileSettingsIDs = fileSettings.value.map((setting) =>  setting.identifier)
    const data = settings.value.reduce((data, setting) => {
      if (fileSettingsIDs.includes(setting.identifier)) {
        const input = fileRefs[setting.identifier]
        const { files } = input

        logger.debug('ref', input, files)

        if (files && files.length > 0) {
          data[setting.identifier] = files[0]
        }
      } else {
        data[setting.identifier] = values[setting.identifier] as string
      }

      return data
    }, {} as Record<string, string | File>) 

    contentType = 'multipart/form-data'
    postData = useFormData(data)
  }

  try {
    const response = await axios.post('instance/admin/settings/bulk/', postData, {
      headers: { 'Content-Type': contentType }
    })

    result.value = true
    for (const setting of response.data) {
      values[setting.identifier] = setting.value
    }

    store.dispatch('instance/fetchSettings')
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }

  isLoading.value = false
}
</script>

<template>
  <form
    :id="group.id"
    class="ui form component-settings-group"
    @submit.prevent="save"
  >
    <div class="ui divider" />
    <h3 class="ui header">
      {{ group.label }}
    </h3>
    <div
      v-if="errors.length > 0"
      role="alert"
      class="ui negative message"
    >
      <h4 class="header">
        <translate translate-context="Content/*/Error message.Title">
          Error while saving settings
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
      v-if="result"
      class="ui positive message"
    >
      <translate translate-context="Content/Settings/Paragraph">
        Settings updated successfully.
      </translate>
    </div>
    <div
      v-for="(setting, key) in settings"
      :key="key"
      class="ui field"
    >
      <template v-if="setting.field.widget.class !== 'CheckboxInput'">
        <label :for="setting.identifier">{{ setting.verbose_name }}</label>
        <p v-if="setting.help_text">
          {{ setting.help_text }}
        </p>
      </template>
      <content-form
        v-if="setting.fieldType === 'markdown'"
        v-bind="setting.fieldParams"
        v-model="values[setting.identifier]"
      />
      <signup-form-builder
        v-else-if="setting.fieldType === 'formBuilder'"
        v-model="values[setting.identifier] as Form"
        :signup-approval-enabled="!!values.moderation__signup_approval_enabled"
      />
      <input
        v-else-if="setting.field.widget.class === 'PasswordInput'"
        :id="setting.identifier"
        v-model="values[setting.identifier]"
        :name="setting.identifier"
        type="password"
        class="ui input"
      >
      <input
        v-else-if="setting.field.widget.class === 'TextInput'"
        :id="setting.identifier"
        v-model="values[setting.identifier]"
        :name="setting.identifier"
        type="text"
        class="ui input"
      >
      <input
        v-else-if="setting.field.class === 'IntegerField'"
        :id="setting.identifier"
        v-model.number="values[setting.identifier]"
        :name="setting.identifier"
        type="number"
        class="ui input"
      >
      <textarea
        v-else-if="setting.field.widget.class === 'Textarea'"
        :id="setting.identifier"
        v-model="values[setting.identifier] as string"
        :name="setting.identifier"
        type="text"
        class="ui input"
      />
      <div
        v-else-if="setting.field.widget.class === 'CheckboxInput'"
        class="ui toggle checkbox"
      >
        <input
          :id="setting.identifier"
          v-model="values[setting.identifier] as boolean"
          :name="setting.identifier"
          type="checkbox"
        >
        <label :for="setting.identifier">{{ setting.verbose_name }}</label>
        <p v-if="setting.help_text">
          {{ setting.help_text }}
        </p>
      </div>
      <select
        v-else-if="setting.field.class === 'MultipleChoiceField'"
        :id="setting.identifier"
        v-model="values[setting.identifier]"
        multiple
        class="ui search selection dropdown"
      >
        <option
          v-for="v in setting.additional_data.choices"
          :key="v[0]"
          :value="v[0]"
        >
          {{ v[1] }}
        </option>
      </select>
      <div v-else-if="setting.field.widget.class === 'ImageWidget'">
        <input
          :id="setting.identifier"
          :ref="setFileRef(setting.identifier)"
          type="file"
        >
        <div v-if="values[setting.identifier]">
          <div class="ui hidden divider" />
          <h3 class="ui header">
            <translate translate-context="Content/Settings/Title/Noun">
              Current image
            </translate>
          </h3>
          <img
            v-if="values[setting.identifier]"
            class="ui image"
            alt=""
            :src="$store.getters['instance/absoluteUrl'](values[setting.identifier])"
          >
        </div>
      </div>
    </div>
    <button
      type="submit"
      :class="['ui', {'loading': isLoading}, 'right', 'floated', 'success', 'button']"
    >
      <translate translate-context="Content/*/Button.Label/Verb">
        Save
      </translate>
    </button>
  </form>
</template>
