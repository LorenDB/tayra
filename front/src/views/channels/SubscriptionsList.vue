<template>
  <main
    v-title="labels.title"
    class="main pusher"
  >
    <section class="ui head vertical stripe segment container">
      <h1 class="ui with-actions header">
        {{ labels.title }}
        <div class="actions">
          <a @click.stop.prevent="showSubscribeModal = true">
            <i class="plus icon" />
            <translate translate-context="Content/Profile/Button">Add new</translate>
          </a>
        </div>
      </h1>
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
            initial-type="both"
            :show-submit="false"
            :standalone="false"
            :redirect="true"
            @subscribed="showSubscribeModal = false; reloadWidget()"
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

      <inline-search-bar
        v-model="query"
        :placeholder="labels.searchPlaceholder"
        @search="reloadWidget"
      />
      <channels-widget
        :key="widgetKey"
        :limit="50"
        :show-modification-date="true"
        :filters="{q: query, subscribed: 'true', ordering: '-modification_date'}"
      />
    </section>
  </main>
</template>

<script>
import axios from 'axios'
import Modal from '~/components/semantic/Modal.vue'

import ChannelsWidget from '~/components/audio/ChannelsWidget.vue'
import RemoteSearchForm from '~/components/RemoteSearchForm.vue'

export default {
  components: {
    ChannelsWidget,
    RemoteSearchForm,
    Modal
  },
  props: { defaultQuery: { type: String, required: false, default: '' } },
  data () {
    return {
      query: this.defaultQuery || '',
      channels: [],
      count: 0,
      isLoading: false,
      errors: null,
      previousPage: null,
      nextPage: null,
      widgetKey: String(new Date()),
      showSubscribeModal: false
    }
  },
  computed: {
    labels () {
      return {
        title: this.$pgettext('Content/Subscriptions/Header', 'Subscribed Channels'),
        searchPlaceholder: this.$pgettext('Content/Subscriptions/Form.Placeholder', 'Filter by name…')
      }
    }
  },
  created () {
    this.fetchData()
  },
  methods: {
    fetchData () {
      const self = this
      this.isLoading = true
      axios.get('channels/', { params: { subscribed: 'true', q: this.query } }).then(response => {
        self.previousPage = response.data.previous
        self.nextPage = response.data.next
        self.isLoading = false
        self.channels = [...self.channels, ...response.data.results]
        self.count = response.data.count
      })
    },
    reloadWidget () {
      this.widgetKey = String(new Date())
    }
  }
}
</script>
