<script setup lang="ts">
import axios from 'axios'
import Pagination from '~/components/vui/Pagination.vue'
import ActionTable from '~/components/common/ActionTable.vue'
import useSharedLabels from '~/composables/locale/useSharedLabels'
import useSmartSearch, { SmartSearchProps } from '~/composables/useSmartSearch'
import useOrdering, { OrderingProps } from '~/composables/useOrdering'
import { OrderingField } from '~/store/ui'
import { computed, ref, watch } from 'vue'
import { useGettext } from 'vue3-gettext'

interface Props extends SmartSearchProps, OrderingProps {
  // TODO (wvffle): find object type
  filters?: object
}

const props = withDefaults(defineProps<Props>(), {
  defaultQuery: '',
  updateUrl: false,
  filters: () => ({})
})

// TODO (wvffle): Make sure everything is it's own type
const page = ref(1)
type ResponseType = { count: number, results: any[] }
const result = ref<null | ResponseType>(null)

const { onSearch, query, addSearchToken, getTokenValue } = useSmartSearch(props.defaultQuery, props.updateUrl)
const { onOrderingUpdate, orderingString, paginateBy, ordering, orderingDirection } = useOrdering(props.orderingConfigName)

const orderingOptions: [OrderingField, keyof typeof sharedLabels.filters][] = [
  ['creation_date', 'creation_date'],
  ['followers_count', 'followers'],
  ['uploads_count', 'uploads']
]

const { $pgettext } = useGettext()
const actionFilters = computed(() => ({ q: query.value, ...props.filters }))
const actions = [
  {
    name: 'delete',
    label: $pgettext('*/*/*/Verb', 'Delete'),
    confirmationMessage: $pgettext('Popup/*/Paragraph', 'The selected library will be removed, as well as associated uploads and follows. This action is irreversible.'),
    isDangerous: true,
    allowAll: false,
    confirmColor: 'danger'
  }
]

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
    const response = await axios.get('/manage/library/libraries/', {
      params
      // TODO (wvffle): Check if params should be serialized. In other similar components (Podcasts, Artists) they are
      // paramsSerializer: function (params) {
      //   return qs.stringify(params, { indices: false })
      // }
    })

    result.value = response.data
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
const labels = computed(() => ({
  searchPlaceholder: $pgettext('Content/Search/Input.Placeholder', 'Search by domain, actor, name, description…')
}))
</script>

<template>
  <div>
    <div class="ui inline form">
      <div class="fields">
        <div class="ui six wide field">
          <label for="libraries-search"><translate translate-context="Content/Search/Input.Label/Noun">Search</translate></label>
          <form @submit.prevent="query = $refs.search.value">
            <input
              id="libraries-search"
              ref="search"
              name="search"
              type="text"
              :value="query"
              :placeholder="labels.searchPlaceholder"
            >
          </form>
        </div>
        <div class="field">
          <label for="libraries-visibility"><translate translate-context="*/*/*">Visibility</translate></label>
          <select
            id="libraries-visibility"
            class="ui dropdown"
            :value="getTokenValue('privacy_level', '')"
            @change="addSearchToken('privacy_level', ($event.target as HTMLSelectElement).value)"
          >
            <option value="">
              <translate translate-context="Content/*/Dropdown">
                All
              </translate>
            </option>
            <option value="me">
              {{ sharedLabels.fields.privacy_level.shortChoices.me }}
            </option>
            <option value="instance">
              {{ sharedLabels.fields.privacy_level.shortChoices.instance }}
            </option>
            <option value="everyone">
              {{ sharedLabels.fields.privacy_level.shortChoices.everyone }}
            </option>
          </select>
        </div>
        <div class="field">
          <label for="libraries-ordering"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering</translate></label>
          <select
            id="libraries-ordering"
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
          <label for="libraries-ordering-direction"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering direction</translate></label>
          <select
            id="libraries-ordering-direction"
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
      <action-table
        v-if="result"
        :objects-data="result"
        :actions="actions"
        action-url="manage/library/libraries/action/"
        :filters="actionFilters"
        @action-launched="fetchData"
      >
        <template #header-cells>
          <th>
            <translate translate-context="*/*/*/Noun">
              Name
            </translate>
          </th>
          <th>
            <translate translate-context="*/*/*/Noun">
              Account
            </translate>
          </th>
          <th>
            <translate translate-context="Content/Moderation/*/Noun">
              Domain
            </translate>
          </th>
          <th>
            <translate translate-context="*/*/*">
              Visibility
            </translate>
          </th>
          <th>
            <translate translate-context="*/*/*">
              Uploads
            </translate>
          </th>
          <th>
            <translate translate-context="Content/Federation/*/Noun">
              Followers
            </translate>
          </th>
          <th>
            <translate translate-context="Content/*/*/Noun">
              Creation date
            </translate>
          </th>
        </template>
        <template
          #row-cells="scope"
        >
          <td>
            <router-link :to="{name: 'manage.library.libraries.detail', params: {id: scope.obj.uuid }}">
              {{ scope.obj.name }}
            </router-link>
          </td>
          <td>
            <router-link :to="{name: 'manage.moderation.accounts.detail', params: {id: scope.obj.actor.full_username }}">
              <i class="wrench icon" />
            </router-link>
            <a
              href=""
              class="discrete link"
              :title="scope.obj.actor.full_username"
              @click.prevent="addSearchToken('account', scope.obj.actor.full_username)"
            >{{ scope.obj.actor.preferred_username }}</a>
          </td>
          <td>
            <template v-if="!scope.obj.is_local">
              <router-link :to="{name: 'manage.moderation.domains.detail', params: {id: scope.obj.domain }}">
                <i class="wrench icon" />
              </router-link>
              <a
                href=""
                class="discrete link"
                :title="scope.obj.domain"
                @click.prevent="addSearchToken('domain', scope.obj.domain)"
              >{{ scope.obj.domain }}</a>
            </template>
            <a
              v-else
              href=""
              class="ui tiny accent icon link label"
              @click.prevent="addSearchToken('domain', scope.obj.domain)"
            >
              <i class="home icon" />
              <translate translate-context="Content/Moderation/*/Short, Noun">Local</translate>
            </a>
          </td>
          <td>
            <a
              href=""
              class="discrete link"
              :title="sharedLabels.fields.privacy_level.shortChoices[scope.obj.privacy_level]"
              @click.prevent="addSearchToken('privacy_level', scope.obj.privacy_level)"
            >
              {{ sharedLabels.fields.privacy_level.shortChoices[scope.obj.privacy_level] }}
            </a>
          </td>
          <td>
            {{ scope.obj.uploads_count }}
          </td>
          <td>
            {{ scope.obj.followers_count }}
          </td>
          <td>
            <human-date :date="scope.obj.creation_date" />
          </td>
        </template>
      </action-table>
    </div>
    <div>
      <pagination
        v-if="result && result.count > paginateBy"
        v-model:current="page"
        :compact="true"
        :paginate-by="paginateBy"
        :total="result.count"
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
