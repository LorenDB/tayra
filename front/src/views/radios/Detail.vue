<script setup lang="ts">
import type { Track, Radio } from "~/types"

import axios from 'axios'
import TrackTable from '~/components/audio/track/Table.vue'
import RadioButton from '~/components/radios/Button.vue'
import Pagination from '~/components/vui/Pagination.vue'
import { ref, computed, watch } from 'vue'
import { useGettext } from 'vue3-gettext'
import { useRouter } from 'vue-router'

interface Props {
  id: string
}

const props = defineProps<Props>()

const radio = ref<Radio | null>(null)
const tracks = ref([] as Track[])
const totalTracks = ref(0)
const page = ref(1)

const { $pgettext } = useGettext()
const labels = computed(() => ({
  title: $pgettext('Head/Radio/Title', 'Radio')
}))

const isLoading = ref(false)
const fetchData = async () => {
  isLoading.value = true

  const url = `radios/radios/${props.id}/`

  try {
    const radioResponse = await axios.get(url)
    radio.value = radioResponse.data

    const tracksResponse = await axios.get(url + 'tracks/', { params: { page: page.value }})
    totalTracks.value = tracksResponse.data.count
    tracks.value = tracksResponse.data.results
  } catch (error) {
    // TODO (wvffle): Handle error
  }

  isLoading.value = false
}

watch(page, fetchData, { immediate: true })

const router = useRouter()
const deleteRadio = async () => {
  try {
    await axios.delete(`radios/radios/${props.id}/`)
    return router.push({ path: '/library' })
  } catch (error) {
    // TODO (wvffle): Handle error
  }
}
</script>

<template>
  <main>
    <div
      v-if="isLoading"
      v-title="labels.title"
      class="ui vertical segment"
    >
      <div :class="['ui', 'centered', 'active', 'inline', 'loader']" />
    </div>
    <section
      v-if="!isLoading && radio"
      v-title="radio.name"
      class="ui head vertical center aligned stripe segment"
    >
      <div class="segment-content">
        <h2 class="ui center aligned icon header">
          <i class="circular inverted feed primary icon" />
          <div class="content">
            {{ radio.name }}
            <div class="sub header">
              Radio containing {{ totalTracks }} tracks,
              by <username :username="radio.user.username" />
            </div>
          </div>
        </h2>
        <div class="ui hidden divider" />
        <radio-button
          type="custom"
          :custom-radio-id="radio.id"
        />
        <template v-if="$store.state.auth.username === radio.user.username">
          <router-link
            class="ui icon labeled button"
            :to="{name: 'library.radios.edit', params: {id: radio.id}}"
          >
            <i class="pencil icon" />
            Edit…
          </router-link>
          <dangerous-button
            class="ui labeled danger icon button"
            :action="deleteRadio"
          >
            <i class="trash icon" /> Delete
            <template #modal-header>
              <p
                v-translate="{radio: radio.name}"
                translate-context="Popup/Radio/Title"
                :translate-params="{radio: radio.name}"
              >
                Do you want to delete the radio "%{ radio }"?
              </p>
            </template>
            <template #modal-content>
              <p>
                <translate translate-context="Popup/Radio/Paragraph">
                  This will completely delete this radio and cannot be undone.
                </translate>
              </p>
            </template>
            <template #modal-confirm>
              <p>
                <translate translate-context="Popup/Radio/Button.Label/Verb">
                  Delete radio
                </translate>
              </p>
            </template>
          </dangerous-button>
        </template>
      </div>
    </section>
    <section
      v-if="totalTracks > 0"
      class="ui vertical stripe segment"
    >
      <h2>
        <translate translate-context="*/*/*">
          Tracks
        </translate>
      </h2>
      <track-table :tracks="tracks" />
      <div class="ui center aligned basic segment">
        <pagination
          v-if="totalTracks > 25"
          v-model:current="page"
          :paginate-by="25"
          :total="totalTracks"
        />
      </div>
    </section>
    <div
      v-else-if="!isLoading && totalTracks === 0"
      class="ui placeholder segment"
    >
      <div class="ui icon header">
        <i class="rss icon" />
        <translate
          translate-context="Content/Radios/Placeholder"
        >
          No tracks have been added to this radio yet
        </translate>
      </div>
      <router-link
        v-if="$store.state.auth.username === radio?.user.username"
        class="ui success icon labeled button"
        :to="{name: 'library.radios.edit', params: { id: radio?.id }}"
      >
        <i class="pencil icon" />
        Edit…
      </router-link>
    </div>
  </main>
</template>
