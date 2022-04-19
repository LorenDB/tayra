<template>
  <div class="ui fluid category search">
    <slot /><div class="ui icon input">
      <input
        ref="search"
        :aria-label="labels.searchContent"
        type="search"
        class="prompt"
        name="search"
        :placeholder="labels.placeholder"
        @keydown.esc="$event.target.blur()"
      >
      <i class="search icon" />
    </div>
    <div class="results" />
    <slot name="after" />
  </div>
</template>

<script>
import jQuery from 'jquery'
import router from '~/router'
import { trim } from 'lodash-es'
import { useFocus } from '@vueuse/core'
import { ref } from 'vue'
import onKeyboardShortcut from '~/composables/onKeyboardShortcut'

export default {
  setup () {
    const search = ref()
    const { focused } = useFocus(search)
    onKeyboardShortcut(['shift', 'f'], () => (focused.value = true), true)

    return {
      search
    }
  },
  computed: {
    labels () {
      return {
        placeholder: this.$pgettext('Sidebar/Search/Input.Placeholder', 'Search for artists, albums, tracks…'),
        searchContent: this.$pgettext('Sidebar/Search/Input.Label', 'Search for content')
      }
    }
  },
  mounted () {
    const artistLabel = this.$pgettext('*/*/*/Noun', 'Artist')
    const albumLabel = this.$pgettext('*/*/*', 'Album')
    const trackLabel = this.$pgettext('*/*/*/Noun', 'Track')
    const tagLabel = this.$pgettext('*/*/*/Noun', 'Tag')
    const self = this
    let searchQuery

    jQuery(this.$el).keypress(function (e) {
      if (e.which === 13) {
        // Cancel any API search request to backend…
        jQuery(this.$el).search('cancel query')
        // Go direct to the artist page…
        router.push(`/search?q=${searchQuery}&type=artists`)
      }
    })

    jQuery(this.$el).search({
      type: 'category',
      minCharacters: 3,
      showNoResults: true,
      error: {
        noResultsHeader: this.$pgettext('Sidebar/Search/Error', 'No matches found'),
        noResults: this.$pgettext('Sidebar/Search/Error.Label', 'Sorry, there are no results for this search')
      },
      onSelect (result, response) {
        jQuery(self.$el).search('set value', searchQuery)
        router.push(result.routerUrl)
        jQuery(self.$el).search('hide results')
        return false
      },
      onSearchQuery (query) {
        self.$emit('search')
        searchQuery = query
      },
      apiSettings: {
        beforeXHR: function (xhrObject) {
          if (!self.$store.state.auth.authenticated) {
            return xhrObject
          }

          if (self.$store.state.auth.oauth.accessToken) {
            xhrObject.setRequestHeader('Authorization', self.$store.getters['auth/header'])
          }
          return xhrObject
        },
        onResponse: function (initialResponse) {
          const objId = self.extractObjId(searchQuery)
          const results = {}
          let isEmptyResults = true
          const categories = [
            {
              code: 'federation',
              name: self.$pgettext('*/*/*', 'Federation')
            },
            {
              code: 'podcasts',
              name: self.$pgettext('*/*/*', 'Podcasts')
            },
            {
              code: 'artists',
              route: 'library.artists.detail',
              name: artistLabel,
              getTitle (r) {
                return r.name
              },
              getDescription (r) {
                return ''
              },
              getId (t) {
                return t.id
              }
            },
            {
              code: 'albums',
              route: 'library.albums.detail',
              name: albumLabel,
              getTitle (r) {
                return r.title
              },
              getDescription (r) {
                return r.artist.name
              },
              getId (t) {
                return t.id
              }
            },
            {
              code: 'tracks',
              route: 'library.tracks.detail',
              name: trackLabel,
              getTitle (r) {
                return r.title
              },
              getDescription (r) {
                if (r.album) {
                  return `${r.album.artist.name} - ${r.album.title}`
                } else {
                  return r.artist.name
                }
              },
              getId (t) {
                return t.id
              }
            },
            {
              code: 'tags',
              route: 'library.tags.detail',
              name: tagLabel,
              getTitle (r) {
                return `#${r.name}`
              },
              getDescription (r) {
                return ''
              },
              getId (t) {
                return t.name
              }
            },
            {
              code: 'more',
              name: ''
            }
          ]
          categories.forEach(category => {
            results[category.code] = {
              name: category.name,
              results: []
            }
            if (category.code === 'federation') {
              if (objId) {
                isEmptyResults = false
                const searchMessage = self.$pgettext('Search/*/*', 'Search on the fediverse')
                results.federation = {
                  name: self.$pgettext('*/*/*', 'Federation'),
                  results: [{
                    title: searchMessage,
                    routerUrl: {
                      name: 'search',
                      query: {
                        id: objId
                      }
                    }
                  }]
                }
              }
            } else if (category.code === 'podcasts') {
              if (objId) {
                isEmptyResults = false
                const searchMessage = self.$pgettext('Search/*/*', 'Subscribe to podcast via RSS')
                results.podcasts = {
                  name: self.$pgettext('*/*/*', 'Podcasts'),
                  results: [{
                    title: searchMessage,
                    routerUrl: {
                      name: 'search',
                      query: {
                        id: objId,
                        type: 'rss'
                      }
                    }
                  }]
                }
              }
            } else if (category.code === 'more') {
              const searchMessage = self.$pgettext('Search/*/*', 'More results 🡒')
              results.more = {
                name: '',
                results: [{
                  title: searchMessage,
                  routerUrl: {
                    name: 'search',
                    query: {
                      type: 'artists',
                      q: searchQuery
                    }
                  }
                }]
              }
            } else {
              initialResponse[category.code].forEach(result => {
                isEmptyResults = false
                const id = category.getId(result)
                results[category.code].results.push({
                  title: category.getTitle(result),
                  id,
                  routerUrl: {
                    name: category.route,
                    params: {
                      id
                    }
                  },
                  description: category.getDescription(result)
                })
              })
            }
          })
          return {
            results: isEmptyResults ? {} : results
          }
        },
        url: this.$store.getters['instance/absoluteUrl']('api/v1/search?query={query}')
      }
    })
  },
  methods: {
    extractObjId (query) {
      query = trim(query)
      query = trim(query, '@')
      if (query.indexOf(' ') > -1) {
        return
      }
      if (query.startsWith('http://') || query.startsWith('https://')) {
        return query
      }
      if (query.split('@').length > 1) {
        return query
      }
    }
  }
}
</script>
