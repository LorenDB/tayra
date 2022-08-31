<script setup lang="ts">
import type { Channel } from '~/types'

import { useGettext } from 'vue3-gettext'
import { computed, ref } from 'vue'
import { useStore } from '~/store'

import LoginModal from '~/components/common/LoginModal.vue'

interface Events {
  (e: 'unsubscribed'): void
  (e: 'subscribed'): void
}

interface Props {
  channel: Channel
}

const emit = defineEmits<Events>()
const props = defineProps<Props>()

const { $pgettext } = useGettext()
const store = useStore()

const isSubscribed = computed(() => store.getters['channels/isSubscribed'](props.channel.uuid))
const title = computed(() => isSubscribed.value
  ? $pgettext('Content/Channel/Button/Verb', 'Unsubscribe')
  : $pgettext('Content/Channel/Button/Verb', 'Subscribe')
)

const message = computed(() => ({
  authMessage: $pgettext('Popup/Message/Paragraph', 'You need to be logged in to subscribe to this channel')
}))

const toggle = async () => {
  await store.dispatch('channels/toggle', props.channel.uuid)

  if (isSubscribed.value) emit('unsubscribed')
  else emit('subscribed')
}

const loginModal = ref()
</script>

<template>
  <button
    v-if="$store.state.auth.authenticated"
    :class="['ui', 'pink', {'inverted': isSubscribed}, {'favorited': isSubscribed}, 'icon', 'labeled', 'button']"
    @click.stop="toggle"
  >
    <i class="heart icon" />
    {{ title }}
  </button>
  <button
    v-else
    :class="['ui', 'pink', 'icon', 'labeled', 'button']"
    @click="loginModal.show = true"
  >
    <i class="heart icon" />
    {{ title }}
    <login-modal
      ref="loginModal"
      class="small"
      :next-route="$route.fullPath"
      :message="message.authMessage"
      :cover="channel.artist?.cover!"
      @created="loginModal.show = false"
    />
  </button>
</template>
