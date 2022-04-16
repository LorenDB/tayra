<template>
  <main
    v-title="labels.title"
    class="main pusher"
  >
    <section class="ui vertical stripe segment">
      <div
        v-if="initialId"
        class="ui small text container"
      >
        <h2>{{ labels.title }}</h2>
        <remote-search-form
          :initial-id="initialId"
          :type="initialType"
        />
      </div>
      <div
        v-else
        class="ui container"
      >
        <h2>
          <label for="query">
            <translate translate-context="Content/Search/Input.Label/Noun">Search</translate>
          </label>
        </h2>
        <div class="ui two column doubling stackable grid container">
          <div class="column">
            <form
              class="ui form"
              @submit.prevent="page = 1; search()"
            >
              <div class="ui field">
                <div class="ui action input">
                  <input
                    id="query"
                    v-model="query"
                    class="ui input"
                    name="query"
                    type="text"
                  >
                  <button
                    :aria-label="labels.submitSearch"
                    type="submit"
                    class="ui icon button"
                  >
                    <i class="search icon" />
                  </button>
                </div>
              </div>
            </form>
          </div>
          <div class="column">
            <radio-button
              v-if="currentResults && currentConfigValidated && ( type === 'tags' || type === 'artists' ) "
              class="ui right floated medium button"
              type="custom_multiple"
              :config="currentConfig"
            />
          </div>
        </div>
        <div class="ui secondary pointing menu">
          <a
            v-for="t in types"
            :key="t.id"
            :class="['item', {active: type === t.id}]"
            href=""
            @click.prevent="type = t.id"
          >
            {{ t.label }}
            <span
              v-if="results[t.id]"
              class="ui circular mini right floated label"
            >
              {{ results[t.id].count }}</span>
          </a>
        </div>
        <div v-if="isLoading">
          <div
            v-if="isLoading"
            class="ui inverted active dimmer"
          >
            <div class="ui loader" />
          </div>
        </div>

        <empty-state
          v-else-if="!currentResults || currentResults.count === 0"
          :refresh="true"
          @refresh="search"
        />

        <div
          v-else-if="type === 'artists' || type === 'podcasts'"
          class="ui five app-cards cards"
        >
          <artist-card
            v-for="artist in currentResults.results"
            :key="artist.id"
            :artist="artist"
          />
        </div>

        <div
          v-else-if="type === 'albums' || type === 'series'"
          class="ui five app-cards cards"
        >
          <album-card
            v-for="album in currentResults.results"
            :key="album.id"
            :album="album"
          />
        </div>
        <track-table
          v-else-if="type === 'tracks'"
          :tracks="currentResults.results"
        />
        <playlist-card-list
          v-else-if="type === 'playlists'"
          :playlists="currentResults.results"
        />
        <div
          v-else-if="type === 'radios'"
          class="ui cards"
        >
          <radio-card
            v-for="radio in currentResults.results"
            :key="radio.id"
            type="custom"
            :custom-radio="radio"
          />
        </div>
        <tags-list
          v-else-if="type === 'tags'"
          :truncate-size="200"
          :limit="paginateBy"
          :tags="currentResults.results.map(t => {return t.name })"
        />

        <pagination
          v-if="currentResults && currentResults.count > paginateBy"
          :current="page"
          :paginate-by="paginateBy"
          :total="currentResults.count"
          @page-changed="page = $event"
        />
      </div>
    </section>
  </main>
</template>

<script>
import RemoteSearchForm from '@/components/RemoteSearchForm.vue'
import ArtistCard from '@/components/audio/artist/Card.vue'
import AlbumCard from '@/components/audio/album/Card.vue'
import TrackTable from '@/components/audio/track/Table.vue'
import Pagination from '@/components/Pagination.vue'
import PlaylistCardList from '@/components/playlists/CardList.vue'
import RadioButton from '@/components/radios/Button.vue'
import RadioCard from '@/components/radios/Card.vue'
import TagsList from '@/components/tags/List.vue'

import axios from 'axios'

