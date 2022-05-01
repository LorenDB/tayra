<template>
  <form
    :class="['ui segment form', {loading: isLoading}]"
    @submit.prevent="submit"
  >
    <h3>{{ plugin.label }}</h3>
    <div
      v-if="plugin.description"
      v-html="markdown.makeHtml(plugin.description)"
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
    <template v-if="plugin.conf?.length > 0">
      <template v-for="(field, key) in plugin.conf">
        <div
          v-if="field.type === 'text'"
          :key="key"
          class="field"
        >
          <label :for="`plugin-${field.name}`">{{ field.label || field.name }}</label>
          <input
            :id="`plugin-${field.name}`"
            v-model="values[field.name]"
            type="text"
          >
          <div
            v-if="field.help"
            v-html="markdown.makeHtml(field.help)"
          />
        </div>
        <div
          v-if="field.type === 'long_text'"
          :key="key"
          class="field"
        >
          <label :for="`plugin-${field.name}`">{{ field.label || field.name }}</label>
          <textarea
            :id="`plugin-${field.name}`"
            v-model="values[field.name]"
            type="text"
            rows="5"
          />
          <div
            v-if="field.help"
            v-html="markdown.makeHtml(field.help)"
          />
        </div>
        <div
          v-if="field.type === 'url'"
          :key="key"
          class="field"
        >
          <label :for="`plugin-${field.name}`">{{ field.label || field.name }}</label>
          <input
            :id="`plugin-${field.name}`"
            v-model="values[field.name]"
            type="url"
          >
          <div
            v-if="field.help"
            v-html="markdown.makeHtml(field.help)"
          />
        </div>
        <div
          v-if="field.type === 'password'"
          :key="key"
          class="field"
        >
          <label :for="`plugin-${field.name}`">{{ field.label || field.name }}</label>
          <input
            :id="`plugin-${field.name}`"
            v-model="values[field.name]"
            type="password"
          >
          <div
            v-if="field.help"
            v-html="markdown.makeHtml(field.help)"
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
      type="scan"
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

<script>
import axios from 'axios'
import { clone } from 'lodash-es'
import showdown from 'showdown'
export default {
  props: {
    plugin: { type: Object, required: true },
    libraries: { type: Array, required: true }
  },
  data () {
    return {
      markdown: new showdown.Converter(),
      isLoading: false,
      enabled: this.plugin.enabled,
      values: clone(this.plugin.values || {}),
      errors: []
    }
  },
  methods: {
    async submit () {
      this.isLoading = true
      this.errors = []
      const url = `plugins/${this.plugin.name}`
      const enableUrl = this.enabled ? `${url}/enable` : `${url}/disable`
      await axios.post(enableUrl)
      try {
        await axios.post(url, this.values)
      } catch (e) {
        this.errors = e.backendErrors
      }
      this.isLoading = false
    },
    async scan () {
      this.isLoading = true
      this.errors = []
      const url = `plugins/${this.plugin.name}/scan`
      try {
        await axios.post(url, this.values)
      } catch (e) {
        this.errors = e.backendErrors
      }
      this.isLoading = false
    },
    async submitAndScan () {
      await this.submit()
      await this.scan()
    }
  }
}
</script>
