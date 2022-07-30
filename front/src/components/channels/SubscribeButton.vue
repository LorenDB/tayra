<script setup lang="ts">
import type { Channel } from '~/types'

import { useGettext } from 'vue3-gettext'
import { useStore } from '~/store'
import { computed } from 'vue'

import LoginModal from '~/components/common/LoginModal.vue'

interface Emits {
  (e: 'unsubscribed'): void
  (e: 'subscribed'): void
}

interface Props {
  channel: Channel
}

const emit = defineEmits<Emits>()
const props = defineProps<Props>()

const { $pgettext } = useGettext()
const store = useStore()

const isSubscribed = computed(() => store.getters['channels/isSubscribed'](props.channel.uuid))
const title = computed(() => isSubscribed.value
  ? $pgettext('Content/Channel/Button/Verb', 'Subscribe')
  : $pgettext('Content/Channel/Button/Verb', 'Unsubscribe')
)

const message = computed(() => ({
  authMessage: $pgettext('Popup/Message/Paragraph', 'You need to be logged in to subscribe to this channel')
}))

const toggle = async () => {
  await store.dispatch('channels/toggle', props.channel.uuid)
  emit(isSubscribed.value ? 'unsubscribed' : 'subscribed')
}
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
    @click="$refs.loginModal.show = true"
  >
    <i class="heart icon" />
    {{ title }}
    <login-modal
      ref="loginModal"
      class="small"
      :next-route="$route.fullPath"
      :message="message.authMessage"
      :cover="channel.artist.cover!"
      @created="$refs.loginModal.show = false;"
    />
  </button>
</template>
