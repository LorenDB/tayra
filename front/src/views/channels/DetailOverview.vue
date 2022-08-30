<script setup lang="ts">
import type { Channel, Upload } from '~/types'

import { computed, ref, reactive, watch } from 'vue'
import { whenever } from '@vueuse/core'
import { useStore } from '~/store'

import axios from 'axios'
import qs from 'qs'

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
      paramsSerializer: function (params) {
        return qs.stringify(params, { indices: false })
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
          <translate translate-context="Content/Channel/Header">
            Uploads published successfully
          </translate>
        </h3>
        <p>
          <translate translate-context="Content/Channel/Paragraph">
            Processed uploads:
          </translate> {{ processedUploads.length }}/{{ pendingUploads.length }}
        </p>
      </template>
      <template v-else-if="isOver">
        <h3 class="ui header">
          <translate translate-context="Content/Channel/Header">
            Some uploads couldn't be published
          </translate>
        </h3>
        <div class="ui hidden divider" />
        <router-link
          v-if="skippedUploads.length > 0"
          class="ui basic button"
          :to="{name: 'content.libraries.files', query: {q: 'status:skipped'}}"
        >
          <translate translate-context="Content/Channel/Button">
            View skipped uploads
          </translate>
        </router-link>
        <router-link
          v-if="erroredUploads.length > 0"
          class="ui basic button"
          :to="{name: 'content.libraries.files', query: {q: 'status:errored'}}"
        >
          <translate translate-context="Content/Channel/Button">
            View errored uploads
          </translate>
        </router-link>
      </template>
      <template v-else>
        <div class="ui inline right floated active loader" />
        <h3 class="ui header">
          <translate translate-context="Content/Channel/Header">
            Uploads are being processed
          </translate>
        </h3>
        <p>
          <translate translate-context="Content/Channel/Paragraph">
            Your uploads are being processed by Funkwhale and will be live very soon.
          </translate>
        </p>
        <p>
          <translate translate-context="Content/Channel/Paragraph">
            Processed uploads:
          </translate> {{ processedUploads.length }}/{{ pendingUploads.length }}
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
        <translate
          v-if="isPodcast"
          translate-context="Content/Channel/Paragraph"
        >
          Latest episodes
        </translate>
        <translate
          v-else
          translate-context="Content/Channel/Paragraph"
        >
          Latest tracks
        </translate>
      </h2>
    </channel-entries>
    <div class="ui hidden divider" />
    <channel-series
      :key="String(seriesKey) + 'series'"
      :filters="seriesFilters"
      :is-podcast="isPodcast"
    >
      <h2 class="ui with-actions header">
        <translate
          v-if="isPodcast"
          translate-context="Content/Channel/Paragraph"
        >
          Series
        </translate>
        <translate
          v-else
          translate-context="*/*/*"
        >
          Albums
        </translate>
        <div
          v-if="isOwner"
          class="actions"
        >
          <a @click.stop.prevent="albumModal.show = true">
            <i class="plus icon" />
            <translate translate-context="Content/Profile/Button">Add new</translate>
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
