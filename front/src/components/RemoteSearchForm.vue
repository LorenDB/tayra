<script setup lang="ts">
import type { BackendError } from '~/types'

import { ref, computed, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import { useStore } from '~/store'

import axios from 'axios'

import updateQueryString from '~/composables/updateQueryString'
import useLogger from '~/composables/useLogger'

type Type = 'rss' | 'artists' | 'both'

interface Events {
  (e: 'subscribed', rss: object): void
}

interface Props {
  initialId?: string
  initialType?: Type
  redirect?: boolean
  showSubmit?: boolean
  standalone?: boolean
}

const emit = defineEmits<Events>()
const props = withDefaults(defineProps<Props>(), {
  initialId: '',
  initialType: 'artists',
  redirect: true,
  showSubmit: true,
  standalone: true
})

const type = ref(props.initialType)
const id = ref(props.initialId)
const errors = ref([] as string[])

const logger = useLogger()
const { t } = useI18n()
const labels = computed(() => ({
  title: type.value === 'rss'
    ? t('components.RemoteSearchForm.label.rss.title')
    : t('components.RemoteSearchForm.label.fediverse.title'),
  fieldLabel: type.value === 'rss'
    ? t('components.RemoteSearchForm.label.rss.fieldLabel')
    : t('components.RemoteSearchForm.label.fediverse.fieldLabel'),
  fieldPlaceholder: type.value === 'rss'
    ? t('components.RemoteSearchForm.label.rss.fieldPlaceholder')
    : t('components.RemoteSearchForm.label.fediverse.fieldPlaceholder')
}))

const obj = ref()
const objInfo = computed(() => obj.value?.status === 'finished' ? obj.value.object : null)
const redirectRoute = computed(() => {
  if (!objInfo.value) {
    return null
  }

  switch (objInfo.value.type) {
    case 'account': {
      const [username, domain] = objInfo.value.full_username.split('@')
      return { name: 'profile.full', params: { username, domain } }
    }

    case 'library':
      return { name: 'library.detail', params: { id: objInfo.value.uuid } }

    case 'artist':
      return { name: 'library.artists.detail', params: { id: objInfo.value.id } }

    case 'album':
      return { name: 'library.albums.detail', params: { id: objInfo.value.id } }

    case 'track':
      return { name: 'library.tracks.detail', params: { id: objInfo.value.id } }

    case 'upload':
      return { name: 'library.uploads.detail', params: { id: objInfo.value.uuid } }

    case 'channel':
      return { name: 'channels.detail', params: { id: objInfo.value.uuid } }
  }

  return null
})

const router = useRouter()
watch(redirectRoute, () => {
  if (props.redirect && redirectRoute.value) {
    return router.push(redirectRoute.value)
  }
})

const submit = () => {
  if (type.value === 'rss') {
    return rssSubscribe()
  }

  return createFetch()
}

const isLoading = ref(false)
const createFetch = async () => {
  logger.debug(id.value, props.standalone)
  if (!id.value) return
  if (props.standalone) {
    history.replaceState(history.state, '', updateQueryString(location.href, 'id', id.value))
  }

  obj.value = undefined
  errors.value = []
  isLoading.value = true

  try {
    const response = await axios.post('federation/fetches/', { object: id.value })
    obj.value = response.data

    if (response.data.status === 'errored' || response.data.status === 'skipped') {
      errors.value.push(t('components.RemoteSearchForm.error.fetchFailed'))
    }
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }

  isLoading.value = false
}

const store = useStore()

const rssSubscribe = async () => {
  if (!id.value) return
  if (props.standalone) {
    history.replaceState(history.state, '', updateQueryString(location.href, 'id', id.value))
  }

  obj.value = undefined
  errors.value = []
  isLoading.value = true

  try {
    const response = await axios.post('channels/rss-subscribe/', { url: id.value })
    store.commit('channels/subscriptions', { uuid: response.data.channel.uuid, value: true })
    emit('subscribed', response.data)

    if (props.redirect) {
      return router.push({ name: 'channels.detail', params: { id: response.data.channel.uuid } })
    }
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }

  isLoading.value = false
}

watch(() => props.initialId, () => {
  id.value = props.initialId

  if (id.value) {
    submit()
  }
}, { immediate: true })
</script>

<template>
  <div
    v-if="type === 'both'"
    class="two ui buttons"
  >
    <button
      class="ui left floated labeled icon button"
      @click.prevent="type = 'rss'"
    >
      <i class="feed icon" />
      {{ $t('components.RemoteSearchForm.button.rss') }}
    </button>
    <div class="or" />
    <button
      class="ui right floated right labeled icon button"
      @click.prevent="type = 'artists'"
    >
      <i class="globe icon" />
      {{ $t('components.RemoteSearchForm.button.fediverse') }}
    </button>
  </div>
  <div v-else>
    <form
      id="remote-search"
      :class="['ui', {loading: isLoading}, 'form']"
      @submit.stop.prevent="submit"
    >
      <div
        v-if="errors.length > 0"
        role="alert"
        class="ui negative message"
      >
        <h3 class="header">
          {{ $t('components.RemoteSearchForm.header.fetchFailed') }}
        </h3>
        <ul class="list">
          <li
            v-for="(error, key) in errors"
            :key="key"
          >
            {{ error }}
          </li>
        </ul>
      </div>
      <div class="ui required field">
        <label for="object-id">
          {{ labels.fieldLabel }}
        </label>
        <p v-if="type === 'rss'">
          {{ $t('components.RemoteSearchForm.description.rss') }}
        </p>
        <p v-else-if="type === 'artists'">
          {{ $t('components.RemoteSearchForm.description.fediverse') }}
        </p>
        <input
          id="object-id"
          v-model="id"
          type="text"
          name="object-id"
          :placeholder="labels.fieldPlaceholder"
          required
        >
      </div>
      <button
        v-if="showSubmit"
        type="submit"
        :class="['ui', 'primary', {loading: isLoading}, 'button']"
        :disabled="isLoading || !id || id.length === 0"
      >
        {{ $t('components.RemoteSearchForm.button.search') }}
      </button>
    </form>
    <div
      v-if="!isLoading && obj?.status === 'finished' && !redirectRoute"
      role="alert"
      class="ui warning message"
    >
      <p>
        {{ $t('components.RemoteSearchForm.warning.unsupported') }}
      </p>
    </div>
  </div>
</template>
