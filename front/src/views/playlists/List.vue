<template>
  <main v-title="labels.playlists">
    <section class="ui vertical stripe segment">
      <h2 class="ui header">
        <translate translate-context="Content/Playlist/Title">
          Browsing playlists
        </translate>
      </h2>
      <template v-if="$store.state.auth.authenticated">
        <button
          class="ui success button"
          @click="$store.commit('playlists/chooseTrack', null)"
        >
          <translate translate-context="Content/Playlist/Button.Label/Verb">
            Manage your playlists
          </translate>
        </button>
        <div class="ui hidden divider" />
      </template>
      <form
        :class="['ui', {'loading': isLoading}, 'form']"
        @submit.prevent="updateQueryString();fetchData()"
      >
        <div class="fields">
          <div class="field">
            <label for="playlists-search"><translate translate-context="Content/Search/Input.Label/Noun">Search</translate></label>
            <div class="ui action input">
              <input
                id="playlists-search"
                v-model="query"
                stype="text"
                name="search"
                :placeholder="labels.searchPlaceholder"
              >
              <button
                class="ui icon button"
                type="submit"
                :aria-label="$pgettext('Content/Search/Input.Label/Noun', 'Search')"
              >
                <i class="search icon" />
              </button>
            </div>
          </div>
          <div class="field">
            <label for="playlists-ordering"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering</translate></label>
            <select
              id="playlists-ordering"
              v-model="ordering"
              class="ui dropdown"
            >
              <option
                v-for="option in orderingOptions"
                :key="option[0]"
                :value="option[0]"
              >
                {{ sharedLabels.filters[option[1]] }}
              </option>
            </select>
          </div>
          <div class="field">
            <label for="playlists-ordering-direction"><translate translate-context="Content/Search/Dropdown.Label/Noun">Order</translate></label>
            <select
              id="playlists-ordering-direction"
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
          <div class="field">
            <label for="playlists-results"><translate translate-context="Content/Search/Dropdown.Label/Noun">Results per page</translate></label>
            <select
              id="playlists-results"
              v-model="paginateBy"
              class="ui dropdown"
            >
              <option :value="parseInt(12)">
                12
              </option>
              <option :value="parseInt(25)">
                25
              </option>
              <option :value="parseInt(50)">
                50
              </option>
            </select>
          </div>
        </div>
      </form>
      <div class="ui hidden divider" />
      <playlist-card-list
        v-if="result && result.results.length > 0"
        :playlists="result.results"
      />
      <div
        v-else-if="result && !result.results.length > 0"
        class="ui placeholder segment sixteen wide column"
        style="text-align: center; display: flex; align-items: center"
      >
        <div class="ui icon header">
          <i class="list icon" />
          <translate translate-context="Content/Playlists/Placeholder">
            No results matching your query
          </translate>
        </div>
        <button
          v-if="$store.state.auth.authenticated"
          class="ui success button labeled icon"
          @click="$store.commit('playlists/chooseTrack', null)"
        >
          <i class="list icon" />
          <translate translate-context="Content/*/Verb">
            Create a playlist
          </translate>
        </button>
      </div>
      <div class="ui center aligned basic segment">
        <pagination
          v-if="result && result.results.length > 0"
          :current="page"
          :paginate-by="paginateBy"
          :total="result.count"
          @page-changed="selectPage"
        />
      </div>
    </section>
  </main>
</template>

<script>
import axios from 'axios'
import $ from 'jquery'

import OrderingMixin from '~/components/mixins/Ordering.vue'
import PaginationMixin from '~/components/mixins/Pagination.vue'
import PlaylistCardList from '~/components/playlists/CardList.vue'
import Pagination from '~/components/Pagination.vue'
import useSharedLabels from '../../composables/useSharedLabels'

const FETCH_URL = 'playlists/'

export default {
  components: {
    PlaylistCardList,
    Pagination
  },
  mixins: [OrderingMixin, PaginationMixin],
  props: {
    defaultQuery: { type: String, required: false, default: '' },
    scope: { type: String, required: false, default: 'all' }
  },
  setup () {
    const sharedLabels = useSharedLabels()
    return { sharedLabels }
  },
  data () {
    return {
      isLoading: true,
      result: null,
      page: parseInt(this.defaultPage),
      query: this.defaultQuery,
      orderingOptions: [
        ['creation_date', 'creation_date'],
        ['modification_date', 'modification_date'],
        ['name', 'name']
      ]
    }
  },
  computed: {
    labels () {
      const playlists = this.$pgettext('*/*/*', 'Playlists')
      const searchPlaceholder = this.$pgettext('Content/Playlist/Placeholder/Call to action', 'Enter playlist name…')
      return {
        playlists,
        searchPlaceholder
      }
    }
  },
  watch: {
    page () {
      this.updateQueryString()
      this.fetchData()
    }
  },
  created () {
    this.fetchData()
  },
  mounted () {
    $('.ui.dropdown').dropdown()
  },
  methods: {
    updateQueryString: function () {
      history.pushState(
        {},
        null,
        this.$route.path + '?' + new URLSearchParams(
          {
            query: this.query,
            page: this.page,
            paginateBy: this.paginateBy,
            ordering: this.getOrderingAsString()
          }).toString()
      )
    },
    fetchData: function () {
      const self = this
      this.isLoading = true
      const url = FETCH_URL
      const params = {
        scope: this.scope,
        page: this.page,
        page_size: this.paginateBy,
        q: this.query,
        ordering: this.getOrderingAsString(),
        playable: true
      }
      axios.get(url, { params: params }).then(response => {
        self.result = response.data
        self.isLoading = false
      })
    },
    selectPage: function (page) {
      this.page = page
    }
  }
}
</script>
