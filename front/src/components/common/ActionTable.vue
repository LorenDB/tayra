<script setup lang="ts">
import type { BackendError } from '~/types'

import { ref, computed, reactive, watch } from 'vue'
import { useI18n } from 'vue-i18n'

import axios from 'axios'

interface Action {
  name: string
  label: string
  isDangerous?: boolean
  allowAll?: boolean
  confirmColor?: string
  confirmationMessage?: string
  filterChackable?: (item: any) => boolean
}

interface Events {
  (e: 'action-launched', data: any): void
  (e: 'refresh'): void
}

interface Props {
  objectsData: { results: any[], count: number }
  actions: Action[]
  actionUrl: string
  idField?: string
  refreshable?: boolean
  needsRefresh?: boolean
  filters?: object
  customObjects?: Record<string, unknown>[]
}

const emit = defineEmits<Events>()
const props = withDefaults(defineProps<Props>(), {
  idField: 'id',
  refreshable: false,
  needsRefresh: false,
  filters: () => ({}),
  customObjects: () => []
})

const { t } = useI18n()

const currentActionName = ref(props.actions[0]?.name ?? null)
const currentAction = computed(() => props.actions.find(action => action.name === currentActionName.value))

const checkable = computed(() => {
  if (!currentAction.value) return []

  return props.objectsData.results
    .filter(currentAction.value.filterChackable ?? (() => true))
    .map(item => item[props.idField] as string)
})

const objects = computed(() => props.objectsData.results.map(object => {
  return props.customObjects.find(custom => custom[props.idField] === object[props.idField])
    ?? object
}))

const selectAll = ref(false)
const checked = reactive([] as string[])
const affectedObjectsCount = computed(() => selectAll.value ? props.objectsData.count : checked.length)
watch(() => props.objectsData, () => {
  checked.length = 0
  selectAll.value = false
})

// We update checked status as some actions have specific filters
// on what is checkable or not
watch(currentActionName, () => {
  const ableToCheck = checkable.value
  const replace = checked.filter(object => ableToCheck.includes(object))

  checked.length = 0
  checked.push(...replace)
})

const lastCheckedIndex = ref(-1)
const toggleCheckAll = () => {
  lastCheckedIndex.value = -1

  if (checked.length === checkable.value.length) {
    checked.length = 0
    return
  }

  checked.length = 0
  checked.push(...checkable.value)
}

const toggleCheck = (event: MouseEvent, id: string, index: number) => {
  const affectedIds = new Set([id])

  const wasChecked = checked.includes(id)
  if (wasChecked) {
    selectAll.value = false
  }

  // Add in between ids to the list of affected ids
  if (event.shiftKey && lastCheckedIndex.value !== -1) {
    const boundaries = [index, lastCheckedIndex.value].sort((a, b) => a - b)
    for (const object of props.objectsData.results.slice(boundaries[0], boundaries[1] + 1)) {
      affectedIds.add(object[props.idField])
    }
  }

  for (const id of affectedIds) {
    const isChecked = checked.includes(id)

    if (!wasChecked && !isChecked && checkable.value.includes(id)) {
      checked.push(id)
      continue
    }

    if (wasChecked && isChecked) {
      checked.splice(checked.indexOf(id), 1)
    }
  }

  lastCheckedIndex.value = index
}

const labels = computed(() => ({
  refresh: t('components.common.ActionTable.button.refresh'),
  selectAllItems: t('components.common.ActionTable.button.selectAll'),
  performAction: t('components.common.ActionTable.label.performAction'),
  selectItem: t('components.common.ActionTable.button.select')
}))

const errors = ref([] as string[])
const isLoading = ref(false)
const result = ref()
const launchAction = async () => {
  isLoading.value = true
  result.value = undefined
  errors.value = []

  try {
    const response = await axios.post(props.actionUrl, {
      action: currentActionName.value,
      filters: props.filters,
      objects: !selectAll.value
        ? checked
        : 'all'
    })

    result.value = response.data
    emit('action-launched', response.data)
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }

  isLoading.value = false
}
</script>

