<template>
  <main v-title="labels.title">
    <section class="ui vertical stripe segment">
      <h2 class="ui header">
        <translate translate-context="Content/Podcasts/Title">
          Browsing podcasts
        </translate>
      </h2>
      <form
        :class="['ui', {'loading': isLoading}, 'form']"
        @submit.prevent="updatePage();updateQueryString();fetchData()"
      >
        <div class="fields">
          <div class="field">
            <label for="artist-search">
              <translate translate-context="Content/Search/Input.Label/Noun">Podcast title</translate>
            </label>
            <div class="ui action input">
              <input
                id="artist-search"
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
            <label for="artist-ordering"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering</translate></label>
            <select
              id="artist-ordering"
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
            <label for="artist-ordering-direction"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering direction</translate></label>
            <select
              id="artist-ordering-direction"
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
            <label for="artist-results"><translate translate-context="Content/Search/Dropdown.Label/Noun">Results per page</translate></label>
            <select
              id="artist-results"
              v-model="paginateBy"
              class="ui dropdown"
            >
              <option :value="parseInt(12)">
                12
              </option>
              <option :value="parseInt(30)">
                30
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
        v-if="result && result.results.length > 0"
        class="ui five app-cards cards"
      >
        <div
          v-if="isLoading"
          class="ui inverted active dimmer"
        >
          <div class="ui loader" />
        </div>
        <artist-card
          v-for="artist in result.results"
          :key="artist.id"
          :artist="artist"
        />
      </div>
      <div
        v-else-if="!isLoading"
        class="ui placeholder segment sixteen wide column"
        style="text-align: center; display: flex; align-items: center"
      >
        <div class="ui icon header">
          <i class="podcast icon" />
          <translate translate-context="Content/Artists/Placeholder">
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
            Create a Channel
          </translate>
        </router-link>
        <h1
          v-if="$store.state.auth.authenticated"
          class="ui with-actions header"
        >
          <div class="actions">
            <a @click.stop.prevent="showSubscribeModal = true">
              <i class="plus icon" />
              <translate translate-context="Content/Profile/Button">Subscribe to feed</translate>
            </a>
          </div>
        </h1>
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
    <modal
      v-model:show="showSubscribeModal"
      class="tiny"
      :fullscreen="false"
    >
      <h2 class="header">
        <translate translate-context="*/*/*/Noun">
          Subscription
        </translate>
      </h2>
      <div
        ref="modalContent"
        class="scrolling content"
      >
        <remote-search-form
          type="both"
          :show-submit="false"
          :standalone="false"
          :redirect="true"
          @subscribed="showSubscribeModal = false; fetchData()"
        />
      </div>
      <div class="actions">
        <button class="ui basic deny button">
          <translate translate-context="*/*/Button.Label/Verb">
            Cancel
          </translate>
        </button>
        <button
          form="remote-search"
          type="submit"
          class="ui primary button"
        >
          <i class="bookmark icon" />
          <translate translate-context="*/*/*/Verb">
            Subscribe
          </translate>
        </button>
      </div>
    </modal>
  </main>
</template>

<script>
import qs from 'qs'
import axios from 'axios'
import $ from 'jquery'

import OrderingMixin from '~/components/mixins/Ordering.vue'
import PaginationMixin from '~/components/mixins/Pagination.vue'
import ArtistCard from '~/components/audio/artist/Card.vue'
import Pagination from '~/components/Pagination.vue'
import TagsSelector from '~/components/library/TagsSelector.vue'
import Modal from '~/components/semantic/Modal.vue'
import RemoteSearchForm from '~/components/RemoteSearchForm.vue'
import useLogger from '~/composables/useLogger'
import useSharedLabels from '~/composables/locale/useSharedLabels'

const logger = useLogger()

const FETCH_URL = 'artists/'

export default {
  components: {
    ArtistCard,
    Pagination,
    TagsSelector,
    RemoteSearchForm,
    Modal
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
      orderingOptions: [['creation_date', 'creation_date'], ['name', 'name']],
      showSubscribeModal: false
    }
  },
  computed: {
    labels () {
      const searchPlaceholder = this.$pgettext('Content/Search/Input.Placeholder', 'Search…')
      const title = this.$pgettext('*/*/*/Noun', 'Podcasts')
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
    },
    excludeCompilation () {
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
            ordering: this.getOrderingAsString(),
            include_channels: true,
            content_category: 'podcast'
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
        has_albums: this.excludeCompilation,
        q: this.query,
        ordering: this.getOrderingAsString(),
        playable: 'true',
        tag: this.tags,
        include_channels: 'true',
        content_category: 'podcast'
      }
      logger.debug('Fetching artists')
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
