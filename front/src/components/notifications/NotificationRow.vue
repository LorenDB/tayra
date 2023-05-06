<script setup lang="ts">
import type { Notification, LibraryFollow } from '~/types'

import { computed, ref, watchEffect, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useStore } from '~/store'

import axios from 'axios'

interface Props {
  initialItem: Notification
}

const props = defineProps<Props>()

const { t } = useI18n()
const store = useStore()

const labels = computed(() => ({
  markRead: t('components.notifications.NotificationRow.button.markRead'),
  markUnread: t('components.notifications.NotificationRow.button.markUnread')
}))

const item = ref(props.initialItem)
watchEffect(() => (item.value = props.initialItem))

const username = computed(() => props.initialItem.activity.actor.preferred_username)
const notificationData = computed(() => {
  const activity = props.initialItem.activity

  if (activity.type === 'Follow') {
    if (activity.object && activity.object.type === 'music.Library') {
      const detailUrl = { name: 'library.detail.edit', params: { id: activity.object.uuid } }

      if (activity.related_object?.approved === null) {
        return {
          detailUrl,
          message: t('components.notifications.NotificationRow.message.libraryPendingFollow', { username: username.value, library: activity.object.name }),
          acceptFollow: {
            buttonClass: 'success',
            icon: 'check',
            label: t('components.notifications.NotificationRow.button.approve'),
            handler: () => approveLibraryFollow(activity.related_object)
          },
          rejectFollow: {
            buttonClass: 'danger',
            icon: 'x',
            label: t('components.notifications.NotificationRow.button.reject'),
            handler: () => rejectLibraryFollow(activity.related_object)
          }
        }
      } else if (activity.related_object?.approved) {
        return {
          detailUrl,
          message: t('components.notifications.NotificationRow.message.libraryFollow', { username: username.value, library: activity.object.name })
        }
      }

      return {
        detailUrl,
        message: t('components.notifications.NotificationRow.message.libraryReject', { username: username.value, library: activity.object.name })
      }
    }
  }

  if (activity.type === 'Accept') {
    if (activity.object?.type === 'federation.LibraryFollow') {
      return {
        detailUrl: { name: 'content.remote.index' },
        message: t('components.notifications.NotificationRow.message.libraryAcceptFollow', { username: username.value, library: activity.related_object.name })
      }
    }
  }

  return {}
})

const read = ref(false)
watch(read, async () => {
  await axios.patch(`federation/inbox/${item.value.id}/`, { is_read: read.value })

  item.value.is_read = read.value
  store.commit('ui/incrementNotifications', { type: 'inbox', count: read.value ? -1 : 1 })
})

const handleAction = (handler?: () => void) => {
  // call handler then mark notification as read
  handler?.()
  read.value = true
}

const approveLibraryFollow = async (follow: LibraryFollow) => {
  await axios.post(`federation/follows/library/${follow.uuid}/accept/`)
  follow.approved = true
  item.value.is_read = true
}

const rejectLibraryFollow = async (follow: LibraryFollow) => {
  await axios.post(`federation/follows/library/${follow.uuid}/reject/`)
  follow.approved = false
  item.value.is_read = true
}
</script>

<template>
  <tr :class="[{'disabled-row': item.is_read}]">
    <td>
      <actor-link
        class="user"
        :actor="item.activity.actor"
      />
    </td>
    <td>
      <router-link
        v-if="notificationData.detailUrl"
        v-slot="{ navigate }"
        custom
        :to="notificationData.detailUrl"
      >
        <sanitized-html
          tag="span"
          class="link"
          :html="notificationData.message"
          @click="navigate()"
          @keypress.enter="navigate()"
        />
      </router-link>
      <sanitized-html
        v-else
        :html="notificationData.message"
      />
      <template v-if="notificationData.acceptFollow">
&nbsp;
        <button
          :class="['ui', 'basic', 'tiny', notificationData.acceptFollow.buttonClass || '', 'button']"
          @click="handleAction(notificationData.acceptFollow?.handler)"
        >
          <i
            v-if="notificationData.acceptFollow.icon"
            :class="[notificationData.acceptFollow.icon, 'icon']"
          />
          {{ notificationData.acceptFollow.label }}
        </button>
        <button
          :class="['ui', 'basic', 'tiny', notificationData.rejectFollow.buttonClass || '', 'button']"
          @click="handleAction(notificationData.rejectFollow?.handler)"
        >
          <i
            v-if="notificationData.rejectFollow.icon"
            :class="[notificationData.rejectFollow.icon, 'icon']"
          />
          {{ notificationData.rejectFollow.label }}
        </button>
      </template>
    </td>
    <td><human-date :date="item.activity.creation_date" /></td>
    <td class="read collapsing">
      <a
        v-if="item.is_read"
        href=""
        :aria-label="labels.markUnread"
        class="discrete link"
        :title="labels.markUnread"
        @click.prevent="read = false"
      >
        <i class="redo icon" />
      </a>
      <a
        v-else
        href=""
        :aria-label="labels.markRead"
        class="discrete link"
        :title="labels.markRead"
        @click.prevent="read = true"
      >
        <i class="check icon" />
      </a>
    </td>
  </tr>
</template>
