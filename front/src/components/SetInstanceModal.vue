<script setup lang="ts">
import { ref, computed, watch, nextTick } from 'vue'
import { useI18n } from 'vue-i18n'
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

const { t } = useI18n()
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
      content: t('You are now using the Funkwhale instance at %{ url }', { url: instanceUrl }),
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
      Choose your instance
    </h3>
    <div class="scrolling content">
      <div
        v-if="isError"
        role="alert"
        class="ui negative message"
      >
        <h4 class="header">
          It is not possible to connect to the given URL
        </h4>
        <ul class="list">
          <li>
            The server might be down
          </li>
          <li>
            The given address is not a Funkwhale server
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
        >
          You are currently connected to <a
            href="%{ url }"
            target="_blank"
          >%{ hostname }&nbsp;<i class="external icon" /></a>. If you continue, you will be disconnected from your current instance and all your local data will be deleted.
        </p>
        <p v-else>
          To continue, please select the Funkwhale instance you want to connect to. Enter the address directly, or select one of the suggested choices.
        </p>
        <div class="field">
          <label for="instance-picker">Instance URL</label>
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
              Submit
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
            Suggested choices
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
        Cancel
      </button>
    </div>
  </semantic-modal>
</template>
