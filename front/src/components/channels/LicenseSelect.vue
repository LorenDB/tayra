<script setup lang="ts">
import type { License } from '~/types'

import { computed, reactive, ref } from 'vue'
import axios from 'axios'
import { useVModel } from '@vueuse/core'

interface Events {
  (e: 'update:modelValue', value: string): void
}

interface Props {
  modelValue: string | null
}

const emit = defineEmits<Events>()
const props = withDefaults(defineProps<Props>(), {
  modelValue: null
})

const value = useVModel(props, 'modelValue', emit)

const availableLicenses = reactive<License[]>([])
const featuredLicensesIds = [
  'cc0-1.0',
  'cc-by-4.0',
  'cc-by-sa-4.0',
  'cc-by-nc-4.0',
  'cc-by-nc-sa-4.0',
  'cc-by-nc-nd-4.0',
  'cc-by-nd-4.0'
]

const featuredLicenses = computed(() => {
  return availableLicenses.filter(({ code }) => featuredLicensesIds.includes(code))
})

const currentLicense = computed(() => {
  if (!value.value) return null
  return availableLicenses.find(({ code }) => code === value.value) ?? null
})

const isLoading = ref(false)
const fetchLicenses = async () => {
  isLoading.value = true
  const response = await axios.get('licenses/')
  availableLicenses.length = 0
  availableLicenses.push(...response.data.results)
  isLoading.value = false
}

fetchLicenses()
</script>

<template>
  <div>
    <label for="license-dropdown">
      <translate translate-context="Content/*/*/Noun">License</translate>
    </label>
    <select
      id="license-dropdown"
      v-model="value"
      class="ui search normal dropdown"
    >
      <option value="">
        <translate translate-context="*/*/*">
          None
        </translate>
      </option>
      <option
        v-for="l in featuredLicenses"
        :key="l.code"
        :value="l.code"
      >
        {{ l.name }}
      </option>
    </select>
    <div class="ui very small hidden divider" />
    <p
      v-if="value"
      class="help"
    >
      <a
        v-if="value"
        :href="currentLicense?.url"
        target="_blank"
        rel="noreferrer noopener"
      >
        <translate translate-context="Content/*/*">About this license</translate>
      </a>
    </p>
  </div>
</template>
