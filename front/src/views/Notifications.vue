<script setup lang="ts">
import type { Notification } from '~/types'

import moment from 'moment'
import axios from 'axios'

import { ref, reactive, computed, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useStore } from '~/store'

import NotificationRow from '~/components/notifications/NotificationRow.vue'

import useWebSocketHandler from '~/composables/useWebSocketHandler'
import useErrorHandler from '~/composables/useErrorHandler'
import useMarkdown from '~/composables/useMarkdown'

const store = useStore()
const supportMessage = useMarkdown(() => store.state.instance.settings.instance.support_message.value)
const { t } = useI18n()

const additionalNotifications = computed(() => store.getters['ui/additionalNotifications'])
const showInstanceSupportMessage = computed(() => store.getters['ui/showInstanceSupportMessage'])
const showFunkwhaleSupportMessage = computed(() => store.getters['ui/showFunkwhaleSupportMessage'])

const labels = computed(() => ({
  title: t('views.Notifications.title')
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
    notifications.results = response.data.results
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoading.value = false
}

watch(filters, fetchData, { immediate: true })

useWebSocketHandler('inbox.item_added', (event) => {
  notifications.count += 1
  notifications.results.unshift(event.item)
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
            {{ $t('views.Notifications.header.messages') }}
          </h1>
          <div class="ui two column stackable grid">
            <div
              v-if="showInstanceSupportMessage"
              class="column"
            >
              <div class="ui attached info message">
                <h4 class="header">
                  {{ $t('views.Notifications.header.instanceSupport') }}
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
                      {{ $t('views.Notifications.label.reminder') }}
                    </label>
                    <select
                      id="instance-reminder-delay"
                      v-model="instanceSupportMessageDelay"
                    >
                      <option :value="30">
                        {{ $t('views.Notifications.option.delay.30') }}
                      </option>
                      <option :value="60">
                        {{ $t('views.Notifications.option.delay.60') }}
                      </option>
                      <option :value="90">
                        {{ $t('views.Notifications.option.delay.90') }}
                      </option>
                      <option :value="null">
                        {{ $t('views.Notifications.option.delay.never') }}
                      </option>
                    </select>
                    <button
                      type="submit"
                      class="ui right floated basic button"
                    >
                      {{ $t('views.Notifications.button.submit') }}
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
                  {{ $t('views.Notifications.header.funkwhaleSupport') }}
                </h4>
                <p>
                  {{ $t('views.Notifications.message.funkwhaleSupport') }}
                </p>
                <a
                  href="https://funkwhale.audio/support-us"
                  target="_blank"
                  rel="noopener"
                  class="ui primary inverted button"
                >
                  {{ $t('views.Notifications.link.donate') }}
                </a>
                <a
                  href="https://contribute.funkwhale.audio"
                  target="_blank"
                  rel="noopener"
                  class="ui secondary inverted button"
                >
                  {{ $t('views.Notifications.link.help') }}
                </a>
              </div>
              <div class="ui bottom attached segment">
                <form
                  class="ui inline form"
                  @submit.prevent="setDisplayDate('funkwhale_support_message_display_date', funkwhaleSupportMessageDelay)"
                >
                  <div class="inline field">
                    <label for="funkwhale-reminder-delay">
                      {{ $t('views.Notifications.label.reminder') }}
                    </label>
                    <select
                      id="funkwhale-reminder-delay"
                      v-model="funkwhaleSupportMessageDelay"
                    >
                      <option :value="30">
                        {{ $t('views.Notifications.option.delay.30') }}
                      </option>
                      <option :value="60">
                        {{ $t('views.Notifications.option.delay.60') }}
                      </option>
                      <option :value="90">
                        {{ $t('views.Notifications.option.delay.90') }}
                      </option>
                      <option :value="null">
                        {{ $t('views.Notifications.option.delay.never') }}
                      </option>
                    </select>
                    <button
                      type="submit"
                      class="ui right floated basic button"
                    >
                      {{ $t('views.Notifications.button.submit') }}
                    </button>
                  </div>
                </form>
              </div>
            </div>
          </div>
        </div>
        <h1 class="ui header">
          {{ $t('views.Notifications.header.notifications') }}
        </h1>
        <div class="ui toggle checkbox">
          <input
            id="show-read-notifications"
            v-model="filters.is_read"
            type="checkbox"
          >
          <label for="show-read-notifications">{{ $t('views.Notifications.label.showRead') }}</label>
        </div>
        <button
          v-if="filters.is_read === false && notifications.count > 0"
          class="ui basic labeled icon right floated button"
          @click.prevent="markAllAsRead"
        >
          <i class="ui check icon" />
          {{ $t('views.Notifications.button.read') }}
        </button>
        <div class="ui hidden divider" />

        <div
          v-if="isLoading"
          :class="['ui', {'active': isLoading}, 'inverted', 'dimmer']"
        >
          <div class="ui text loader">
            {{ $t('views.Notifications.loading.notifications') }}
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
          {{ $t('views.Notifications.empty.notifications') }}
        </p>
      </div>
    </section>
  </main>
</template>
