<script setup lang="ts">
import { ref, computed, watch, nextTick } from 'vue'
import { useGettext } from 'vue3-gettext'
import { useVModel } from '@vueuse/core'
import { useStore } from '~/store'
import { uniq } from 'lodash-es'

import axios from 'axios'

import SemanticModal from '~/components/semantic/Modal.vue'

interface Events {
  (e: 'update:show', show: boolean): void
}

interface Props {
  show: boolean
}

const emit = defineEmits<Events>()
const props = defineProps<Props>()

const show = useVModel(props, 'show', emit)

const instanceUrl = ref('')

const store = useStore()
const suggestedInstances = computed(() => {
  const serverUrl = store.state.instance.frontSettings.defaultServerUrl

  return uniq([
    store.state.instance.instanceUrl,
    ...store.state.instance.knownInstances,
    serverUrl.endsWith('/') ? serverUrl : serverUrl + '/',
    store.getters['instance/defaultInstance']
  ]).slice(1)
})

watch(() => store.state.instance.instanceUrl, () => store.dispatch('instance/fetchSettings'))

const { $pgettext } = useGettext()
const isError = ref(false)
const isLoading = ref(false)
const checkAndSwitch = async (url: string) => {
  isError.value = false
  isLoading.value = true

  try {
    const instanceUrl = new URL(url.startsWith('https://') || url.startsWith('http://') ? url : `https://${url}`).origin
    await axios.get(instanceUrl + '/api/v1/instance/nodeinfo/2.0/')

    show.value = false
    store.commit('ui/addMessage', {
      content: $pgettext('*/Instance/Message', 'You are now using the Funkwhale instance at %{ url }', { url: instanceUrl }),
      date: new Date()
    })

    await nextTick()
    store.dispatch('instance/setUrl', instanceUrl)
  } catch (error) {
    isError.value = true
  }

  isLoading.value = false
}
</script>

<template>
  <semantic-modal
    v-model:show="show"
    @update:show="isError = false"
  >
    <h3 class="header">
      <translate translate-context="Popup/Instance/Title">
        Choose your instance
      </translate>
    </h3>
    <div class="scrolling content">
      <div
        v-if="isError"
        role="alert"
        class="ui negative message"
      >
        <h4 class="header">
          <translate translate-context="Popup/Instance/Error message.Title">
            It is not possible to connect to the given URL
          </translate>
        </h4>
        <ul class="list">
          <li>
            <translate translate-context="Popup/Instance/Error message.List item">
              The server might be down
            </translate>
          </li>
          <li>
            <translate translate-context="Popup/Instance/Error message.List item">
              The given address is not a Funkwhale server
            </translate>
          </li>
        </ul>
      </div>
      <form
        class="ui form"
        @submit.prevent="checkAndSwitch(instanceUrl)"
      >
        <p
          v-if="$store.state.instance.instanceUrl"
          v-translate="{url: $store.state.instance.instanceUrl, hostname: $store.getters['instance/domain'] }"
          class="description"
          translate-context="Popup/Login/Paragraph"
        >
          You are currently connected to <a
            href="%{ url }"
            target="_blank"
          >%{ hostname }&nbsp;<i class="external icon" /></a>. If you continue, you will be disconnected from your current instance and all your local data will be deleted.
        </p>
        <p v-else>
          <translate translate-context="Popup/Instance/Paragraph">
            To continue, please select the Funkwhale instance you want to connect to. Enter the address directly, or select one of the suggested choices.
          </translate>
        </p>
        <div class="field">
          <label for="instance-picker"><translate translate-context="Popup/Instance/Input.Label/Noun">Instance URL</translate></label>
          <div class="ui action input">
            <input
              id="instance-picker"
              v-model="instanceUrl"
              type="text"
              placeholder="https://funkwhale.server"
            >
            <button
              type="submit"
              :class="['ui', 'icon', {loading: isLoading}, 'button']"
            >
              <translate translate-context="*/*/Button.Label/Verb">
                Submit
              </translate>
            </button>
          </div>
        </div>
      </form>
      <div class="ui hidden divider" />
      <form
        class="ui form"
        @submit.prevent=""
      >
        <div class="field">
          <h4>
            <translate translate-context="Popup/Instance/List.Label">
              Suggested choices
            </translate>
          </h4>
          <button
            v-for="(url, key) in suggestedInstances"
            :key="key"
            class="ui basic button"
            @click="checkAndSwitch(url)"
          >
            {{ url }}
          </button>
        </div>
      </form>
    </div>
    <div class="actions">
      <button class="ui basic cancel button">
        <translate translate-context="*/*/Button.Label/Verb">
          Cancel
        </translate>
      </button>
    </div>
  </semantic-modal>
</template>
