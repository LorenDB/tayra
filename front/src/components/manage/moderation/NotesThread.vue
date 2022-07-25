<script setup lang="ts">
import type { Note } from '~/types'

import axios from 'axios'
import { useMarkdownRaw } from '~/composables/useMarkdown'
import { ref } from 'vue'

interface Props {
  notes: Note[]
}

defineProps<Props>()

const emit = defineEmits(['deleted'])
const isLoading = ref(false)
const remove = async (note: Note) => {
  isLoading.value = true

  try {
    await axios.delete(`manage/moderation/notes/${note.uuid}/`)
    emit('deleted', note.uuid)
  } catch (error) {
    // TODO (wvffle): Handle error
  }

  isLoading.value = false
}
</script>

<template>
  <div class="ui feed">
    <div
      v-for="note in notes"
      :key="note.uuid"
      class="event"
    >
      <div class="label">
        <i class="comment outline icon" />
      </div>
      <div class="content">
        <div class="summary">
          <actor-link
            :admin="true"
            :actor="note.author"
          />
          <div class="date">
            <human-date :date="note.creation_date" />
          </div>
        </div>
        <div class="extra text">
          <expandable-div :content="note.summary">
            <sanitized-html :html="useMarkdownRaw(note.summary ?? '')" />
          </expandable-div>
        </div>
        <div class="meta">
          <dangerous-button
            :class="['ui', {loading: isLoading}, 'basic borderless mini button']"
            @confirm="remove(note)"
          >
            <i class="trash icon" />
            <translate translate-context="*/*/*/Verb">
              Delete
            </translate>
            <template #modal-header>
              <p>
                <translate translate-context="Popup/Moderation/Title">
                  Delete this note?
                </translate>
              </p>
            </template>
            <template #modal-content>
              <div>
                <p>
                  <translate translate-context="Content/Moderation/Paragraph">
                    The note will be removed. This action is irreversible.
                  </translate>
                </p>
              </div>
            </template>
            <template #modal-confirm>
              <p>
                <translate translate-context="*/*/*/Verb">
                  Delete
                </translate>
              </p>
            </template>
          </dangerous-button>
        </div>
      </div>
    </div>
  </div>
</template>
