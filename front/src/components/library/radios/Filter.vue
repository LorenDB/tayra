<script setup lang="ts">
// TODO (wvffle): SORT IMPORTS LIKE SO EVERYWHERE
import type { BuilderFilter, FilterConfig } from './Builder.vue'
import type { Track } from '~/types'

import axios from 'axios'
import $ from 'jquery'

import { useCurrentElement, useVModel } from '@vueuse/core'
import { ref, onMounted, watch, computed } from 'vue'
import { useStore } from '~/store'
import { clone } from 'lodash-es'

import SemanticModal from '~/components/semantic/Modal.vue'
import TrackTable from '~/components/audio/track/Table.vue'

import useErrorHandler from '~/composables/useErrorHandler'

type Filter = { candidates: { count: number, sample: Track[] } }
type ResponseType = { filters: Array<Filter> }

interface Events {
  (e: 'update:data', name: string, value: number[] | boolean): void
  (e: 'delete'): void
}

interface Props {
  data: {
    filter: BuilderFilter
    config: FilterConfig
  }
}

const emit = defineEmits<Events>()
const props = defineProps<Props>()
const data = useVModel(props, 'data', emit)

const store = useStore()

const checkResult = ref<Filter | null>(null)
const showCandidadesModal = ref(false)
const exclude = computed({
  get: () => data.value.config.not,
  set: (value: boolean) => (data.value.config.not = value)
})

const el = useCurrentElement()
onMounted(() => {
  for (const field of data.value.filter.fields) {
    const settings: SemanticUI.DropdownSettings = {
      onChange (value) {
        value = $(this).dropdown('get value').split(',')

        if (field.type === 'list' && field.subtype === 'number') {
          value = value.map((number: string) => parseInt(number))
        }

        data.value.config[field.name] = value
        fetchCandidates()
      }
    }

    let selector = field.type === 'list'
      ? '.dropdown.multiple'
      : '.dropdown'

    if (field.autocomplete) {
      selector += '.autocomplete'

      // @ts-expect-error Semantic UI types are incomplete
      settings.fields = field.autocomplete_fields
      settings.minCharacters = 1
      settings.apiSettings = {
        url: store.getters['instance/absoluteUrl'](`${field.autocomplete}?${field.autocomplete_qs}`),
        beforeXHR (xhrObject) {
          if (store.state.auth.oauth.accessToken) {
            xhrObject.setRequestHeader('Authorization', store.getters['auth/header'])
          }

          return xhrObject
        },
        onResponse (initialResponse) {
          return !settings.fields?.remoteValues
            ? { results: initialResponse.results }
            : initialResponse
        }
      }
    }

    $(el.value).find(selector).dropdown(settings)
  }
})

const fetchCandidates = async () => {
  const params = {
    filters: [{
      ...clone(data.value.config),
      type: data.value.filter.type
    }]
  }

  try {
    const response = await axios.post('radios/radios/validate/', params)
    checkResult.value = (response.data as ResponseType).filters[0]
  } catch (error) {
    useErrorHandler(error as Error)
  }
}

watch(exclude, fetchCandidates)
fetchCandidates()
</script>

<template>
  <tr>
    <td>{{ data.filter.label }}</td>
    <td>
      <div class="ui toggle checkbox">
        <input
          id="exclude-filter"
          v-model="exclude"
          name="public"
          type="checkbox"
        >
        <label
          for="exclude-filter"
          class="visually-hidden"
        >
          {{ $t('components.library.radios.Filter.excludeLabel') }}
        </label>
      </div>
    </td>
    <td>
      <div
        v-for="f in data.filter.fields"
        :key="f.name"
        class="ui field"
      >
        <div :class="['ui', 'search', 'selection', 'dropdown', { autocomplete: f.autocomplete }, { multiple: f.type === 'list' }]">
          <i class="dropdown icon" />
          <div class="default text">
            {{ f.placeholder }}
          </div>
          <input
            v-if="f.type === 'list' && data.config[f.name as keyof FilterConfig]"
            :id="f.name"
            :value="(data.config[f.name as keyof FilterConfig] as string[]).join(',')"
            type="hidden"
          >
          <div
            v-if="typeof data.config[f.name as keyof FilterConfig] === 'object'"
            class="ui menu"
          >
            <div
              v-for="(v, i) in data.config[f.name as keyof FilterConfig] as object"
              v-once
              :key="data.config.ids?.[i] ?? v"
              class="ui item"
              :data-value="v"
            >
              <template v-if="data.config.names">
                {{ data.config.names[i] }}
              </template>
              <template v-else>
                {{ v }}
              </template>
            </div>
          </div>
        </div>
      </div>
    </td>
    <td>
      <a
        v-if="checkResult"
        href=""
        :class="['ui', { success: checkResult.candidates.count > 10 }, 'label']"
        @click.prevent="showCandidadesModal = !showCandidadesModal"
      >
        {{ $t('components.library.radios.Filter.matchingTracks', checkResult.candidates.count) }}
      </a>
      <semantic-modal
        v-if="checkResult"
        v-model:show="showCandidadesModal"
      >
        <h4 class="header">
          {{ $t('components.library.radios.Filter.matchingTracksModalHeader') }}
        </h4>
        <div class="content">
          <div class="description">
            <track-table
              v-if="checkResult.candidates.count > 0"
              :tracks="checkResult.candidates.sample"
            />
          </div>
        </div>
        <div class="actions">
          <button class="ui deny button">
            {{ $t('components.library.radios.Filter.cancelButton') }}
          </button>
        </div>
      </semantic-modal>
    </td>
    <td>
      <button
        class="ui danger button"
        @click="emit('delete')"
      >
        {{ $t('components.library.radios.Filter.removeButton') }}
      </button>
    </td>
  </tr>
</template>
