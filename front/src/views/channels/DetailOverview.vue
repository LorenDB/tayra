<script setup lang="ts">
import type { Channel, Upload } from '~/types'

import { computed, ref, reactive, watch } from 'vue'
import { whenever } from '@vueuse/core'
import { useStore } from '~/store'

import axios from 'axios'

import ChannelEntries from '~/components/audio/ChannelEntries.vue'
import ChannelSeries from '~/components/audio/ChannelSeries.vue'
import AlbumModal from '~/components/channels/AlbumModal.vue'

import useWebSocketHandler from '~/composables/useWebSocketHandler'

interface Props {
  object: Channel
}

const props = defineProps<Props>()

const store = useStore()

const isPodcast = computed(() => props.object.artist?.content_category === 'podcast')
const isOwner = computed(() => store.state.auth.authenticated && props.object.attributed_to.full_username === store.state.auth.fullUsername)

const seriesFilters = computed(() => ({
  artist: props.object.artist?.id,
  ordering: '-creation_date',
  playable: isOwner.value
    ? undefined
    : true
}))

const pendingUploads = reactive([] as Upload[])
const processedUploads = computed(() => pendingUploads.filter(upload => upload.import_status !== 'pending'))
const finishedUploads = computed(() => pendingUploads.filter(upload => upload.import_status === 'finished'))
const erroredUploads = computed(() => pendingUploads.filter(upload => upload.import_status === 'errored'))
const skippedUploads = computed(() => pendingUploads.filter(upload => upload.import_status === 'skipped'))

const pendingUploadsById = computed(() => pendingUploads.reduce((acc, upload) => {
  acc[upload.uuid] = upload
  return acc
}, {} as Record<string, Upload>))

const isOver = computed(() => pendingUploads.length === processedUploads.value.length)
const isSuccessfull = computed(() => pendingUploads.length === finishedUploads.value.length)

watch(() => store.state.channels.latestPublication, (value) => {
  if (value?.channel.uuid === props.object.uuid && value.uploads.length > 0) {
    pendingUploads.push(...value.uploads)
  }
})

const episodesKey = ref(new Date())
const seriesKey = ref(new Date())
whenever(isOver, () => {
  episodesKey.value = new Date()
  seriesKey.value = new Date()
})

const fetchPendingUploads = async () => {
  try {
    const response = await axios.get('uploads/', {
      params: { channel: props.object.uuid, import_status: ['pending', 'skipped', 'errored'], include_channels: 'true' },
      paramsSerializer: {
        indexes: null
      }
    })

    pendingUploads.length = 0
    pendingUploads.push(...response.data.results)
  } catch (error) {

  }
}

if (isOwner.value) {
  fetchPendingUploads()
    .then(() => {
      useWebSocketHandler('import.status_updated', (event) => {
        if (!pendingUploadsById.value[event.upload.uuid]) return
        Object.assign(pendingUploadsById.value[event.upload.uuid], event.upload)
      })
    })
}

const albumModal = ref()
</script>

<template>
  <section>
    <div
      v-if="pendingUploads.length > 0"
      class="ui info message"
    >
      <template v-if="isSuccessfull">
        <i
          role="button"
          class="close icon"
          @click="pendingUploads.length = 0"
        />
        <h3 class="ui header">
          {{ $t('views.channels.DetailOverview.header.uploadsSuccess') }}
        </h3>
        <p>
          {{ $t('views.channels.DetailOverview.meta.progress', {finished: processedUploads.length, total: pendingUploads.length}) }}
        </p>
      </template>
      <template v-else-if="isOver">
        <h3 class="ui header">
          {{ $t('views.channels.DetailOverview.header.uploadsFailure') }}
        </h3>
        <div class="ui hidden divider" />
        <router-link
          v-if="skippedUploads.length > 0"
          class="ui basic button"
          :to="{name: 'content.libraries.files', query: {q: 'status:skipped'}}"
        >
          {{ $t('views.channels.DetailOverview.link.skippedUploads') }}
        </router-link>
        <router-link
          v-if="erroredUploads.length > 0"
          class="ui basic button"
          :to="{name: 'content.libraries.files', query: {q: 'status:errored'}}"
        >
          {{ $t('views.channels.DetailOverview.link.erroredUploads') }}
        </router-link>
      </template>
      <template v-else>
        <div class="ui inline right floated active loader" />
        <h3 class="ui header">
          {{ $t('views.channels.DetailOverview.header.uploadsProcessing') }}
        </h3>
        <p>
          {{ $t('views.channels.DetailOverview.message.processing') }}
        </p>
        <p>
          {{ $t('views.channels.DetailOverview.meta.progress', {finished: processedUploads.length, total: pendingUploads.length}) }}
        </p>
      </template>
    </div>
    <div v-if="$store.getters['ui/layoutVersion'] === 'small'">
      <rendered-description
        :content="object.artist?.description"
        :update-url="`channels/${object.uuid}/`"
        :can-update="false"
      />
      <div class="ui hidden divider" />
    </div>
    <channel-entries
      :key="String(episodesKey) + 'entries'"
      :is-podcast="isPodcast"
      :default-cover="object.artist?.cover"
      :limit="25"
      :filters="{channel: object.uuid, ordering: '-creation_date', page_size: '25'}"
    >
      <h2 class="ui header">
        <span
          v-if="isPodcast"
        >
          {{ $t('views.channels.DetailOverview.header.latestEpisodes') }}
        </span>
        <span
          v-else
        >
          {{ $t('views.channels.DetailOverview.header.latestTracks') }}
        </span>
      </h2>
    </channel-entries>
    <div class="ui hidden divider" />
    <channel-series
      :key="String(seriesKey) + 'series'"
      :filters="seriesFilters"
      :is-podcast="isPodcast"
    >
      <h2 class="ui with-actions header">
        <span
          v-if="isPodcast"
        >
          {{ $t('views.channels.DetailOverview.header.series') }}
        </span>
        <span
          v-else
        >
          {{ $t('views.channels.DetailOverview.header.albums') }}
        </span>
        <div
          v-if="isOwner"
          class="actions"
        >
          <a @click.stop.prevent="albumModal.show = true">
            <i class="plus icon" />
            {{ $t('views.channels.DetailOverview.link.addAlbum') }}
          </a>
        </div>
      </h2>
    </channel-series>
    <album-modal
      v-if="isOwner"
      ref="albumModal"
      :channel="object"
      @created="albumModal.show = false; seriesKey = new Date()"
    />
  </section>
</template>
