<script setup lang="ts">
import type { Playlist, PrivacyLevel, BackendError } from '~/types'

import $ from 'jquery'
import axios from 'axios'
import { useVModels, useCurrentElement } from '@vueuse/core'
import { useGettext } from 'vue3-gettext'
import { useStore } from '~/store'
import { ref, computed, onMounted, nextTick } from 'vue'
import useLogger from '~/composables/useLogger'
import useSharedLabels from '~/composables/locale/useSharedLabels'

interface Props {
  title?: boolean
  create?: boolean
  playlist?: Playlist | null
}

const props = withDefaults(defineProps<Props>(), {
  title: true,
  create: false,
  playlist: null
})

const emit = defineEmits(['update:playlist'])
const { playlist } = useVModels(props, emit)

const logger = useLogger()

const errors = ref([] as string[])
const success = ref(false)

const store = useStore()
const name = ref(playlist.value?.name ?? '')
const privacyLevel = ref(playlist.value?.privacy_level ?? store.state.auth.profile?.privacy_level ?? 'me')

const { $pgettext } = useGettext()
const labels = computed(() => ({
  placeholder: $pgettext('Content/Playlist/Input.Placeholder', 'My awesome playlist')
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
    const url = props.create ? 'playlists/' : `playlists/${playlist.value!.id}/`
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
      <translate translate-context="Popup/Playlist/Title/Verb">
        Create a new playlist
      </translate>
    </h4>
    <div
      v-if="success"
      class="ui positive message"
    >
      <h4 class="header">
        <template v-if="playlist">
          <translate translate-context="Content/Playlist/Message">
            Playlist updated
          </translate>
        </template>
        <template v-else>
          <translate translate-context="Content/Playlist/Message">
            Playlist created
          </translate>
        </template>
      </h4>
    </div>
    <div
      v-if="errors.length > 0"
      role="alert"
      class="ui negative message"
    >
      <h4 class="header">
        <translate translate-context="Content/Playlist/Error message.Title">
          The playlist could not be created
        </translate>
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
        <label for="playlist-name"><translate translate-context="Content/Playlist/Input.Label">Playlist name</translate></label>
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
        <label for="playlist-visibility"><translate translate-context="Content/Playlist/Dropdown.Label">Playlist visibility</translate></label>
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
            <translate translate-context="Content/Playlist/Button.Label/Verb">
              Update playlist
            </translate>
          </template>
          <template v-else>
            <translate translate-context="Content/Playlist/Button.Label/Verb">
              Create playlist
            </translate>
          </template>
        </button>
      </div>
    </div>
  </form>
</template>
