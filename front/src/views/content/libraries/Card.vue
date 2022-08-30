<script setup lang="ts">
import type { Library, PrivacyLevel } from '~/types'

import { humanSize } from '~/utils/filters'
import { useGettext } from 'vue3-gettext'
import { computed } from 'vue'

import useSharedLabels from '~/composables/locale/useSharedLabels'

interface Props {
  library: Library
}

defineProps<Props>()

const { $pgettext } = useGettext()

const sharedLabels = useSharedLabels()

const sizeLabel = computed(() => $pgettext('Content/Library/Card.Help text', 'Total size of the files in this library'))

const privacyTooltips = (level: PrivacyLevel) => `Visibility: ${sharedLabels.fields.privacy_level.choices[level].toLowerCase()}`
</script>

<template>
  <div class="ui card">
    <div class="content">
      <h4 class="header">
        {{ library.name }}
        <span
          v-if="library.privacy_level === 'me'"
          class="right floated"
          :data-tooltip="privacyTooltips('me')"
        >
          <i class="small lock icon" />
        </span>
        <span
          v-else-if="library.privacy_level === 'instance'"
          class="right floated"
          :data-tooltip="privacyTooltips('instance')"
        >
          <i class="small circle outline icon" />
        </span>
        <span
          v-else-if="library.privacy_level === 'everyone'"
          class="right floated"
          :data-tooltip="privacyTooltips('everyone')"
        >
          <i class="small globe icon" />
        </span>
      </h4>
      <div class="meta">
        <span>
          <i class="small outline clock icon" />
          <human-date :date="library.creation_date" />
        </span>
      </div>
      <div class="description">
        {{ library.description }}
        <div class="ui hidden divider" />
      </div>
      <div class="content">
        <span
          v-if="library.size"
          class="right floated"
          :data-tooltip="sizeLabel"
        >
          <i class="database icon" />
          {{ humanSize(library.size) }}
        </span>
        <i class="music icon" />
        <translate
          translate-context="*/*/*"
          :translate-params="{count: library.uploads_count}"
          :translate-n="library.uploads_count"
          translate-plural="%{ count } tracks"
        >
          %{ count } track
        </translate>
      </div>
    </div>
    <div class="ui bottom basic attached buttons">
      <router-link
        :to="{name: 'library.detail.upload', params: {id: library.uuid}}"
        class="ui button"
      >
        <translate translate-context="Content/Library/Card.Button.Label/Verb">
          Upload
        </translate>
      </router-link>
      <router-link
        :to="{name: 'library.detail', params: {id: library.uuid}}"
        class="ui button"
      >
        <translate translate-context="Content/Library/Card.Button.Label/Noun">
          Library Details
        </translate>
      </router-link>
    </div>
  </div>
</template>
