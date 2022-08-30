<script setup lang="ts">
import { computed, ref, reactive, watch, watchEffect, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useGettext } from 'vue3-gettext'

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

const { $pgettext } = useGettext()
const router = useRouter()

const labels = computed(() => ({
  title: $pgettext('Head/Radio/Title', 'Radio Builder'),
  placeholder: {
    description: $pgettext('Content/Radio/Input.Placeholder', 'My awesome description'),
    name: $pgettext('Content/Radio/Input.Placeholder', 'My awesome radio')
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

watch(filters, fetchCandidates)
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

const isLoading = ref(false)
const fetchData = async () => {
  isLoading.value = true

  try {
    const response = await axios.get(`radios/radios/${props.id}/`)
    filters.length = 0
    filters.push(...response.data.config.map((filter: FilterConfig) => ({
      config: filter,
      filter: availableFilters.find(available => available.type === filter.type),
      hash: +new Date()
    })))

    radioName.value = response.data.name
    radioDesc.value = response.data.description
    isPublic.value = response.data.is_public
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoading.value = false
}

fetchFilters().then(() => watchEffect(fetchData))

const add = async () => {
  if (currentFilter.value) {
    filters.push({
      config: {} as FilterConfig,
      filter: currentFilter.value,
      hash: +new Date()
    })
  }

  return fetchCandidates()
}

const updateConfig = async (index: number, field: keyof FilterConfig, value: unknown) => {
  filters[index].config[field] = value
  return fetchCandidates()
}

const deleteFilter = async (index: number) => {
  filters.splice(index, 1)
  return fetchCandidates()
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
          <translate translate-context="Content/Radio/Title">
            Builder
          </translate>
        </h2>
        <p>
          <translate translate-context="Content/Radio/Paragraph">
            You can use this interface to build your own custom radio, which will play tracks according to your criteria.
          </translate>
        </p>
        <div class="ui form">
          <div
            v-if="success"
            class="ui positive message"
          >
            <h4 class="header">
              <template v-if="radioName">
                <translate translate-context="Content/Radio/Message">
                  Radio updated
                </translate>
              </template>
              <template v-else>
                <translate translate-context="Content/Radio/Message">
                  Radio created
                </translate>
              </template>
            </h4>
          </div>
          <div class="">
            <div class="field">
              <label for="name"><translate translate-context="Content/Radio/Input.Label/Noun">Radio name</translate></label>
              <input
                id="name"
                v-model="radioName"
                name="name"
                type="text"
                :placeholder="labels.placeholder.name"
              >
            </div>
            <div class="field">
              <label for="description"><translate translate-context="*/*/*/Noun">Description</translate></label>
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
              <label for="public"><translate translate-context="Content/Radio/Checkbox.Label/Verb">Display publicly</translate></label>
            </div>
            <div class="ui hidden divider" />
            <button
              :disabled="!canSave"
              :class="['ui', 'success', {loading: isLoading}, 'button']"
              @click="save"
            >
              <translate translate-context="Content/*/Button.Label/Verb">
                Save
              </translate>
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
            ><translate translate-context="Content/Radio/Paragraph">Add filters to customize your radio</translate></label>
            <select
              id="radio-filters"
              v-model="currentFilterType"
              class="ui dropdown"
            >
              <option value="">
                <translate translate-context="Content/Radio/Dropdown.Placeholder/Verb">
                  Select a filter
                </translate>
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
              <translate translate-context="Content/Radio/Button.Label/Verb">
                Add filter
              </translate>
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
                <translate translate-context="Content/Radio/Table.Label/Noun">
                  Filter name
                </translate>
              </th>
              <th class="one wide">
                <translate translate-context="Content/Radio/Table.Label/Verb">
                  Exclude
                </translate>
              </th>
              <th class="six wide">
                <translate translate-context="Content/Radio/Table.Label/Verb (Value is a List of Parameters)">
                  Config
                </translate>
              </th>
              <th class="five wide">
                <translate translate-context="Content/Radio/Table.Label/Noun (Value is a number of Tracks)">
                  Candidates
                </translate>
              </th>
              <th class="two wide">
                <translate translate-context="Content/*/*/Noun">
                  Actions
                </translate>
              </th>
            </tr>
          </thead>
          <tbody>
            <builder-filter
              v-for="(f, index) in filters"
              :key="f.hash"
              :index="index"
              :config="f.config"
              :filter="f.filter"
              @update-config="updateConfig"
              @delete="deleteFilter"
            />
          </tbody>
        </table>
        <template v-if="checkResult && checkResult.candidates && checkResult.candidates.count">
          <h3
            v-translate="{count: checkResult.candidates.count}"
            class="ui header"
            :translate-n="checkResult.candidates.count"
            translate-plural="%{ count } tracks matching combined filters"
            translate-context="Content/Radio/Table.Paragraph/Short"
          >
            %{ count } track matching combined filters
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
