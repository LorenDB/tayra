<template>
  <div
    v-if="type === 'both' || type === undefined"
    class="two ui buttons"
  >
    <button
      class="ui left floated labeled icon button"
      @click.prevent="changeType('rss')"
    >
      <i class="feed icon" />
      <translate translate-context="Content/Search/Input.Label/Noun">
        RSS
      </translate>
    </button>
    <div class="or" />
    <button
      class="ui right floated right labeled icon button"
      @click.prevent="changeType('artists')"
    >
      <i class="globe icon" />
      <translate translate-context="Content/Search/Input.Label/Noun">
        Fediverse
      </translate>
    </button>
  </div>
  <div v-else>
    <form
      id="remote-search"
      :class="['ui', {loading: isLoading}, 'form']"
      @submit.stop.prevent="submit"
    >
      <div
        v-if="errors.length > 0"
        role="alert"
        class="ui negative message"
      >
        <h3 class="header">
          <translate translate-context="Content/*/Error message.Title">
            Error while fetching object
          </translate>
        </h3>
        <ul class="list">
          <li
            v-for="(error, key) in errors"
            :key="key"
          >
            {{ error }}
          </li>
        </ul>
      </div>
      <div class="ui required field">
        <label for="object-id">
          {{ labels.fieldLabel }}
        </label>
        <p v-if="type === 'rss'">
          <translate translate-context="Content/Fetch/Paragraph">
            Use this form to subscribe to an RSS feed from its URL.
          </translate>
        </p>
        <p v-else-if="type === 'artists'">
          <translate translate-context="Content/Fetch/Paragraph">
            Use this form to subscribe to a channel hosted somewhere else on the Fediverse.
          </translate>
        </p>
        <input
          id="object-id"
          v-model="id"
          type="text"
          name="object-id"
          :placeholder="labels.fieldPlaceholder"
          required
        >
      </div>
      <button
        v-if="showSubmit"
        type="submit"
        :class="['ui', 'primary', {loading: isLoading}, 'button']"
        :disabled="isLoading || !id || id.length === 0 || null"
      >
        <translate translate-context="Content/Search/Input.Label/Noun">
          Search
        </translate>
      </button>
    </form>
    <div
      v-if="!isLoading && fetch && fetch.status === 'finished' && !redirectRoute"
      role="alert"
      class="ui warning message"
    >
      <p>
        <translate translate-context="Content/*/Error message.Title">
          This kind of object isn't supported yet
        </translate>
      </p>
    </div>
  </div>
</template>
<script>
import axios from 'axios'

export default {
  props: {
    initialId: { type: String, required: false, default: '' },
    initialType: { type: String, required: false, default: '' },
    redirect: { type: Boolean, default: true },
    showSubmit: { type: Boolean, default: true },
    standalone: { type: Boolean, default: true }
  },

  data () {
    return {
      type: this.initialType,
      id: this.initialId,
      fetch: null,
      obj: null,
      isLoading: false,
      errors: []
    }
  },
  computed: {
    labels () {
      let title = ''
      let fieldLabel = ''
      let fieldPlaceholder = ''
      if (this.type === 'rss') {
        title = this.$pgettext('Head/Fetch/Title', 'Subscribe to a podcast RSS feed')
        fieldLabel = this.$pgettext('*/*/*', 'RSS feed location')
        fieldPlaceholder = this.$pgettext('Head/Fetch/Field.Placeholder', 'https://website.example.com/rss.xml')
      } else if (this.type === 'artists') {
        title = this.$pgettext('Head/Fetch/Title', 'Subscribe to a podcast hosted on the Fediverse')
        fieldLabel = this.$pgettext('*/*/*', 'Fediverse object')
        fieldPlaceholder = this.$pgettext('Head/Fetch/Field.Placeholder', '@username@example.com')
      }
      return {
        title,
        fieldLabel,
        fieldPlaceholder
      }
    },
    objInfo () {
      if (this.fetch && this.fetch.status === 'finished') {
        return this.fetch.object
      }
      return null
    },
    redirectRoute () {
      if (!this.objInfo) {
        return
      }
      switch (this.objInfo.type) {
        case 'account': {
          const [username, domain] = this.objInfo.full_username.split('@')
          return { name: 'profile.full', params: { username, domain } }
        }
        case 'library':
          return { name: 'library.detail', params: { id: this.objInfo.uuid } }
        case 'artist':
          return { name: 'library.artists.detail', params: { id: this.objInfo.id } }
        case 'album':
          return { name: 'library.albums.detail', params: { id: this.objInfo.id } }
        case 'track':
          return { name: 'library.tracks.detail', params: { id: this.objInfo.id } }
        case 'upload':
          return { name: 'library.uploads.detail', params: { id: this.objInfo.uuid } }
        case 'channel':
          return { name: 'channels.detail', params: { id: this.objInfo.uuid } }

        default:
          break
      }
      return null
    }
  },

  watch: {
    initialId (v) {
      this.id = v
      this.createFetch()
    },
    redirectRoute (v) {
      if (v && this.redirect) {
        this.$router.push(v)
      }
    }
  },
  created () {
    if (this.id) {
      if (this.type === 'rss') {
        this.rssSubscribe()
      } else if (this.type === 'artists') {
        this.createFetch()
      }
    }
  },

  methods: {
    changeType (newType) {
      this.type = newType
    },
    submit () {
      if (this.type === 'rss') {
        return this.rssSubscribe()
      } else {
        return this.createFetch()
      }
    },
    createFetch () {
      if (!this.id) {
        return
      }
      if (this.standalone) {
        this.$router.replace({ name: 'search', query: { id: this.id } })
      }
      this.fetch = null
      const self = this
      self.errors = []
      self.isLoading = true
      const payload = {
        object: this.id
      }

      axios.post('federation/fetches/', payload).then((response) => {
        self.isLoading = false
        self.fetch = response.data
        if (self.fetch.status === 'errored' || self.fetch.status === 'skipped') {
          self.errors.push(
            self.$pgettext('Content/*/Error message.Title', 'This object cannot be retrieved')
          )
        }
      }, error => {
        self.isLoading = false
        self.errors = error.backendErrors
      })
    },
    rssSubscribe () {
      if (!this.id) {
        return
      }
      if (this.standalone) {
        this.$router.replace({ name: 'search', query: { id: this.id, type: 'rss' } })
      }
      this.fetch = null
      const self = this
      self.errors = []
      self.isLoading = true
      const payload = {
        url: this.id
      }

      axios.post('channels/rss-subscribe/', payload).then((response) => {
        self.isLoading = false
        self.$store.commit('channels/subscriptions', { uuid: response.data.channel.uuid, value: true })
        self.$emit('subscribed', response.data)
        if (self.redirect) {
          self.$router.push({ name: 'channels.detail', params: { id: response.data.channel.uuid } })
        }
      }, error => {
        self.isLoading = false
        self.errors = error.backendErrors
      })
    }
  }
}
</script>