export default {
  components: {
    RemoteSearchForm,
    ArtistCard,
    AlbumCard,
    TrackTable,
    Pagination,
    PlaylistCardList,
    RadioCard,
    RadioButton,
    TagsList
  },
  props: {
    initialId: { type: String, required: false, default: '' },
    initialType: { type: String, required: false, default: '' },
    initialQuery: { type: String, required: false, default: '' },
    initialPage: { type: Number, required: false, default: 0 }
  },
  data () {
    return {
      query: this.initialQuery,
      type: this.initialType,
      page: this.initialPage,
      results: {
        artists: null,
        albums: null,
        tracks: null,
        playlists: null,
        radios: null,
        tags: null,
        podcasts: null,
        series: null
      },
      isLoading: false,
      paginateBy: 25,
      config: null
    }
  },
  computed: {
    labels () {
      const submitSearch = this.$pgettext('Content/Search/Button.Label/Verb', 'Submit Search Query')
      let title = this.$pgettext('Content/Search/Input.Label/Noun', 'Search')
      if (this.initialId) {
        title = this.$pgettext('Head/Fetch/Title', 'Search a remote object')
        if (this.type === 'rss') {
          title = this.$pgettext('Head/Fetch/Title', 'Subscribe to a podcast RSS feed')
        }
      }
      return {
        title,
        submitSearch
      }
    },
    axiosParams () {
      const params = new URLSearchParams()
      params.append('q', this.query)
      params.append('page', this.page)
      params.append('page_size', this.paginateBy)
      if (this.currentType.contentCategory !== undefined) { params.append('content_category', this.currentType.contentCategory) }
      if (this.currentType.includeChannels !== undefined) { params.append('include_channels', this.currentType.includeChannels) }
      return params
    },
    types () {
      return [
        {
          id: 'artists',
          label: this.$pgettext('*/*/*/Noun', 'Artists'),
          includeChannels: true,
          contentCategory: 'music'
        },
        {
          id: 'albums',
          label: this.$pgettext('*/*/*', 'Albums'),
          includeChannels: true,
          contentCategory: 'music'
        },
        {
          id: 'tracks',
          label: this.$pgettext('*/*/*', 'Tracks')
        },
        {
          id: 'playlists',
          label: this.$pgettext('*/*/*', 'Playlists')
        },
        {
          id: 'radios',
          label: this.$pgettext('*/*/*', 'Radios'),
          endpoint: 'radios/radios'
        },
        {
          id: 'tags',
          label: this.$pgettext('*/*/*', 'Tags')
        },
        {
          id: 'podcasts',
          label: this.$pgettext('*/*/*', 'Podcasts'),
          endpoint: '/artists',
          contentCategory: 'podcast',
          includeChannels: true
        },
        {
          id: 'series',
          label: this.$pgettext('*/*/*', 'Series'),
          endpoint: '/albums',
          includeChannels: true,
          contentCategory: 'podcast'
        }
      ]
    },
    currentType () {
      return this.types.filter(t => {
        return t.id === this.type
      })[0]
    },
    currentResults () {
      return this.results[this.currentType.id]
    },
    currentConfig () {
      const resultDict = this.currentResults.results
      return this.generateConfig(this.currentType.id, resultDict)
    },
    currentConfigValidated () {
      const configValidate = this.currentConfig
      const array = configValidate[0][Object.keys(configValidate[0])[1]]
      return array.length >= 1
    }
  },
  watch: {
    async type () {
      this.page = 1
      this.updateQueryString()
      await this.search()
    },
    async page () {
      this.updateQueryString()
      await this.search()
    },
    '$route.query.q': async function (v) {
      this.query = v
      this.updateQueryString()
      await this.search()
    }
  },
  created () {
    this.search()
  },
  methods: {
    async search () {
      this.updateQueryString()
      if (!this.query) {
        this.types.forEach(t => {
          this.results[t.id] = null
        })
        return
      }
      this.isLoading = true
      const response = await axios.get(
        this.currentType.endpoint || this.currentType.id,
        { params: this.axiosParams }
      )
      this.results[this.currentType.id] = response.data
      this.isLoading = false
      this.types.forEach(t => {
        if (t.id !== this.currentType.id) {
          axios.get(t.endpoint || t.id, {
            params: {
              q: this.query,
              page_size: 1,
              content_category: t.contentCategory,
              include_channels: t.includeChannels
            }
          }).then(response => {
            this.results[t.id] = response.data
          })
        }
      })
    },
    updateQueryString: function () {
      history.pushState(
        {},
        null,
        this.$route.path + '?' + new URLSearchParams(
          {
            q: this.query,
            page: this.page,
            type: this.type
          }).toString()
      )
    },
    generateConfig: function (type, resultDict) {
      const obj = {
        type: type.slice(0, -1)
      }
      switch (type) {
        case 'tags':
          obj.names = this.generateTagConfig(resultDict, type)
          break
        case 'artists':
          obj.ids = this.generateArtistConfig(resultDict, type)
          break
        default:
          console.info('This type is not yet supported for radio')
          obj.ids = 0
      }
      return [obj]
    },
    generateTagConfig: function (resultDict, type) {
      return Object.values(resultDict).map(({ name }) => name)
    },
    generateArtistConfig: function (resultDict, type) {
      return Object.values(resultDict).map(({ id }) => id)
    }
  }
}
</script>
