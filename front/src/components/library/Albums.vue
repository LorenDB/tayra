<template>
  <main v-title="labels.title">
    <section class="ui vertical stripe segment">
      <h2 class="ui header">
        <translate translate-context="Content/Album/Title">
          Browsing albums
        </translate>
      </h2>
      <form
        :class="['ui', {'loading': isLoading}, 'form']"
        @submit.prevent="updatePage();updateQueryString();fetchData()"
      >
        <div class="fields">
          <div class="field">
            <label for="albums-search">
              <translate translate-context="Content/Search/Input.Label/Noun">Search</translate>
            </label>
            <div class="ui action input">
              <input
                id="albums-search"
                v-model="query"
                type="text"
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
            <label for="tags-search"><translate translate-context="*/*/*/Noun">Tags</translate></label>
            <tags-selector v-model="tags" />
          </div>
          <div class="field">
            <label for="album-ordering"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering</translate></label>
            <select
              id="album-ordering"
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
            <label for="album-ordering-direction"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering direction</translate></label>
            <select
              id="album-ordering-direction"
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
            <label for="album-results"><translate translate-context="Content/Search/Dropdown.Label/Noun">Results per page</translate></label>
            <select
              id="album-results"
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
      <div
        v-if="result"
        transition-duration="0"
        item-selector=".column"
        percent-position="true"
        stagger="0"
        class=""
      >
        <div
          v-if="result.results.length > 0"
          class="ui app-cards cards"
        >
          <album-card
            v-for="album in result.results"
            :key="album.id"
            :album="album"
          />
        </div>
        <div
          v-else
          class="ui placeholder segment sixteen wide column"
          style="text-align: center; display: flex; align-items: center"
        >
          <div class="ui icon header">
            <i class="compact disc icon" />
            <translate translate-context="Content/Albums/Placeholder">
              No results matching your query
            </translate>
          </div>
          <router-link
            v-if="$store.state.auth.authenticated"
            :to="{name: 'content.index'}"
            class="ui success button labeled icon"
          >
            <i class="upload icon" />
            <translate translate-context="Content/*/Verb">
              Add some music
            </translate>
          </router-link>
        </div>
      </div>
      <div class="ui center aligned basic segment">
        <pagination
          v-if="result && result.count > paginateBy"
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
import qs from 'qs'
import axios from 'axios'
import $ from 'jquery'

import OrderingMixin from '~/components/mixins/Ordering.vue'
import PaginationMixin from '~/components/mixins/Pagination.vue'
import AlbumCard from '~/components/audio/album/Card.vue'
import Pagination from '~/components/Pagination.vue'
import TagsSelector from '~/components/library/TagsSelector.vue'
import useLogger from '~/composables/useLogger'
import useSharedLabels from '../../composables/useSharedLabels'

const logger = useLogger()

const FETCH_URL = 'albums/'

export default {
  components: {
    AlbumCard,
    Pagination,
    TagsSelector
  },
  mixins: [OrderingMixin, PaginationMixin],
  props: {
    defaultQuery: { type: String, required: false, default: '' },
    defaultTags: { type: Array, required: false, default: () => { return [] } },
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
      tags: (this.defaultTags || []).filter((t) => { return t.length > 0 }),
      orderingOptions: [['creation_date', 'creation_date'], ['title', 'album_title'], ['release_date', 'release_date']]
    }
  },
  computed: {
    labels () {
      const searchPlaceholder = this.$pgettext('Content/Search/Input.Placeholder', 'Enter album title…')
      const title = this.$pgettext('*/*/*', 'Albums')
      return {
        searchPlaceholder,
        title
      }
    }
  },
  watch: {
    page () {
      this.updateQueryString()
      this.fetchData()
    },
    '$store.state.moderation.lastUpdate': function () {
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
            tag: this.tags,
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
        playable: 'true',
        tag: this.tags,
        include_channels: 'true',
        content_category: 'music'
      }
      logger.debug('Fetching albums')
      axios.get(
        url,
        {
          params: params,
          paramsSerializer: function (params) {
            return qs.stringify(params, { indices: false })
          }
        }
      ).then(response => {
        self.result = response.data
        self.isLoading = false
      }, () => {
        self.result = null
        self.isLoading = false
      })
    },
    selectPage: function (page) {
      this.page = page
    },
    updatePage () {
      this.page = this.defaultPage
    }
  }
}
</script>
