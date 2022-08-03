<script setup lang="ts">
import type { BackendError } from '~/types'

import { ref, computed, reactive, watch } from 'vue'
import { useGettext } from 'vue3-gettext'

import axios from 'axios'

interface Action {
  name: string
  label: string
  isDangerous?: boolean
  allowAll?: boolean
  confirmColor?: string
  confirmationMessage?: string
  filterChackable?: (item: never) => boolean
}

interface Emits {
  (e: 'action-launched', data: any): void
  (e: 'refresh'): void
}

interface Props {
  objectsData: { results: [], count: number }
  actions: [Action]
  actionUrl: string
  idField?: string
  refreshable?: boolean
  needsRefresh?: boolean
  filters?: object
  customObjects?: Record<string, unknown>[]
}

const emit = defineEmits<Emits>()
const props = withDefaults(defineProps<Props>(), {
  idField: 'id',
  refreshable: false,
  needsRefresh: false,
  filters: () => ({}),
  customObjects: () => []
})

const { $pgettext } = useGettext()

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

  // Add inbetween ids to the list of affected ids
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
  refresh: $pgettext('Content/*/Button.Tooltip/Verb', 'Refresh table content'),
  selectAllItems: $pgettext('Content/*/Select/Verb', 'Select all items'),
  performAction: $pgettext('Content/*/Button.Label', 'Perform actions'),
  selectItem: $pgettext('Content/*/Select/Verb', 'Select')
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
                <translate translate-context="Content/*/Button.Help text.Paragraph">Content has been updated, click refresh to see up-to-date content</translate>
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
                  <label for="actions-select"><translate translate-context="Content/*/*/Noun">Actions</translate></label>
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
                    <translate translate-context="Content/*/Button.Label/Short, Verb">
                      Go
                    </translate>
                    <template #modal-header>
                      <p>
                        <translate
                          key="1"
                          translate-context="Modal/*/Title"
                          :translate-n="affectedObjectsCount"
                          :translate-params="{count: affectedObjectsCount, action: currentActionName}"
                          translate-plural="Do you want to launch %{ action } on %{ count } elements?"
                        >
                          Do you want to launch %{ action } on %{ count } element?
                        </translate>
                      </p>
                    </template>
                    <template #modal-content>
                      <p>
                        <template v-if="currentAction?.confirmationMessage">
                          {{ currentAction?.confirmationMessage }}
                        </template>
                        <translate
                          v-else
                          translate-context="Modal/*/Paragraph"
                        >
                          This may affect a lot of elements or have irreversible consequences, please double check this is really what you want.
                        </translate>
                      </p>
                    </template>
                    <template #modal-confirm>
                      <div :aria-label="labels.performAction">
                        <translate translate-context="Modal/*/Button.Label/Short, Verb">
                          Launch
                        </translate>
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
                    <translate translate-context="Content/*/Button.Label/Short, Verb">
                      Go
                    </translate>
                  </button>
                </div>
                <div class="count field">
                  <translate
                    v-if="selectAll"
                    translate-context="Content/*/Paragraph"
                    tag="span"
                    :translate-n="objectsData.count"
                    :translate-params="{count: objectsData.count, total: objectsData.count}"
                    translate-plural="All %{ count } elements selected"
                  >
                    All %{ count } element selected
                  </translate>
                  <translate
                    v-else
                    translate-context="Content/*/Paragraph"
                    tag="span"
                    :translate-n="checked.length"
                    :translate-params="{count: checked.length, total: objectsData.count}"
                    translate-plural="%{ count } on %{ total } selected"
                  >
                    %{ count } on %{ total } selected
                  </translate>
                  <template v-if="currentAction?.allowAll && checkable.length > 0 && checkable.length === checked.length">
                    <a
                      v-if="!selectAll"
                      href=""
                      @click.prevent="selectAll = true"
                    >
                      <translate
                        key="3"
                        translate-context="Content/*/Link/Verb"
                        :translate-n="objectsData.count"
                        :translate-params="{total: objectsData.count}"
                        translate-plural="Select all %{ total } elements"
                      >
                        Select one element
                      </translate>
                    </a>
                    <a
                      v-else
                      href=""
                      @click.prevent="selectAll = false"
                    >
                      <translate
                        key="4"
                        translate-context="Content/*/Link/Verb"
                      >Select only current page</translate>
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
                  <translate translate-context="Content/*/Error message/Header">
                    Error while applying action
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
                <p>
                  <translate
                    translate-context="Content/*/Paragraph"
                    :translate-n="result.updated"
                    :translate-params="{count: result.updated, action: result.action}"
                    translate-plural="Action %{ action } was launched successfully on %{ count } elements"
                  >
                    Action %{ action } was launched successfully on %{ count } element
                  </translate>
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
