<script setup lang="ts">
import type { Library, LibraryFollow } from '~/types'

import { ref } from 'vue'

import axios from 'axios'

import LibraryFilesTable from '~/views/content/libraries/FilesTable.vue'
import LibraryForm from '~/views/content/libraries/Form.vue'

import useErrorHandler from '~/composables/useErrorHandler'

interface Events {
  (e: 'updated'): void
}

interface Props {
  object: Library
}

const emit = defineEmits<Events>()
const props = defineProps<Props>()

type ResponseType = { count: number, results: any[] }
const follows = ref<ResponseType | null>(null)

const isLoading = ref(false)
const fetchData = async () => {
  isLoading.value = true

  try {
    const response = await axios.get(`libraries/${props.object.uuid}/follows/`)
    follows.value = response.data
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoading.value = false
}

fetchData()

const updateApproved = async (follow: LibraryFollow, approved: boolean) => {
  try {
    await axios.post(`federation/follows/library/${follow.uuid}/${approved ? 'accept' : 'reject'}/`)
    follow.approved = approved
  } catch (error) {
    useErrorHandler(error as Error)
  }
}
</script>

<template>
  <section>
    <library-form
      :library="object"
      @updated="emit('updated')"
      @deleted="$router.push({name: 'profile.overview', params: {username: $store.state.auth.username}})"
    />
    <div class="ui hidden divider" />
    <h2 class="ui header">
      Library contents
    </h2>
    <library-files-table :filters="{ library: object.uuid }" />

    <div class="ui hidden divider" />
    <h2 class="ui header">
      Followers
    </h2>
    <div
      v-if="isLoading"
      :class="['ui', {'active': isLoading}, 'inverted', 'dimmer']"
    >
      <div class="ui text loader">
        Loading followers…
      </div>
    </div>
    <table
      v-else-if="(follows ?? { count: 0 }).count > 0"
      class="ui table"
    >
      <thead>
        <tr>
          <th>
            User
          </th>
          <th>
            Date
          </th>
          <th>
            Status
          </th>
          <th>
            Action
          </th>
        </tr>
      </thead>
      <tr
        v-for="follow in follows?.results ?? []"
        :key="follow.fid"
      >
        <td><actor-link :actor="follow.actor" /></td>
        <td><human-date :date="follow.creation_date" /></td>
        <td>
          <span
            v-if="follow.approved === null"
            :class="['ui', 'warning', 'basic', 'label']"
          >
            Pending approval
          </span>
          <span
            v-else-if="follow.approved === true"
            :class="['ui', 'success', 'basic', 'label']"
          >
            Accepted
          </span>
          <span
            v-else-if="follow.approved === false"
            :class="['ui', 'danger', 'basic', 'label']"
          >
            Rejected
          </span>
        </td>
        <td>
          <button
            v-if="follow.approved === null || follow.approved === false"
            :class="['ui', 'mini', 'icon', 'labeled', 'success', 'button']"
            @click="updateApproved(follow, true)"
          >
            <i class="ui check icon" />               Accept
          </button>
          <button
            v-if="follow.approved === null || follow.approved === true"
            :class="['ui', 'mini', 'icon', 'labeled', 'danger', 'button']"
            @click="updateApproved(follow, false)"
          >
            <i class="ui x icon" />               Reject
          </button>
        </td>
      </tr>
    </table>
    <p v-else>
      Nobody is following this library
    </p>
  </section>
</template>
