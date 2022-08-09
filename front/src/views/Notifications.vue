<script setup lang="ts">
import type { Notification } from '~/types'

import moment from 'moment'
import axios from 'axios'

import { ref, reactive, computed, watch, markRaw } from 'vue'
import { useGettext } from 'vue3-gettext'
import { useStore } from '~/store'

import NotificationRow from '~/components/notifications/NotificationRow.vue'

import useWebSocketHandler from '~/composables/useWebSocketHandler'
import useErrorHandler from '~/composables/useErrorHandler'
import useMarkdown from '~/composables/useMarkdown'

const store = useStore()
const supportMessage = useMarkdown(() => store.state.instance.settings.instance.support_message.value)
const { $pgettext } = useGettext()

const additionalNotifications = computed(() => store.getters['ui/additionalNotifications'])
const showInstanceSupportMessage = computed(() => store.getters['ui/showInstanceSupportMessage'])
const showFunkwhaleSupportMessage = computed(() => store.getters['ui/showFunkwhaleSupportMessage'])

const labels = computed(() => ({
  title: $pgettext('*/Notifications/*', 'Notifications')
}))

const filters = reactive({
  is_read: false
})

const isLoading = ref(false)
const notifications = reactive({ count: 0, results: [] as Notification[] })
const fetchData = async () => {
  isLoading.value = true

  try {
    const response = await axios.get('federation/inbox/', { params: filters })
    notifications.count = response.data.count
    notifications.results = response.data.results.map(markRaw)
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoading.value = false
}

watch(filters, fetchData, { immediate: true })

useWebSocketHandler('inbox.item_added', (event) => {
  notifications.count += 1
  notifications.results.unshift(markRaw((event.item)))
})

const instanceSupportMessageDelay = ref(60)
const funkwhaleSupportMessageDelay = ref(60)

const setDisplayDate = async (field: string, days: number) => {
  try {
    const response = await axios.patch(`users/${store.state.auth.username}/`, {
      [field]: days
        ? moment().add({ days })
        : undefined
    })

    store.commit('auth/profilePartialUpdate', response.data)
  } catch (error) {
    useErrorHandler(error as Error)
  }
}

const markAllAsRead = async () => {
  try {
    await axios.post('federation/inbox/action/', {
      action: 'read',
      objects: 'all',
      filters: {
        is_read: false,
        before: notifications.results[0]?.id
      }
    })

    store.commit('ui/notifications', { type: 'inbox', count: 0 })
    notifications.results = notifications.results.map(notification => ({ ...notification, is_read: true }))
  } catch (error) {
    useErrorHandler(error as Error)
  }
}
</script>

<template>
  <main
    v-title="labels.title"
    class="main pusher page-notifications"
  >
    <section class="ui vertical aligned stripe segment">
      <div class="ui container">
        <div
          v-if="additionalNotifications"
          class="ui container"
        >
          <h1 class="ui header">
            <translate translate-context="Content/Notifications/Title">
              Your messages
            </translate>
          </h1>
          <div class="ui two column stackable grid">
            <div
              v-if="showInstanceSupportMessage"
              class="column"
            >
              <div class="ui attached info message">
                <h4 class="header">
                  <translate translate-context="Content/Notifications/Header">
                    Support this Funkwhale pod
                  </translate>
                </h4>
                <sanitized-html :html="supportMessage" />
              </div>
              <div class="ui bottom attached segment">
                <form
                  class="ui inline form"
                  @submit.prevent="setDisplayDate('instance_support_message_display_date', instanceSupportMessageDelay)"
                >
                  <div class="inline field">
                    <label for="instance-reminder-delay">
                      <translate translate-context="Content/Notifications/Label">Remind me in:</translate>
                    </label>
                    <select
                      id="instance-reminder-delay"
                      v-model="instanceSupportMessageDelay"
                    >
                      <option :value="30">
                        <translate translate-context="*/*/*">
                          30 days
                        </translate>
                      </option>
                      <option :value="60">
                        <translate translate-context="*/*/*">
                          60 days
                        </translate>
                      </option>
                      <option :value="90">
                        <translate translate-context="*/*/*">
                          90 days
                        </translate>
                      </option>
                      <option :value="null">
                        <translate translate-context="*/*/*">
                          Never
                        </translate>
                      </option>
                    </select>
                    <button
                      type="submit"
                      class="ui right floated basic button"
                    >
                      <translate translate-context="Content/Notifications/Button.Label">
                        Got it!
                      </translate>
                    </button>
                  </div>
                </form>
              </div>
            </div>
            <div
              v-if="showFunkwhaleSupportMessage"
              class="column"
            >
              <div class="ui info attached message">
                <h4 class="header">
                  <translate translate-context="Content/Notifications/Header">
                    Do you like Funkwhale?
                  </translate>
                </h4>
                <p>
                  <translate translate-context="Content/Notifications/Paragraph">
                    We noticed you've been here for a while. If Funkwhale is useful to you, we could use your help to make it even better!
                  </translate>
                </p>
                <a
                  href="https://funkwhale.audio/support-us"
                  target="_blank"
                  rel="noopener"
                  class="ui primary inverted button"
                >
                  <translate translate-context="Content/Notifications/Button.Label/Verb">Donate</translate>
                </a>
                <a
                  href="https://contribute.funkwhale.audio"
                  target="_blank"
                  rel="noopener"
                  class="ui secondary inverted button"
                >
                  <translate translate-context="Content/Notifications/Button.Label/Verb">Discover other ways to help</translate>
                </a>
              </div>
              <div class="ui bottom attached segment">
                <form
                  class="ui inline form"
                  @submit.prevent="setDisplayDate('funkwhale_support_message_display_date', funkwhaleSupportMessageDelay)"
                >
                  <div class="inline field">
                    <label for="funkwhale-reminder-delay">
                      <translate translate-context="Content/Notifications/Label">Remind me in:</translate>
                    </label>
                    <select
                      id="funkwhale-reminder-delay"
                      v-model="funkwhaleSupportMessageDelay"
                    >
                      <option :value="30">
                        <translate translate-context="*/*/*">
                          30 days
                        </translate>
                      </option>
                      <option :value="60">
                        <translate translate-context="*/*/*">
                          60 days
                        </translate>
                      </option>
                      <option :value="90">
                        <translate translate-context="*/*/*">
                          90 days
                        </translate>
                      </option>
                      <option :value="null">
                        <translate translate-context="*/*/*">
                          Never
                        </translate>
                      </option>
                    </select>
                    <button
                      type="submit"
                      class="ui right floated basic button"
                    >
                      <translate translate-context="Content/Notifications/Button.Label">
                        Got it!
                      </translate>
                    </button>
                  </div>
                </form>
              </div>
            </div>
          </div>
        </div>
        <h1 class="ui header">
          <translate translate-context="Content/Notifications/Title">
            Your notifications
          </translate>
        </h1>
        <div class="ui toggle checkbox">
          <input
            id="show-read-notifications"
            v-model="filters.is_read"
            type="checkbox"
          >
          <label for="show-read-notifications"><translate translate-context="Content/Notifications/Form.Label/Verb">Show read notifications</translate></label>
        </div>
        <button
          v-if="filters.is_read === false && notifications.count > 0"
          class="ui basic labeled icon right floated button"
          @click.prevent="markAllAsRead"
        >
          <i class="ui check icon" />
          <translate translate-context="Content/Notifications/Button.Label/Verb">
            Mark all as read
          </translate>
        </button>
        <div class="ui hidden divider" />

        <div
          v-if="isLoading"
          :class="['ui', {'active': isLoading}, 'inverted', 'dimmer']"
        >
          <div class="ui text loader">
            <translate translate-context="Content/Notifications/Paragraph">
              Loading notifications…
            </translate>
          </div>
        </div>

        <table
          v-else-if="notifications.count > 0"
          class="ui table"
        >
          <tbody>
            <notification-row
              v-for="item in notifications.results"
              :key="item.id"
              :initial-item="item"
            />
          </tbody>
        </table>
        <p v-else-if="additionalNotifications === 0">
          <translate translate-context="Content/Notifications/Paragraph">
            No notification to show.
          </translate>
        </p>
      </div>
    </section>
  </main>
</template>
