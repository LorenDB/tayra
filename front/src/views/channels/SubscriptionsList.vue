<script setup lang="ts">
import type { Channel } from '~/types'

import { useGettext } from 'vue3-gettext'
import { ref, computed } from 'vue'

import axios from 'axios'

import ChannelsWidget from '~/components/audio/ChannelsWidget.vue'
import RemoteSearchForm from '~/components/RemoteSearchForm.vue'
import SemanticModal from '~/components/semantic/Modal.vue'

import useErrorHandler from '~/composables/useErrorHandler'

interface Props {
  defaultQuery?: string
}

const props = withDefaults(defineProps<Props>(), {
  defaultQuery: ''
})

const query = ref(props.defaultQuery)
const widgetKey = ref(new Date().toLocaleString())

const { $pgettext } = useGettext()
const labels = computed(() => ({
  title: $pgettext('Content/Subscriptions/Header', 'Subscribed Channels'),
  searchPlaceholder: $pgettext('Content/Subscriptions/Form.Placeholder', 'Filter by name…')
}))

const previousPage = ref()
const nextPage = ref()
const channels = ref([] as Channel[])
const count = ref(0)
const isLoading = ref(false)
const fetchData = async () => {
  isLoading.value = true

  try {
    const response = await axios.get('channels/', { params: { subscribed: 'true', q: query.value } })
    previousPage.value = response.data.previous
    nextPage.value = response.data.next
    channels.value.push(...response.data.results)
    count.value = response.data.count
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoading.value = false
}
fetchData()

const reloadWidget = () => (widgetKey.value = new Date().toLocaleString())
const showSubscribeModal = ref(false)
</script>

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
      <semantic-modal
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
      </semantic-modal>

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
