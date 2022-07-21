<script setup lang="ts">
import type { Channel, BackendError } from '~/types'

import { slugify } from 'transliteration'
import { reactive, computed, ref, watchEffect, watch } from 'vue'
import { useGettext } from 'vue3-gettext'

import axios from 'axios'
import AttachmentInput from '~/components/common/AttachmentInput.vue'
import TagsSelector from '~/components/library/TagsSelector.vue'

interface Props {
  object?: Channel | null
  step: number
}

const emit = defineEmits(['category', 'submittable', 'loading', 'errored', 'created', 'updated'])
const props = withDefaults(defineProps<Props>(), {
  object: null,
  step: 1
})

const { $pgettext } = useGettext()

const newValues = reactive({
  name: props.object?.artist?.name ?? '',
  username: props.object?.actor.preferred_username ?? '',
  tags: props.object?.artist?.tags ?? [],
  description: props.object?.artist?.description?.text ?? '',
  cover: props.object?.artist?.cover?.uuid ?? null,
  content_category: props.object?.artist?.content_category ?? 'podcast',
  metadata: { ...(props.object?.metadata ?? {}) }
})

const creating = computed(() => props.object === null)
const categoryChoices = computed(() => [
  {
    value: 'podcast',
    label: $pgettext('*/*/*', 'Podcasts'),
    helpText: $pgettext('Content/Channels/Help', 'Host your episodes and keep your community updated.')
  },
  {
    value: 'music',
    label: $pgettext('*/*/*', 'Artist discography'),
    helpText: $pgettext('Content/Channels/Help', 'Publish music you make as a nice discography of albums and singles.')
  }
])

interface ITunesCategory {
  value: string
  label: string
  children: []
}

interface MetadataChoices {
  itunes_category?: ITunesCategory[] | null
  language: {
    value: string
    label: string
  }[]
}

const metadataChoices = ref({ itunes_category: null } as MetadataChoices)
const itunesSubcategories = computed(() => {
  for (const element of metadataChoices.value.itunes_category ?? []) {
    if (element.value === newValues.metadata.itunes_category) {
      return element.children ?? []
    }
  }

  return []
})

const labels = computed(() => ({
  namePlaceholder: $pgettext('Content/Channel/Form.Field.Placeholder', 'Awesome channel name'),
  usernamePlaceholder: $pgettext('Content/Channel/Form.Field.Placeholder', 'awesomechannelname')
}))

const submittable = computed(() =>
  newValues.content_category === 'podcast'
    ? newValues.name && newValues.username && newValues.metadata.itunes_category && newValues.metadata.language
    : newValues.name && newValues.username
)

watch(() => newValues.name, (name) => {
  if (creating.value) {
    newValues.username = slugify(name)
  }
})

watch(() => newValues.metadata.itunes_category, () => {
  newValues.metadata.itunes_subcategory = null
})

const isLoading = ref(false)
const errors = ref([] as string[])

watchEffect(() => emit('category', newValues.content_category))
watchEffect(() => emit('loading', isLoading.value))
watchEffect(() => emit('submittable', submittable.value))

// TODO (wvffle): Add loader / Use Suspense
const fetchMetadataChoices = async () => {
  try {
    const response = await axios.get('channels/metadata-choices')
    metadataChoices.value = response.data
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }
}

fetchMetadataChoices()

const submit = async () => {
  isLoading.value = true

  const payload = {
    ...newValues,
    description: newValues.description
      ? {
          content_type: 'text/markdown',
          text: newValues.description
        }
      : null
  }

  try {
    const request = () => creating.value
      ? axios.post('channels/', payload)
      : axios.patch(`channels/${props.object?.uuid}`, payload)

    const response = await request()
    emit(creating.value ? 'created' : 'updated', response.data)
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
    emit('errored', errors.value)
  }

  isLoading.value = false
}
</script>

