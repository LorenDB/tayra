<script setup lang="ts">
import type { Playlist, PrivacyLevel, BackendError } from '~/types'

import { useVModels, useCurrentElement } from '@vueuse/core'
import { ref, computed, onMounted, nextTick } from 'vue'
import { useI18n } from 'vue-i18n'
import { useStore } from '~/store'

import axios from 'axios'
import $ from 'jquery'

import useSharedLabels from '~/composables/locale/useSharedLabels'
import useLogger from '~/composables/useLogger'

interface Events {
  (e: 'update:playlist', value: Playlist): void
}

interface Props {
  title?: boolean
  create?: boolean
  playlist?: Playlist | null
}

const emit = defineEmits<Events>()
const props = withDefaults(defineProps<Props>(), {
  title: true,
  create: false,
  playlist: null
})

const { playlist } = useVModels(props, emit)

const logger = useLogger()

const errors = ref([] as string[])
const success = ref(false)

const store = useStore()
const name = ref(playlist.value?.name ?? '')
const privacyLevel = ref(playlist.value?.privacy_level ?? store.state.auth.profile?.privacy_level ?? 'me')

const { t } = useI18n()
const labels = computed(() => ({
  placeholder: t('components.playlists.Form.placeholder.name')
}))

const sharedLabels = useSharedLabels()
const privacyLevelChoices = computed(() => [
  {
    value: 'me',
    label: sharedLabels.fields.privacy_level.choices.me
  },
  {
    value: 'instance',
    label: sharedLabels.fields.privacy_level.choices.instance
  },
  {
    value: 'everyone',
    label: sharedLabels.fields.privacy_level.choices.everyone
  }
] as { value: PrivacyLevel, label: string }[])

const el = useCurrentElement()
onMounted(async () => {
  await nextTick()
  $(el.value).find('.dropdown').dropdown()
})

const isLoading = ref(false)
const submit = async () => {
  isLoading.value = true
  success.value = false
  errors.value = []

  try {
    const url = props.create ? 'playlists/' : `playlists/${playlist.value?.id}/`
    const method = props.create ? 'post' : 'patch'

    const data = {
      name: name.value,
      privacy_level: privacyLevel.value
    }

    const response = await axios.request({ method, url, data })
    success.value = true

    if (props.create) {
      name.value = ''
    } else {
      playlist.value = response.data
    }

    store.dispatch('playlists/fetchOwn')
  } catch (error) {
    logger.error('Error while creating playlist')
    errors.value = (error as BackendError).backendErrors
  }

  isLoading.value = false
}

</script>

<template>
  <form
    class="ui form"
    @submit.prevent="submit()"
  >
    <h4
      v-if="title"
      class="ui header"
    >
      {{ $t('components.playlists.Form.header.createPlaylist') }}
    </h4>
    <div
      v-if="success"
      class="ui positive message"
    >
      <h4 class="header">
        <template v-if="playlist">
          {{ $t('components.playlists.Form.header.updateSuccess') }}
        </template>
        <template v-else>
          {{ $t('components.playlists.Form.header.createSuccess') }}
        </template>
      </h4>
    </div>
    <div
      v-if="errors.length > 0"
      role="alert"
      class="ui negative message"
    >
      <h4 class="header">
        {{ $t('components.playlists.Form.header.createFailure') }}
      </h4>
      <ul class="list">
        <li
          v-for="(error, key) in errors"
          :key="key"
        >
          {{ error }}
        </li>
      </ul>
    </div>
    <div class="three fields">
      <div class="field">
        <label for="playlist-name">{{ $t('components.playlists.Form.label.name') }}</label>
        <input
          id="playlist-name"
          v-model="name"
          name="name"
          required
          type="text"
          :placeholder="labels.placeholder"
        >
      </div>
      <div class="field">
        <label for="playlist-visibility">{{ $t('components.playlists.Form.label.visibility') }}</label>
        <select
          id="playlist-visibility"
          v-model="privacyLevel"
          class="ui dropdown"
        >
          <option
            v-for="(c, key) in privacyLevelChoices"
            :key="key"
            :value="c.value"
          >
            {{ c.label }}
          </option>
        </select>
      </div>
      <div class="field">
        <span id="updatePlaylistLabel" />
        <button
          :class="['ui', 'fluid', {'loading': isLoading}, 'button']"
          type="submit"
        >
          <template v-if="playlist">
            {{ $t('components.playlists.Form.button.update') }}
          </template>
          <template v-else>
            {{ $t('components.playlists.Form.button.create') }}
          </template>
        </button>
      </div>
    </div>
  </form>
</template>
