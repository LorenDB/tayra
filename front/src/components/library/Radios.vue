<template>
  <main v-title="labels.title">
    <section class="ui vertical stripe segment">
      <h2 class="ui header">
        <translate translate-context="Content/Radio/Title">
          Browsing radios
        </translate>
      </h2>
      <div class="ui hidden divider" />
      <div class="ui row">
        <h3 class="ui header">
          <translate translate-context="Content/Radio/Title">
            Instance radios
          </translate>
        </h3>
        <div class="ui cards">
          <radio-card
            v-if="isAuthenticated"
            :type="'actor-content'"
            :object-id="$store.state.auth.fullUsername"
          />
          <radio-card
            v-if="isAuthenticated && hasFavorites"
            :type="'favorites'"
          />
          <radio-card :type="'random'" />
          <radio-card :type="'recently-added'" />
          <radio-card
            v-if="$store.state.auth.authenticated"
            :type="'less-listened'"
          />
        </div>
      </div>

      <div class="ui hidden divider" />
      <h3 class="ui header">
        <translate translate-context="Content/Radio/Title">
          User radios
        </translate>
      </h3>
      <router-link
        v-if="isAuthenticated"
        class="ui success button"
        to="/library/radios/build"
        exact
      >
        <translate translate-context="Content/Radio/Button.Label/Verb">
          Create your own radio
        </translate>
      </router-link>
      <div class="ui hidden divider" />
      <form
        :class="['ui', {'loading': isLoading}, 'form']"
        @submit.prevent="updateQueryString();fetchData()"
      >
        <div class="fields">
          <div class="field">
            <label for="radios-search"><translate translate-context="Content/Search/Input.Label/Noun">Search</translate></label>
            <div class="ui action input">
              <input
                id="radios-search"
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
            <label for="radios-ordering"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering</translate></label>
            <select
              id="radios-ordering"
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
            <label for="radios-ordering-direction"><translate translate-context="Content/Search/Dropdown.Label/Noun">Order</translate></label>
            <select
              id="radios-ordering-direction"
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
            <label for="radios-results"><translate translate-context="Content/Search/Dropdown.Label/Noun">Results per page</translate></label>
            <select
              id="radios-results"
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
        v-if="result && !result.results.length > 0"
        class="ui placeholder segment"
      >
        <div class="ui icon header">
          <i class="feed icon" />
          <translate translate-context="Content/Radios/Placeholder">
            No results matching your query
          </translate>
        </div>
        <router-link
          v-if="$store.state.auth.authenticated"
          :to="{name: 'library.radios.build'}"
          class="ui success button labeled icon"
        >
          <i class="rss icon" />
          <translate translate-context="Content/*/Verb">
            Create a radio
          </translate>
        </router-link>
      </div>
      <div
        v-if="result && result.results.length > 0"
        class="ui cards"
      >
        <radio-card
          v-for="radio in result.results"
          :key="radio.id"
          type="custom"
          :custom-radio="radio"
        />
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
import axios from 'axios'
import $ from 'jquery'

import OrderingMixin from '~/components/mixins/Ordering.vue'
import PaginationMixin from '~/components/mixins/Pagination.vue'
import TranslationsMixin from '~/components/mixins/Translations.vue'
import RadioCard from '~/components/radios/Card.vue'
import Pagination from '~/components/Pagination.vue'
import useLogger from '~/composables/useLogger'

const logger = useLogger()

const FETCH_URL = 'radios/radios/'

export default {
  components: {
    RadioCard,
    Pagination
  },
  mixins: [OrderingMixin, PaginationMixin, TranslationsMixin],
  props: {
    defaultQuery: { type: String, required: false, default: '' },
    scope: { type: String, required: false, default: 'all' }
  },
  data () {
    return {
      isLoading: true,
      result: null,
      page: parseInt(this.defaultPage),
      query: this.defaultQuery,
      orderingOptions: [['creation_date', 'creation_date'], ['name', 'name']]
    }
  },
  computed: {
    labels () {
      const searchPlaceholder = this.$pgettext('Content/Search/Input.Placeholder', 'Enter a radio name…')
      const title = this.$pgettext('*/*/*', 'Radios')
      return {
        searchPlaceholder,
        title
      }
    },
    isAuthenticated () {
      return this.$store.state.auth.authenticated
    },
    hasFavorites () {
      return this.$store.state.favorites.count > 0
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
        name__icontains: this.query,
        ordering: this.getOrderingAsString()
      }
      logger.debug('Fetching radios')
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
