<script setup lang="ts">
import { computed, ref, reactive, watch, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'

import axios from 'axios'
import $ from 'jquery'

import useErrorHandler from '~/composables/useErrorHandler'

import TrackTable from '~/components/audio/track/Table.vue'
import RadioButton from '~/components/radios/Button.vue'
import BuilderFilter from './Filter.vue'

export interface BuilderFilter {
  type: string
  label: string
  help_text: string
  fields: FilterField[]
}

export interface FilterField {
  name: string
  placeholder: string
  type: 'list'
  subtype: 'number'
  autocomplete?: string
  autocomplete_qs: string
  autocomplete_fields: {
    remoteValues?: unknown
  }
}

export interface FilterConfig extends Record<string, unknown> {
  type: string
  not: boolean
  names: string[]
}

interface Filter {
  hash: number
  config: FilterConfig
  filter: BuilderFilter
}

interface Props {
  id?: number
}

const props = withDefaults(defineProps<Props>(), {
  id: 0
})

const { t } = useI18n()
const router = useRouter()

const labels = computed(() => ({
  title: t('components.library.radios.Builder.title'),
  placeholder: {
    description: t('components.library.radios.Builder.placeholder.description'),
    name: t('components.library.radios.Builder.placeholder.name')
  }
}))

const filters = reactive([] as Filter[])
const checkResult = ref()
const fetchCandidates = async () => {
  // TODO (wvffle): Add loader

  try {
    const response = await axios.post('radios/radios/validate/', {
      filters: [{
        type: 'group',
        filters: filters.map(filter => ({
          ...filter.config,
          type: filter.filter.type
        }))
      }]
    })

    checkResult.value = response.data.filters[0]
  } catch (error) {
    useErrorHandler(error as Error)
  }
}

// NOTE: Whenever we modify filters array, we refetch the candidates automatically
watch(filters, fetchCandidates, {
  deep: true
})

const checkErrors = computed(() => checkResult.value?.errors ?? [])

const isPublic = ref(true)
const radioName = ref('')
const radioDesc = ref('')
const canSave = computed(() => radioName.value.length > 0 && checkErrors.value.length === 0)

const currentFilterType = ref()
const availableFilters = reactive([] as BuilderFilter[])
const currentFilter = computed(() => availableFilters.find(filter => filter.type === currentFilterType.value))

const fetchFilters = async () => {
  // TODO (wvffle): Add loader
  try {
    const response = await axios.get('radios/radios/filters/')
    availableFilters.length = 0
    availableFilters.push(...response.data)
  } catch (error) {
    useErrorHandler(error as Error)
  }
}

let filterId = Number.MIN_SAFE_INTEGER
const isLoading = ref(false)
const fetchData = async () => {
  isLoading.value = true

  try {
    const response = await axios.get(`radios/radios/${props.id}/`)
    filters.length = 0
    filters.push(...response.data.config.map((config: FilterConfig) => ({
      config,
      filter: availableFilters.find(available => available.type === config.type),
      hash: filterId++
    })))

    radioName.value = response.data.name
    radioDesc.value = response.data.description
    isPublic.value = response.data.is_public
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoading.value = false
}

fetchFilters().then(() => fetchData())

const add = async () => {
  if (!currentFilter.value) return
  filters.push({
    config: {} as FilterConfig,
    filter: currentFilter.value,
    hash: +new Date()
  })
}

const deleteFilter = async (index: number) => {
  filters.splice(index, 1)
}

const success = ref(false)
const save = async () => {
  success.value = false
  isLoading.value = true

  try {
    const data = {
      name: radioName.value,
      description: radioDesc.value,
      is_public: isPublic.value,
      config: filters.map(filter => ({
        ...filter.config,
        type: filter.filter.type
      }))
    }

    const response = props.id
      ? await axios.put(`radios/radios/${props.id}/`, data)
      : await axios.post('radios/radios/', data)

    success.value = true
    if (!props.id) {
      router.push({
        name: 'library.radios.detail',
        params: {
          id: response.data.id
        }
      })
    }
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoading.value = false
}

onMounted(() => {
  $('.ui.dropdown').dropdown()
})
</script>

<template>
  <div
    v-title="labels.title"
    class="ui vertical stripe segment"
  >
    <div>
      <section>
        <h2 class="ui header">
          {{ $t('components.library.radios.Builder.header.builder') }}
        </h2>
        <p>
          {{ $t('components.library.radios.Builder.description.builder') }}
        </p>
        <div class="ui form">
          <div
            v-if="success"
            class="ui positive message"
          >
            <h4 class="header">
              <template v-if="radioName">
                {{ $t('components.library.radios.Builder.header.updated') }}
              </template>
              <template v-else>
                {{ $t('components.library.radios.Builder.header.created') }}
              </template>
            </h4>
          </div>
          <div class="">
            <div class="field">
              <label for="name">{{ $t('components.library.radios.Builder.label.name') }}</label>
              <input
                id="name"
                v-model="radioName"
                name="name"
                type="text"
                :placeholder="labels.placeholder.name"
              >
            </div>
            <div class="field">
              <label for="description">{{ $t('components.library.radios.Builder.label.description') }}</label>
              <textarea
                id="description"
                v-model="radioDesc"
                rows="2"
                type="text"
                :placeholder="labels.placeholder.description"
              />
            </div>
            <div class="ui toggle checkbox">
              <input
                id="public"
                v-model="isPublic"
                type="checkbox"
              >
              <label for="public">{{ $t('components.library.radios.Builder.label.public') }}</label>
            </div>
            <div class="ui hidden divider" />
            <button
              :disabled="!canSave"
              :class="['ui', 'success', {loading: isLoading}, 'button']"
              @click="save"
            >
              {{ $t('components.library.radios.Builder.button.save') }}
            </button>
            <radio-button
              v-if="id"
              type="custom"
              :custom-radio-id="id"
            />
          </div>
        </div>
        <div class="ui form">
          <div class="inline field">
            <label
              id="radioFilterLabel"
              for="radio-filters"
            >{{ $t('components.library.radios.Builder.label.filter') }}</label>
            <select
              id="radio-filters"
              v-model="currentFilterType"
              class="ui dropdown"
            >
              <option value="">
                {{ $t('components.library.radios.Builder.option.filter') }}
              </option>
              <option
                v-for="f in availableFilters"
                :key="f.label"
                :value="f.type"
              >
                {{ f.label }}
              </option>
            </select>
            <button
              id="addFilter"
              :disabled="!currentFilterType"
              class="ui button"
              @click="add"
            >
              {{ $t('components.library.radios.Builder.button.filter') }}
            </button>
          </div>
          <p v-if="currentFilter">
            {{ currentFilter.help_text }}
          </p>
        </div>
        <table class="ui table">
          <thead>
            <tr>
              <th class="two wide">
                {{ $t('components.library.radios.Builder.table.filter.header.name') }}
              </th>
              <th class="one wide">
                {{ $t('components.library.radios.Builder.table.filter.header.exclude') }}
              </th>
              <th class="six wide">
                {{ $t('components.library.radios.Builder.table.filter.header.config') }}
              </th>
              <th class="five wide">
                {{ $t('components.library.radios.Builder.table.filter.header.candidates') }}
              </th>
              <th class="two wide">
                {{ $t('components.library.radios.Builder.table.filter.header.actions') }}
              </th>
            </tr>
          </thead>
          <tbody>
            <builder-filter
              v-for="(f, index) in filters"
              :key="f.hash"
              v-model:data="filters[index]"
              @delete="deleteFilter(index)"
            />
          </tbody>
        </table>
        <template v-if="checkResult && checkResult.candidates && checkResult.candidates.count">
          <h3 class="ui header">
            {{ $t('components.library.radios.Builder.header.matches', checkResult.candidates.count) }}
          </h3>
          <track-table
            v-if="checkResult.candidates.sample"
            :tracks="checkResult.candidates.sample"
            :playable="true"
            :show-position="false"
            :show-duration="false"
            :display-actions="false"
          />
        </template>
      </section>
    </div>
  </div>
</template>
