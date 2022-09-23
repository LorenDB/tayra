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
      {{ $t('views.library.Edit.header.libraryContents') }}
    </h2>
    <library-files-table :filters="{ library: object.uuid }" />

    <div class="ui hidden divider" />
    <h2 class="ui header">
      {{ $t('views.library.Edit.header.followers') }}
    </h2>
    <div
      v-if="isLoading"
      :class="['ui', {'active': isLoading}, 'inverted', 'dimmer']"
    >
      <div class="ui text loader">
        {{ $t('views.library.Edit.loading.followers') }}
      </div>
    </div>
    <table
      v-else-if="(follows ?? { count: 0 }).count > 0"
      class="ui table"
    >
      <thead>
        <tr>
          <th>
            {{ $t('views.library.Edit.table.action.header.user') }}
          </th>
          <th>
            {{ $t('views.library.Edit.table.action.header.date') }}
          </th>
          <th>
            {{ $t('views.library.Edit.table.action.header.status') }}
          </th>
          <th>
            {{ $t('views.library.Edit.table.action.header.action') }}
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
            {{ $t('views.library.Edit.table.action.status.pending') }}
          </span>
          <span
            v-else-if="follow.approved === true"
            :class="['ui', 'success', 'basic', 'label']"
          >
            {{ $t('views.library.Edit.table.action.status.accepted') }}
          </span>
          <span
            v-else-if="follow.approved === false"
            :class="['ui', 'danger', 'basic', 'label']"
          >
            {{ $t('views.library.Edit.table.action.status.rejected') }}
          </span>
        </td>
        <td>
          <button
            v-if="follow.approved === null || follow.approved === false"
            :class="['ui', 'mini', 'icon', 'labeled', 'success', 'button']"
            @click="updateApproved(follow, true)"
          >
            <i class="ui check icon" />
            {{ $t('views.library.Edit.button.accept') }}
          </button>
          <button
            v-if="follow.approved === null || follow.approved === true"
            :class="['ui', 'mini', 'icon', 'labeled', 'danger', 'button']"
            @click="updateApproved(follow, false)"
          >
            <i class="ui x icon" />
            {{ $t('views.library.Edit.button.reject') }}
          </button>
        </td>
      </tr>
    </table>
    <p v-else>
      {{ $t('views.library.Edit.empty.noFollowers') }}
    </p>
  </section>
</template>
