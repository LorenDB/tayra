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
          <translate

            :translate-params="{id: obj.uuid.substring(0, 8)}"
          >
            Request %{ id }
          </translate>
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
                    Submitted by
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
                    Creation date
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
                    Status
                  </td>
                  <td>
                    <template v-if="obj.status === 'pending'">
                      <i class="warning hourglass icon" />
                      Pending
                    </template>
                    <template v-else-if="obj.status === 'refused'">
                      <i class="danger x icon" />
                      Refused
                    </template>
                    <template v-else-if="obj.status === 'approved'">
                      <i class="success check icon" />
                      Approved
                    </template>
                  </td>
                </tr>
                <tr>
                  <td>
                    Assigned to
                  </td>
                  <td>
                    <div v-if="obj.assigned_to">
                      <actor-link
                        :admin="true"
                        :actor="obj.assigned_to"
                      />
                    </div>
                    <translate
                      v-else
                    >
                      N/A
                    </translate>
                  </td>
                </tr>
                <tr>
                  <td>
                    Resolution date
                  </td>
                  <td>
                    <human-date
                      v-if="obj.handled_date"
                      :date="obj.handled_date"
                      :icon="true"
                    />
                    <translate
                      v-else
                    >
                      N/A
                    </translate>
                  </td>
                </tr>
                <tr>
                  <td>
                    Internal notes
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
            Message
          </h3>
          <p>
            This user wants to sign-up on your pod.
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
              <translate
                v-else
              >
                N/A
              </translate>
              <div class="ui hidden divider" />
            </div>
          </template>
        </div>
        <aside class="column">
          <div v-if="obj.status != 'approved'">
            <h3>
              Actions
            </h3>
            <div class="ui labelled icon basic buttons">
              <button
                v-if="obj.status === 'pending' || obj.status === 'refused'"
                :class="['ui', {loading: isLoading}, 'button']"
                @click="approve(true)"
              >
                <i class="success check icon" />&nbsp;
                Approve
              </button>
              <button
                v-if="obj.status === 'pending'"
                :class="['ui', {loading: isLoading}, 'button']"
                @click="approve(false)"
              >
                <i class="danger x icon" />&nbsp;
                Refuse
              </button>
            </div>
          </div>
          <h3>
            Internal notes
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
