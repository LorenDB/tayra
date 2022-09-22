<script setup lang="ts">
import type { Note } from '~/types'

import { useMarkdownRaw } from '~/composables/useMarkdown'
import { ref } from 'vue'

import axios from 'axios'

import useErrorHandler from '~/composables/useErrorHandler'

interface Events {
  (e: 'deleted', uuid: string): void
}
interface Props {
  notes: Note[]
}

const emit = defineEmits<Events>()
defineProps<Props>()

const isLoading = ref(false)
const remove = async (note: Note) => {
  isLoading.value = true

  try {
    await axios.delete(`manage/moderation/notes/${note.uuid}/`)
    emit('deleted', note.uuid)
  } catch (error) {
    useErrorHandler(error as Error)
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
            {{ $t('components.manage.moderation.NotesThread.button.delete') }}
            <template #modal-header>
              <p>
                {{ $t('components.manage.moderation.NotesThread.modal.delete.header') }}
              </p>
            </template>
            <template #modal-content>
              <div>
                <p>
                  {{ $t('components.manage.moderation.NotesThread.modal.delete.content.warning') }}
                </p>
              </div>
            </template>
            <template #modal-confirm>
              <p>
                {{ $t('components.manage.moderation.NotesThread.button.delete') }}
              </p>
            </template>
          </dangerous-button>
        </div>
      </div>
    </div>
  </div>
</template>
