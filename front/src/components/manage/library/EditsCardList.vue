<script setup lang="ts">
import axios from 'axios'
import { uniq, merge } from 'lodash-es'
import Pagination from '~/components/vui/Pagination.vue'
import EditCard from '~/components/library/EditCard.vue'
import { normalizeQuery, parseTokens } from '~/utils/search'

import useSharedLabels from '~/composables/locale/useSharedLabels'
import { ref, reactive, watch } from 'vue'
import useOrdering, { OrderingProps } from '~/composables/useOrdering'
import useSmartSearch, { SmartSearchProps } from '~/composables/useSmartSearch'
import { OrderingField } from '~/store/ui'
import useEditConfigs from '~/composables/moderation/useEditConfigs'

interface Props extends SmartSearchProps, OrderingProps {
  // TODO (wvffle): find object type
  filters?: object
}

const props = withDefaults(defineProps<Props>(), {
  defaultQuery: '',
  updateUrl: false,
  filters: () => ({})
})

const configs = useEditConfigs()

// TODO (wvffle): Make sure everything is it's own type
const page = ref(1)
type ResponseType = { count: number, results: { target?: { type: string, id: number } }[] }
const result = ref<null | ResponseType>(null)

const { onSearch, query, addSearchToken, getTokenValue } = useSmartSearch(props.defaultQuery, props.updateUrl)
const { onOrderingUpdate, orderingString, paginateBy, ordering, orderingDirection } = useOrdering(props.orderingConfigName)

const orderingOptions: [OrderingField, keyof typeof sharedLabels.filters][] = [
  ['creation_date', 'creation_date'],
  ['applied_date', 'applied_date']
]

const targets = reactive({
  track: {}
})

const fetchTargets = async () => {
  // we request target data via the API so we can display previous state
  // additionnal data next to the edit card
  const typesAndIds = {
    track: { url: 'tracks/', ids: [] as number[] }
  }

  for (const res of result.value?.results ?? []) {
    const typeAndId = typesAndIds[result.target?.type as keyof typeof typesAndIds]
    typeAndId?.ids.push(result.target.id)
  }

  for (const [key, config] of Object.entries(typesAndIds)) {
    if (config.ids.length === 0) {
      continue
    }

    const response = await axios.get(config.url, {
      params: {
        id: uniq(config.ids),
        hidden: 'null'
      }
    }).catch(() => {
      // TODO (wvffle): Handle error
    })

    for (const payload of response.data.results) {
      targets[key][payload.id] = { 
        payload,
        currentState: configs[key].fields.reduce((state, field) => {
          state[field.id] = { value: field.getValue(payload) }
          return state
        })
      }
    }
  }
}

const isLoading = ref(false)
const fetchData = async () => {
  isLoading.value = true
  const params = {
    page: page.value,
    page_size: paginateBy.value,
    q: query.value,
    ordering: orderingString.value,
    ...props.filters
  }

  try {
    const response = await axios.get('mutations/', {
      params
      // TODO (wvffle): Check if params should be serialized. In other similar components (Podcasts, Artists) they are
      // paramsSerializer: function (params) {
      //   return qs.stringify(params, { indices: false })
      // }
    })

    result.value = response.data
    fetchTargets()
  } catch (error) {
    // TODO (wvffle): Handle error
    result.value = null
  } finally {
    isLoading.value = false
  }
}

onSearch(() => {
  page.value = 1
  fetchData()
})

watch(page, fetchData)
onOrderingUpdate(fetchData)
fetchData()

const sharedLabels = useSharedLabels()
const { $pgettext } = useGettext()
const labels = computed(() => ({
  searchPlaceholder: $pgettext('Content/Search/Input.Placeholder', 'Search by account, summary, domain…')
}))
export default {
  methods: {
    selectPage: function (page) {
      this.page = page
    },
    handle (type, id, value) {
      if (type === 'delete') {
        this.exclude.push(id)
      }

      this.result.results.forEach((e) => {
        if (e.uuid === id) {
          e.is_approved = value
        }
      })
    },
    getCurrentState (target) {
      if (!target) {
        return {}
      }
      if (this.targets[target.type] && this.targets[target.type][String(target.id)]) {
        return this.targets[target.type][String(target.id)].currentState
      }
      return {}
    }
  }
}
</script>

<template>
  <div class="ui text container">
    <slot />
    <div class="ui inline form">
      <div class="fields">
        <div class="ui field">
          <label for="search-edits"><translate translate-context="Content/Search/Input.Label/Noun">Search</translate></label>
          <form @submit.prevent="search.query = $refs.search.value">
            <input
              id="search-edits"
              ref="search"
              name="search"
              type="text"
              :value="search.query"
              :placeholder="labels.searchPlaceholder"
            >
          </form>
        </div>
        <div class="field">
          <label for="edit-status"><translate translate-context="*/*/*">Status</translate></label>
          <select
            id="edit-status"
            class="ui dropdown"
            :value="getTokenValue('is_approved', '')"
            @change="addSearchToken('is_approved', $event.target.value)"
          >
            <option value="">
              <translate translate-context="Content/*/Dropdown">
                All
              </translate>
            </option>
            <option value="null">
              <translate translate-context="Content/Admin/*/Noun">
                Pending review
              </translate>
            </option>
            <option value="yes">
              <translate translate-context="Content/*/*/Short">
                Approved
              </translate>
            </option>
            <option value="no">
              <translate translate-context="Content/Library/*/Short">
                Rejected
              </translate>
            </option>
          </select>
        </div>
        <div class="field">
          <label for="edit-ordering"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering</translate></label>
          <select
            id="edit-ordering"
            v-model="ordering"
            class="ui dropdown"
          >
            <option
              v-for="(option, key) in orderingOptions"
              :key="key"
              :value="option[0]"
            >
              {{ sharedLabels.filters[option[1]] }}
            </option>
          </select>
        </div>
        <div class="field">
          <label for="edit-ordering-direction"><translate translate-context="Content/Search/Dropdown.Label/Noun">Order</translate></label>
          <select
            id="edit-ordering-direction"
            v-model="orderingDirection"
            class="ui dropdown"
          >
            <option value="+">
              <translate translate-context="Content/Search/Dropdown">
                Ascending
              </translate>
            </option>
            <option value="-">
              <translate translate-context="Content/Search/Dropdown">
                Descending
              </translate>
            </option>
          </select>
        </div>
      </div>
    </div>
    <div class="dimmable">
      <div
        v-if="isLoading"
        class="ui active inverted dimmer"
      >
        <div class="ui loader" />
      </div>
      <div v-else-if="result?.count > 0">
        <edit-card
          v-for="obj in result.results"
          :key="obj.uuid"
          :obj="obj"
          :current-state="getCurrentState(obj.target)"
          @deleted="handle('delete', obj.uuid, null)"
          @approved="handle('approved', obj.uuid, $event)"
        />
      </div>
      <empty-state
        v-else
        :refresh="true"
        @refresh="fetchData()"
      />
    </div>
    <div class="ui hidden divider" />
    <div>
      <pagination
        v-if="result && result.count > paginateBy"
        :compact="true"
        :current="page"
        :paginate-by="paginateBy"
        :total="result.count"
        @page-changed="selectPage"
      />

      <span v-if="result && result.results.length > 0">
        <translate
          translate-context="Content/*/Paragraph"
          :translate-params="{start: ((page-1) * paginateBy) + 1, end: ((page-1) * paginateBy) + result.results.length, total: result.count}"
        >
          Showing results %{ start }-%{ end } on %{ total }
        </translate>
      </span>
    </div>
  </div>
</template>
