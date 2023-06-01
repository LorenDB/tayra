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
      content: t('components.SetInstanceModal.message.newUrl', { url: instanceUrl }),
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
      {{ $t('components.SetInstanceModal.header.chooseInstance') }}
    </h3>
    <div class="scrolling content">
      <div
        v-if="isError"
        role="alert"
        class="ui negative message"
      >
        <h4 class="header">
          {{ $t('components.SetInstanceModal.header.failure') }}
        </h4>
        <ul class="list">
          <li>
            {{ $t('components.SetInstanceModal.help.serverDown') }}
          </li>
          <li>
            {{ $t('components.SetInstanceModal.help.notFunkwhaleServer') }}
          </li>
        </ul>
      </div>
      <form
        class="ui form"
        @submit.prevent="checkAndSwitch(instanceUrl)"
      >
        <p
          v-if="$store.state.instance.instanceUrl"
          class="description"
        >
          <i18n-t keypath="components.SetInstanceModal.message.currentConnection">
            <a
              :href="$store.state.instance.instanceUrl"
              target="_blank"
            >
              {{ $store.getters['instance/domain'] }}
              <i class="external icon" />
            </a>
          </i18n-t>
          {{ $t('', {url: $store.state.instance.instanceUrl, hostname: $store.getters['instance/domain']}) }}
        </p>
        <p v-else>
          {{ $t('components.SetInstanceModal.help.selectPod') }}
        </p>
        <div class="field">
          <label for="instance-picker">{{ $t('components.SetInstanceModal.label.url') }}</label>
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
              {{ $t('components.SetInstanceModal.button.submit') }}
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
            {{ $t('components.SetInstanceModal.header.suggestions') }}
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
        {{ $t('components.SetInstanceModal.button.cancel') }}
      </button>
    </div>
  </semantic-modal>
</template>
