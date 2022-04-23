<script>

import { normalizeQuery, parseTokens, compileTokens } from '~/search'

export default {
  props: {
    defaultQuery: { type: String, required: false, default: '' },
    updateUrl: { type: Boolean, required: false, default: false }
  },
  watch: {
    'search.query' (newValue) {
      this.search.tokens = parseTokens(normalizeQuery(newValue))
    },
    'search.tokens': {
      handler (newValue) {
        const newQuery = compileTokens(newValue)
        if (this.updateUrl) {
          const params = {}
          if (newQuery) {
            params.q = newQuery
          }
          this.$router.replace({
            query: params
          })
        } else {
          this.search.query = newQuery
          this.page = 1
          this.fetchData()
        }
      },
      deep: true
    }
  },
  methods: {
    getTokenValue (key, fallback) {
      const matching = this.search.tokens.filter(t => {
        return t.field === key
      })
      if (matching.length > 0) {
        return matching[0].value
      }
      return fallback
    },
    addSearchToken (key, value) {
      value = String(value)
      if (!value) {
        // we remove existing matching tokens, if any
        this.search.tokens = this.search.tokens.filter(t => {
          return t.field !== key
        })
      } else {
        const existing = this.search.tokens.filter(t => {
          return t.field === key
        })
        if (existing.length > 0) {
          // we replace the value in existing tokens, if any
          existing.forEach(t => {
            t.value = value
          })
        } else {
          // we add a new token
          this.search.tokens.push({ field: key, value })
        }
      }
    }
  }
}
</script>
