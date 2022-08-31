<script setup lang="ts">
import type { Library, Plugin, BackendError } from '~/types'

import axios from 'axios'
import { clone } from 'lodash-es'
import useMarkdown, { useMarkdownRaw } from '~/composables/useMarkdown'
import { ref } from 'vue'

interface Props {
  plugin: Plugin
  libraries: Library[]
}

const props = defineProps<Props>()

const description = useMarkdown(() => props.plugin.description ?? '')
const enabled = ref(props.plugin.enabled)
const values = clone(props.plugin.values ?? {})

const errors = ref([] as string[])
const isLoading = ref(false)
const submit = async () => {
  isLoading.value = true
  errors.value = []

  try {
    await axios.post(`plugins/${props.plugin.name}/${enabled.value ? 'enable' : 'disable'}`)
    await axios.post(`plugins/${props.plugin.name}`, values)
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }

  isLoading.value = false
}

const scan = async () => {
  isLoading.value = true
  errors.value = []

  try {
    await axios.post(`plugins/${props.plugin.name}/scan`, values)
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }

  isLoading.value = false
}

const submitAndScan = async () => {
  await submit()
  await scan()
}
</script>

<template>
  <form
    :class="['ui segment form', {loading: isLoading}]"
    @submit.prevent="submit"
  >
    <h3>{{ plugin.label }}</h3>
    <sanitized-html
      v-if="plugin.description"
      :html="description"
    />
    <template v-if="plugin.homepage">
      <div class="ui small hidden divider" />
      <a
        :href="plugin.homepage"
        target="_blank"
      >
        <i class="external icon" />
        <translate translate-context="Footer/*/List item.Link/Short, Noun">Documentation</translate>
      </a>
    </template>
    <div class="ui clearing hidden divider" />
    <div
      v-if="errors.length > 0"
      role="alert"
      class="ui negative message"
    >
      <h4 class="header">
        <translate translate-context="Content/*/Error message.Title">
          Error while saving plugin
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
    <div class="field">
      <div class="ui toggle checkbox">
        <input
          :id="`${plugin.name}-enabled`"
          v-model="enabled"
          type="checkbox"
        >
        <label :for="`${plugin.name}-enabled`"><translate translate-context="*/*/*">Enabled</translate></label>
      </div>
    </div>
    <div class="ui clearing hidden divider" />
    <div
      v-if="plugin.source"
      class="field"
    >
      <label for="plugin-library"><translate translate-context="*/*/*/Noun">Library</translate></label>
      <select
        id="plugin-library"
        v-model="values['library']"
      >
        <option
          v-for="l in libraries"
          :key="l.uuid"
          :value="l.uuid"
        >
          {{ l.name }}
        </option>
      </select>
      <div>
        <translate translate-context="*/*/Paragraph/Noun">
          Library where files should be imported.
        </translate>
      </div>
    </div>
    <template v-if="(plugin.conf?.length ?? 0) > 0">
      <template
        v-for="field in plugin.conf"
        :key="field.name"
      >
        <div
          v-if="field.type === 'text'"
          class="field"
        >
          <label :for="`plugin-${field.name}`">{{ field.label || field.name }}</label>
          <input
            :id="`plugin-${field.name}`"
            v-model="values[field.name]"
            type="text"
          >
          <sanitized-html
            v-if="field.help"
            :html="useMarkdownRaw(field.help)"
          />
        </div>
        <div
          v-if="field.type === 'long_text'"
          class="field"
        >
          <label :for="`plugin-${field.name}`">{{ field.label || field.name }}</label>
          <textarea
            :id="`plugin-${field.name}`"
            v-model="values[field.name]"
            type="text"
            rows="5"
          />
          <sanitized-html
            v-if="field.help"
            :html="useMarkdownRaw(field.help)"
          />
        </div>
        <div
          v-if="field.type === 'url'"
          class="field"
        >
          <label :for="`plugin-${field.name}`">{{ field.label || field.name }}</label>
          <input
            :id="`plugin-${field.name}`"
            v-model="values[field.name]"
            type="url"
          >
          <sanitized-html
            v-if="field.help"
            :html="useMarkdownRaw(field.help)"
          />
        </div>
        <div
          v-if="field.type === 'password'"
          class="field"
        >
          <label :for="`plugin-${field.name}`">{{ field.label || field.name }}</label>
          <input
            :id="`plugin-${field.name}`"
            v-model="values[field.name]"
            type="password"
          >
          <sanitized-html
            v-if="field.help"
            :html="useMarkdownRaw(field.help)"
          />
        </div>
      </template>
    </template>
    <button
      type="submit"
      :class="['ui', {'loading': isLoading}, 'right', 'floated', 'button']"
    >
      <translate translate-context="Content/*/Button.Label/Verb">
        Save
      </translate>
    </button>
    <button
      v-if="plugin.source"
      :class="['ui', {'loading': isLoading}, 'right', 'floated', 'button']"
      @click.prevent="submitAndScan"
    >
      <translate translate-context="Content/*/Button.Label/Verb">
        Scan
      </translate>
    </button>
    <div class="ui clearing hidden divider" />
  </form>
</template>
