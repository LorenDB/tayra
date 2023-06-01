<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import useSharedLabels from '~/composables/locale/useSharedLabels'
import { useVModel } from '@vueuse/core'

interface Events {
  (e: 'update:modelValue', value: string): void
}

interface Props {
  modelValue: string
  all?: boolean
  label?: boolean
  empty?: boolean
  required?: boolean
  restrictTo?: string[] // TODO (wvffle): Make sure its string list
}

const emit = defineEmits<Events>()
const props = withDefaults(defineProps<Props>(), {
  all: false,
  label: false,
  empty: false,
  required: false,
  restrictTo: () => []
})

const value = useVModel(props, 'modelValue', emit)

const { t } = useI18n()
const sharedLabels = useSharedLabels()
const sharedChoices = sharedLabels.fields.report_type.choices

const allCategories = computed(() => {
  const res = []
  if (props.all) {
    res.push({ value: '', label: t('components.moderation.ReportCategoryDropdown.option.all') })
  }

  const choices = props.restrictTo.length === 0
    ? Object.keys(sharedChoices)
    : props.restrictTo

  for (const value of choices.sort()) {
    res.push({
      value,
      label: value in sharedChoices
        // NOTE: M$ simply locked the conversation instead of fixing type inferring
        //       https://github.com/microsoft/TypeScript/issues/35859
        ? sharedChoices[value as keyof typeof sharedChoices]
        : value
    })
  }

  return res
})
</script>

<template>
  <div>
    <label v-if="label">{{ $t('components.moderation.ReportCategoryDropdown.label.category') }}</label>
    <select
      v-model="value"
      class="ui dropdown"
      :required="required || undefined"
    >
      <option
        v-if="empty"
        disabled
        value=""
      />
      <option
        v-for="option in allCategories"
        :key="option.label"
        :value="option.value"
      >
        {{ option.label }}
      </option>
    </select>
    <slot />
  </div>
</template>
