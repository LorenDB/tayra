<template>
  <main
    v-title="labels.title"
    class="main pusher"
  >
    <section class="ui vertical center aligned stripe segment">
      <div :class="['ui', {'active': isLoading}, 'inverted', 'dimmer']">
        <div class="ui text loader">
          <translate translate-context="Content/Favorites/Message">
            Loading your favorites…
          </translate>
        </div>
      </div>
      <h2
        v-if="results"
        class="ui center aligned icon header"
      >
        <i class="circular inverted heart pink icon" />
        <translate
          translate-plural="%{ count } favorites"
          :translate-n="$store.state.favorites.count"
          :translate-params="{count: results.count}"
          translate-context="Content/Favorites/Title"
        >
          %{ count } favorite
        </translate>
      </h2>
      <radio-button
        v-if="hasFavorites"
        type="favorites"
      />
    </section>
    <section
      v-if="hasFavorites"
      class="ui vertical stripe segment"
    >
      <div :class="['ui', {'loading': isLoading}, 'form']">
        <div class="fields">
          <div class="field">
            <label for="favorites-ordering"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering</translate></label>
            <select
              id="favorites-ordering"
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
            <label for="favorites-ordering-direction"><translate translate-context="Content/Search/Dropdown.Label/Noun">Order</translate></label>
            <select
              id="favorites-ordering-direction"
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
            <label for="favorites-results"><translate translate-context="Content/Search/Dropdown.Label/Noun">Results per page</translate></label>
            <select
              id="favorites-results"
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
      </div>
      <track-table
        v-if="results"
        :show-artist="true"
        :show-album="true"
        :tracks="results.results"
      />
      <div class="ui center aligned basic segment">
        <pagination
          v-if="results && results.count > paginateBy"
          :current="page"
          :paginate-by="paginateBy"
          :total="results.count"
          @page-changed="selectPage"
        />
      </div>
    </section>
    <div
      v-else
      class="ui placeholder segment"
    >
      <div class="ui icon header">
        <i class="broken heart icon" />
        <translate
          translate-context="Content/Home/Placeholder"
        >
          No tracks have been added to your favorites yet
        </translate>
      </div>
      <router-link
        :to="'/library'"
        class="ui success labeled icon button"
      >
        <i class="headphones icon" />
        <translate translate-context="Content/*/Verb">
          Browse the library
        </translate>
      </router-link>
    </div>
  </main>
</template>

<script>
import axios from 'axios'
import $ from 'jquery'
import RadioButton from '~/components/radios/Button.vue'
import Pagination from '~/components/Pagination.vue'
import OrderingMixin from '~/components/mixins/Ordering.vue'
import PaginationMixin from '~/components/mixins/Pagination.vue'
import TranslationsMixin from '~/components/mixins/Translations.vue'
import { checkRedirectToLogin } from '~/utils'
import TrackTable from '~/components/audio/track/Table.vue'
import useLogger from '~/composables/useLogger'

const logger = useLogger()

const FAVORITES_URL = 'tracks/'

export default {
  components: {
    RadioButton,
    Pagination,
    TrackTable
  },
  mixins: [OrderingMixin, PaginationMixin, TranslationsMixin],
  data () {
    return {
      results: null,
      isLoading: false,
      nextLink: null,
      previousLink: null,
      page: parseInt(this.defaultPage),
      orderingOptions: [
        ['creation_date', 'creation_date'],
        ['title', 'track_title'],
        ['album__title', 'album_title'],
        ['artist__name', 'artist_name']
      ]
    }
  },
  computed: {
    labels () {
      return {
        title: this.$pgettext('Head/Favorites/Title', 'Your Favorites')
      }
    },
    hasFavorites () {
      return this.$store.state.favorites.count > 0
    }
  },
  watch: {
    page: function () {
      this.updateQueryString()
    },
    paginateBy: function () {
      this.updateQueryString()
    },
    orderingDirection: function () {
      this.updateQueryString()
    },
    ordering: function () {
      this.updateQueryString()
    }
  },
  async created () {
    await checkRedirectToLogin(this.$store, this.$router)
    this.fetchFavorites(FAVORITES_URL)
  },
  mounted () {
    $('.ui.dropdown').dropdown()
  },
  methods: {
    updateQueryString: function () {
      this.$router.replace({
        query: {
          page: this.page,
          paginateBy: this.paginateBy,
          ordering: this.getOrderingAsString()
        }
      })
      this.fetchFavorites(FAVORITES_URL)
    },
    fetchFavorites (url) {
      const self = this
      this.isLoading = true
      const params = {
        favorites: 'true',
        page: this.page,
        page_size: this.paginateBy,
        ordering: this.getOrderingAsString()
      }
      logger.time('Loading user favorites')
      axios.get(url, { params: params }).then(response => {
        self.results = response.data
        self.nextLink = response.data.next
        self.previousLink = response.data.previous
        self.results.results.forEach(track => {
          self.$store.commit('favorites/track', { id: track.id, value: true })
        })
        logger.timeEnd('Loading user favorites')
        self.isLoading = false
      })
    },
    selectPage: function (page) {
      this.page = page
    }
  }
}
</script>