<template>
  <form
    class="ui form"
    @submit.prevent.stop="submit"
  >
    <div
      v-if="errors.length > 0"
      role="alert"
      class="ui negative message"
    >
      <h4 class="header">
        <translate translate-context="Content/*/Error message.Title">
          Error while saving channel
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
    <template v-if="metadataChoices">
      <fieldset
        v-if="creating && step === 1"
        class="ui grouped channel-type required field"
      >
        <legend>
          <translate translate-context="Content/Channel/Paragraph">
            What will this channel be used for?
          </translate>
        </legend>
        <div class="ui hidden divider" />
        <div class="field">
          <div
            v-for="(choice, key) in categoryChoices"
            :key="key"
            :class="['ui', 'radio', 'checkbox', {selected: choice.value == newValues.content_category}]"
          >
            <input
              :id="`category-${choice.value}`"
              v-model="newValues.content_category"
              type="radio"
              name="channel-category"
              :value="choice.value"
            >
            <label :for="`category-${choice.value}`">
              <span :class="['right floated', 'placeholder', 'image', {circular: choice.value === 'music'}]" />
              <strong>{{ choice.label }}</strong>
              <div class="ui small hidden divider" />
              {{ choice.helpText }}
            </label>
          </div>
        </div>
      </fieldset>
      <template v-if="!creating || step === 2">
        <div class="ui required field">
          <label for="channel-name">
            <translate translate-context="Content/Channel/*">Name</translate>
          </label>
          <input
            v-model="newValues.name"
            type="text"
            required
            :placeholder="labels.namePlaceholder"
          >
        </div>
        <div class="ui required field">
          <label for="channel-username">
            <translate translate-context="Content/Channel/*">Fediverse handle</translate>
          </label>
          <div class="ui left labeled input">
            <div class="ui basic label">
              @
            </div>
            <input
              v-model="newValues.username"
              type="text"
              :required="creating"
              :disabled="!creating"
              :placeholder="labels.usernamePlaceholder"
            >
          </div>
          <template v-if="creating">
            <div class="ui small hidden divider" />
            <p>
              <translate translate-context="Content/Channels/Paragraph">
                Used in URLs and to follow this channel in the Fediverse. It cannot be changed later.
              </translate>
            </p>
          </template>
        </div>
        <div class="six wide column">
          <attachment-input
            v-model="newValues.cover"
            :image-class="newValues.content_category === 'podcast' ? '' : 'circular'"
            @delete="newValues.cover = null"
          >
            <translate translate-context="Content/Channel/*">
              Channel Picture
            </translate>
          </attachment-input>
        </div>
        <div class="ui small hidden divider" />
        <div class="ui stackable grid row">
          <div class="ten wide column">
            <div class="ui field">
              <label for="channel-tags">
                <translate translate-context="*/*/*">Tags</translate>
              </label>
              <tags-selector
                id="channel-tags"
                v-model="newValues.tags"
                :required="false"
              />
            </div>
          </div>
          <div
            v-if="newValues.content_category === 'podcast'"
            class="six wide column"
          >
            <div class="ui required field">
              <label for="channel-language">
                <translate translate-context="*/*/*">Language</translate>
              </label>
              <select
                id="channel-language"
                v-model="newValues.metadata.language"
                name="channel-language"
                required
                class="ui search selection dropdown"
              >
                <option
                  v-for="(v, key) in metadataChoices.language"
                  :key="key"
                  :value="v.value"
                >
                  {{ v.label }}
                </option>
              </select>
            </div>
          </div>
        </div>
        <div class="ui small hidden divider" />
        <div class="ui field">
          <label for="channel-name">
            <translate translate-context="*/*/*">Description</translate>
          </label>
          <content-form v-model="newValues.description" />
        </div>
        <div
          v-if="newValues.content_category === 'podcast'"
          class="ui two fields"
        >
          <div class="ui required field">
            <label for="channel-itunes-category">
              <translate translate-context="*/*/*">Category</translate>
            </label>
            <select
              id="itunes-category"
              v-model="newValues.metadata.itunes_category"
              name="itunes-category"
              required
              class="ui dropdown"
            >
              <option
                v-for="(v, key) in metadataChoices.itunes_category"
                :key="key"
                :value="v.value"
              >
                {{ v.label }}
              </option>
            </select>
          </div>
          <div class="ui field">
            <label for="channel-itunes-category">
              <translate translate-context="*/*/*">Subcategory</translate>
            </label>
            <select
              id="itunes-category"
              v-model="newValues.metadata.itunes_subcategory"
              name="itunes-category"
              :disabled="!newValues.metadata.itunes_category"
              class="ui dropdown"
            >
              <option
                v-for="(v, key) in itunesSubcategories"
                :key="key"
                :value="v"
              >
                {{ v }}
              </option>
            </select>
          </div>
        </div>
        <div
          v-if="newValues.content_category === 'podcast'"
          class="ui two fields"
        >
          <div class="ui field">
            <label for="channel-itunes-email">
              <translate translate-context="*/*/*">Owner e-mail address</translate>
            </label>
            <input
              id="channel-itunes-email"
              v-model="newValues.metadata.owner_email"
              name="channel-itunes-email"
              type="email"
            >
          </div>
          <div class="ui field">
            <label for="channel-itunes-name">
              <translate translate-context="*/*/*">Owner name</translate>
            </label>
            <input
              id="channel-itunes-name"
              v-model="newValues.metadata.owner_name"
              name="channel-itunes-name"
              maxlength="255"
            >
          </div>
        </div>
        <p>
          <translate translate-context="*/*/*">
            Used for the itunes:email and itunes:name field required by certain platforms such as Spotify or iTunes.
          </translate>
        </p>
      </template>
    </template>
    <div
      v-else
      class="ui active inverted dimmer"
    >
      <div class="ui text loader">
        <translate translate-context="*/*/*">
          Loading
        </translate>
      </div>
    </div>
  </form>
</template>
