<script setup lang="ts">
import type { UserRequest, UserRequestStatus } from '~/types'

import { useStore } from '~/store'
import { ref } from 'vue'

import axios from 'axios'

import NotesThread from '~/components/manage/moderation/NotesThread.vue'
import NoteForm from '~/components/manage/moderation/NoteForm.vue'

import useErrorHandler from '~/composables/useErrorHandler'

interface Events {
  (e: 'handled', status: UserRequestStatus): void
}

interface Props {
  initObj: UserRequest
}

const emit = defineEmits<Events>()
const props = defineProps<Props>()

const store = useStore()

const obj = ref(props.initObj)

const isCollapsed = ref(false)
const isLoading = ref(false)
const approve = async (isApproved: boolean) => {
  isLoading.value = true

  try {
    const status = isApproved
      ? 'approved'
      : 'refused'

    await axios.patch(`manage/moderation/requests/${obj.value.uuid}/`, {
      status
    })

    emit('handled', status)

    if (isApproved) {
      isCollapsed.value = true
    }

    store.commit('ui/incrementNotifications', {
      type: 'pendingReviewRequests',
      count: -1
    })
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoading.value = false
}

const handleRemovedNote = (uuid: string) => {
  obj.value.notes = obj.value.notes.filter((note) => note.uuid !== uuid)
}
</script>

<template>
  <div class="ui fluid user-request card">
    <div class="content">
      <h4 class="header">
        <router-link :to="{name: 'manage.moderation.requests.detail', params: {id: obj.uuid}}">
          {{ $t('components.manage.moderation.UserRequestCard.link.request', {id: obj.uuid.substring(0, 8)}) }}
        </router-link>
        <collapse-link
          v-model="isCollapsed"
          class="right floated"
        />
      </h4>
      <div class="content">
        <div class="ui hidden divider" />
        <div class="ui stackable two column grid">
          <div class="column">
            <table class="ui very basic unstackable table">
              <tbody>
                <tr>
                  <td>
                    {{ $t('components.manage.moderation.UserRequestCard.table.request.submittedBy') }}
                  </td>
                  <td>
                    <actor-link
                      :admin="true"
                      :actor="obj.submitter"
                    />
                  </td>
                </tr>
                <tr>
                  <td>
                    {{ $t('components.manage.moderation.UserRequestCard.table.request.creationDate') }}
                  </td>
                  <td>
                    <human-date
                      :date="obj.creation_date"
                      :icon="true"
                    />
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <div class="column">
            <table class="ui very basic unstackable table">
              <tbody>
                <tr>
                  <td>
                    {{ $t('components.manage.moderation.UserRequestCard.table.status.status') }}
                  </td>
                  <td>
                    <template v-if="obj.status === 'pending'">
                      <i class="warning hourglass icon" />
                      {{ $t('components.manage.moderation.UserRequestCard.table.status.pending') }}
                    </template>
                    <template v-else-if="obj.status === 'refused'">
                      <i class="danger x icon" />
                      {{ $t('components.manage.moderation.UserRequestCard.table.status.refused') }}
                    </template>
                    <template v-else-if="obj.status === 'approved'">
                      <i class="success check icon" />
                      {{ $t('components.manage.moderation.UserRequestCard.table.status.approved') }}
                    </template>
                  </td>
                </tr>
                <tr>
                  <td>
                    {{ $t('components.manage.moderation.UserRequestCard.table.status.assignedTo') }}
                  </td>
                  <td>
                    <div v-if="obj.assigned_to">
                      <actor-link
                        :admin="true"
                        :actor="obj.assigned_to"
                      />
                    </div>
                    <span
                      v-else
                    >
                      {{ $t('components.manage.moderation.UserRequestCard.notApplicable') }}
                    </span>
                  </td>
                </tr>
                <tr>
                  <td>
                    {{ $t('components.manage.moderation.UserRequestCard.table.status.resolutionDate') }}
                  </td>
                  <td>
                    <human-date
                      v-if="obj.handled_date"
                      :date="obj.handled_date"
                      :icon="true"
                    />
                    <span v-else>
                      {{ $t('components.manage.moderation.UserRequestCard.notApplicable') }}
                    </span>
                  </td>
                </tr>
                <tr>
                  <td>
                    {{ $t('components.manage.moderation.UserRequestCard.table.status.internalNotes') }}
                  </td>
                  <td>
                    <i class="comment icon" />
                    {{ obj.notes.length }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
    <div
      v-if="!isCollapsed"
      class="main content"
    >
      <div class="ui stackable two column grid">
        <div class="column">
          <h3>
            {{ $t('components.manage.moderation.UserRequestCard.header.signup') }}
          </h3>
          <p>
            {{ $t('components.manage.moderation.UserRequestCard.message.signup') }}
          </p>
          <template v-if="obj.metadata">
            <div class="ui hidden divider" />
            <div
              v-for="(value, key) in obj.metadata"
              :key="key"
            >
              <h4>{{ key }}</h4>
              <p v-if="value">
                {{ value }}
              </p>
              <span v-else>
                {{ $t('components.manage.moderation.UserRequestCard.notApplicable') }}
              </span>
              <div class="ui hidden divider" />
            </div>
          </template>
        </div>
        <aside class="column">
          <div v-if="obj.status != 'approved'">
            <h3>
              {{ $t('components.manage.moderation.UserRequestCard.header.actions') }}
            </h3>
            <div class="ui labelled icon basic buttons">
              <button
                v-if="obj.status === 'pending' || obj.status === 'refused'"
                :class="['ui', {loading: isLoading}, 'button']"
                @click="approve(true)"
              >
                <i class="success check icon" />&nbsp;
                {{ $t('components.manage.moderation.UserRequestCard.button.approve') }}
              </button>
              <button
                v-if="obj.status === 'pending'"
                :class="['ui', {loading: isLoading}, 'button']"
                @click="approve(false)"
              >
                <i class="danger x icon" />&nbsp;
                {{ $t('components.manage.moderation.UserRequestCard.button.reject') }}
              </button>
            </div>
          </div>
          <h3>
            {{ $t('components.manage.moderation.UserRequestCard.header.notes') }}
          </h3>
          <notes-thread
            :notes="obj.notes"
            @deleted="handleRemovedNote($event)"
          />
          <note-form
            :target="{type: 'request', uuid: obj.uuid}"
            @created="obj.notes.push($event)"
          />
        </aside>
      </div>
    </div>
  </div>
</template>