<template>
  <div class="table-wrapper component-action-table">
    <table class="ui compact very basic unstackable table">
      <thead>
        <tr>
          <th colspan="1000">
            <div
              v-if="refreshable"
              class="right floated"
            >
              <span v-if="needsRefresh">
                {{ $t('components.common.ActionTable.message.needsRefresh') }}
              </span>
              <button
                class="ui basic icon button"
                :title="labels.refresh"
                :aria-label="labels.refresh"
                @click="$emit('refresh')"
              >
                <i class="refresh icon" />
              </button>
            </div>

            <div
              v-if="actionUrl && actions.length > 0"
              class="ui small left floated form"
            >
              <div class="ui inline fields">
                <div class="field">
                  <label for="actions-select">{{ $t('components.common.ActionTable.label.actions') }}</label>
                  <select
                    id="actions-select"
                    v-model="currentActionName"
                    class="ui dropdown"
                  >
                    <option
                      v-for="action in actions"
                      :key="action.name"
                      :value="action.name"
                    >
                      {{ action.label }}
                    </option>
                  </select>
                </div>
                <div class="field">
                  <dangerous-button
                    v-if="selectAll || currentAction?.isDangerous"
                    :class="['ui', {disabled: checked.length === 0}, {'loading': isLoading}, 'button']"
                    :confirm-color="currentAction?.confirmColor ?? 'success'"
                    :aria-label="labels.performAction"
                    @confirm="launchAction"
                  >
                    {{ $t('components.common.ActionTable.button.go') }}
                    <template #modal-header>
                      <p>
                        <span key="1">
                          {{ $t('components.common.ActionTable.modal.performAction.header', { action: currentActionName }, affectedObjectsCount) }}
                        </span>
                      </p>
                    </template>
                    <template #modal-content>
                      <p>
                        <template v-if="currentAction?.confirmationMessage">
                          {{ currentAction?.confirmationMessage }}
                        </template>
                        <span v-else>
                          {{ $t('components.common.ActionTable.modal.performAction.content.warning') }}
                        </span>
                      </p>
                    </template>
                    <template #modal-confirm>
                      <div :aria-label="labels.performAction">
                        {{ $t('components.common.ActionTable.button.launch') }}
                      </div>
                    </template>
                  </dangerous-button>
                  <button
                    v-else
                    :disabled="checked.length === 0"
                    :aria-label="labels.performAction"
                    :class="['ui', {disabled: checked.length === 0}, {'loading': isLoading}, 'button']"
                    @click="launchAction"
                  >
                    {{ $t('components.common.ActionTable.button.go') }}
                  </button>
                </div>
                <div class="count field">
                  <span v-if="selectAll">
                    {{ $t('components.common.ActionTable.button.allSelected', objectsData.count) }}
                  </span>
                  <span v-else>
                    {{ $t('components.common.ActionTable.button.selected', { total: objectsData.count }, checked.length) }}
                  </span>
                  <template v-if="currentAction?.allowAll && checkable.length > 0 && checkable.length === checked.length">
                    <a
                      v-if="!selectAll"
                      href=""
                      @click.prevent="selectAll = true"
                    >
                      <span key="3">
                        {{ $t('components.common.ActionTable.button.selectElement', objectsData.count) }}
                      </span>
                    </a>
                    <a
                      v-else
                      href=""
                      @click.prevent="selectAll = false"
                    >
                      <span key="4">
                        {{ $t('components.common.ActionTable.button.selectCurrentPage') }}
                      </span>
                    </a>
                  </template>
                </div>
              </div>
              <div
                v-if="errors.length > 0"
                role="alert"
                class="ui negative message"
              >
                <h4 class="header">
                  {{ $t('components.common.ActionTable.header.error') }}
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
                <p>
                  <span>
                    {{ $t('components.common.ActionTable.message.success', { action: result.action }, result.updated) }}
                  </span>
                </p>

                <slot
                  name="action-success-footer"
                  :result="result"
                />
              </div>
            </div>
          </th>
        </tr>
        <tr>
          <th v-if="actions.length > 0">
            <div class="ui checkbox">
              <!-- TODO (wvffle): Check if we don't have to migrate to v-model -->
              <input
                type="checkbox"
                :aria-label="labels.selectAllItems"
                :disabled="checkable.length === 0"
                :checked="checkable.length > 0 && checked.length === checkable.length"
                @change="toggleCheckAll"
              >
            </div>
          </th>
          <slot name="header-cells" />
        </tr>
      </thead>
      <tbody v-if="objectsData.count > 0">
        <tr
          v-for="(obj, index) in objects"
          :key="index"
        >
          <td
            v-if="actions.length > 0"
            class="collapsing"
          >
            <!-- TODO (wvffle): Check if we don't have to migrate to v-model -->
            <input
              type="checkbox"
              :aria-label="labels.selectItem"
              :disabled="checkable.indexOf(obj[idField]) === -1"
              :checked="checked.indexOf(obj[idField]) > -1"
              @click="toggleCheck($event, obj[idField], index)"
            >
          </td>
          <slot
            name="row-cells"
            :obj="obj"
          />
        </tr>
      </tbody>
    </table>
  </div>
</template>
