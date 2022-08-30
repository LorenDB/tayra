<script setup lang="ts">
import type { BackendError } from '~/types'

import axios from 'axios'
import { useStore } from '~/store'
import { ref, computed, watch, watchEffect } from 'vue'
import { useRouter } from 'vue-router'
import { useGettext } from 'vue3-gettext'

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

const { $pgettext } = useGettext()
const labels = computed(() => ({
  title: type.value === 'rss'
    ? $pgettext('Head/Fetch/Title', 'Subscribe to a podcast RSS feed')
    : $pgettext('Head/Fetch/Title', 'Subscribe to a podcast hosted on the Fediverse'),
  fieldLabel: type.value === 'rss'
    ? $pgettext('*/*/*', 'RSS feed location')
    : $pgettext('*/*/*', 'Fediverse object'),
  fieldPlaceholder: type.value === 'rss'
    ? $pgettext('Head/Fetch/Field.Placeholder', 'https://website.example.com/rss.xml')
    : $pgettext('Head/Fetch/Field.Placeholder', '@username@example.com')
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
  if (!id.value) return
  if (props.standalone) {
    // TODO (wvffle): Check if this needs to be handled
    return router.replace({ name: 'search', query: { id: id.value } })
  }

  obj.value = undefined
  errors.value = []
  isLoading.value = true

  try {
    const response = await axios.post('federation/fetches/', { object: id.value })
    obj.value = response.data

    if (response.data.status === 'errored' || response.data.status === 'skipped') {
      errors.value.push($pgettext('Content/*/Error message.Title', 'This object cannot be retrieved'))
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
    // TODO (wvffle): Check if this needs to be handled
    return router.replace({ name: 'search', query: { id: id.value, type: 'rss' } })
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

watchEffect(() => {
  id.value = props.initialId
  // createFetch()

  if (id.value) {
    submit()
  }
})
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
      <translate translate-context="Content/Search/Input.Label/Noun">
        RSS
      </translate>
    </button>
    <div class="or" />
    <button
      class="ui right floated right labeled icon button"
      @click.prevent="type = 'artists'"
    >
      <i class="globe icon" />
      <translate translate-context="Content/Search/Input.Label/Noun">
        Fediverse
      </translate>
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
          <translate translate-context="Content/*/Error message.Title">
            Error while fetching object
          </translate>
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
          <translate translate-context="Content/Fetch/Paragraph">
            Use this form to subscribe to an RSS feed from its URL.
          </translate>
        </p>
        <p v-else-if="type === 'artists'">
          <translate translate-context="Content/Fetch/Paragraph">
            Use this form to subscribe to a channel hosted somewhere else on the Fediverse.
          </translate>
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
        <translate translate-context="Content/Search/Input.Label/Noun">
          Search
        </translate>
      </button>
    </form>
    <div
      v-if="!isLoading && obj?.status === 'finished' && !redirectRoute"
      role="alert"
      class="ui warning message"
    >
      <p>
        <translate translate-context="Content/*/Error message.Title">
          This kind of object isn't supported yet
        </translate>
      </p>
    </div>
  </div>
</template>
