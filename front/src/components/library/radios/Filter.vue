<script setup lang="ts">
// TODO (wvffle): SORT IMPORTS LIKE SO EVERYWHERE
import type { BuilderFilter, FilterConfig } from './Builder.vue'
import type { Track } from '~/types'

import axios from 'axios'
import $ from 'jquery'

import { useCurrentElement } from '@vueuse/core'
import { ref, onMounted, watch } from 'vue'
import { useStore } from '~/store'
import { clone } from 'lodash-es'

import SemanticModal from '~/components/semantic/Modal.vue'
import TrackTable from '~/components/audio/track/Table.vue'

import useErrorHandler from '~/composables/useErrorHandler'

type Filter = { candidates: { count: number, sample: Track[] } }
type ResponseType = { filters: Array<Filter> }

interface Events {
  (e: 'update-config', index: number, name: string, value: number[] | boolean): void
  (e: 'delete', index: number): void
}

interface Props {
  index: number

  filter: BuilderFilter
  config: FilterConfig
}

const emit = defineEmits<Events>()
const props = defineProps<Props>()

const store = useStore()

const checkResult = ref<Filter | null>(null)
const showCandidadesModal = ref(false)
const exclude = ref(props.config.not)

const el = useCurrentElement()
onMounted(() => {
  for (const field of props.filter.fields) {
    const selector = ['.dropdown']

    if (field.type === 'list') {
      selector.push('.multiple')
    }

    const settings: SemanticUI.DropdownSettings = {
      onChange (value) {
        value = $(this).dropdown('get value').split(',')

        if (field.type === 'list' && field.subtype === 'number') {
          value = value.map((number: string) => parseInt(number))
        }

        value.value = value
        emit('update-config', props.index, field.name, value)
        fetchCandidates()
      }
    }

    if (field.autocomplete) {
      selector.push('.autocomplete')
      // @ts-expect-error custom field?
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

    $(el.value).find(selector.join('')).dropdown(settings)
  }
})

const fetchCandidates = async () => {
  const params = {
    filters: [{
      ...clone(props.config),
      type: props.filter.type
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
</script>

<template>
  <tr>
    <td>{{ filter.label }}</td>
    <td>
      <div class="ui toggle checkbox">
        <input
          id="exclude-filter"
          v-model="exclude"
          name="public"
          type="checkbox"
          @change="$emit('update-config', index, 'not', exclude)"
        >
        <label
          for="exclude-filter"
          class="visually-hidden"
        >
          <translate translate-context="Popup/Radio/Title/Noun">Exclude</translate>
        </label>
      </div>
    </td>
    <td>
      <div
        v-for="f in filter.fields"
        :key="f.name"
        class="ui field"
      >
        <div :class="['ui', 'search', 'selection', 'dropdown', {'autocomplete': f.autocomplete}, {'multiple': f.type === 'list'}]">
          <i class="dropdown icon" />
          <div class="default text">
            {{ f.placeholder }}
          </div>
          <input
            v-if="f.type === 'list' && config[f.name as keyof FilterConfig]"
            :id="f.name"
            :value="(config[f.name as keyof FilterConfig] as string[]).join(',')"
            type="hidden"
          >
          <div
            v-if="typeof config[f.name as keyof FilterConfig] === 'object'"
            class="ui menu"
          >
            <div
              v-for="(v, i) in config[f.name as keyof FilterConfig] as object"
              :key="i"
              class="ui item"
              :data-value="v"
            >
              <template v-if="config.names">
                {{ config.names[i] }}
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
        :class="['ui', {'success': checkResult.candidates.count > 10}, 'label']"
        @click.prevent="showCandidadesModal = !showCandidadesModal"
      >
        {{ checkResult.candidates.count }} tracks matching filter
      </a>
      <semantic-modal
        v-if="checkResult"
        v-model:show="showCandidadesModal"
      >
        <h4 class="header">
          <translate translate-context="Popup/Radio/Title/Noun">
            Tracks matching filter
          </translate>
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
            <translate translate-context="*/*/Button.Label/Verb">
              Cancel
            </translate>
          </button>
        </div>
      </semantic-modal>
    </td>
    <td>
      <button
        class="ui danger button"
        @click="$emit('delete', index)"
      >
        <translate translate-context="Content/Radio/Button.Label/Verb">
          Remove
        </translate>
      </button>
    </td>
  </tr>
</template>
