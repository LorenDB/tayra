<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { ref, computed } from 'vue'

import axios from 'axios'

import ChannelsWidget from '~/components/audio/ChannelsWidget.vue'
import PlaylistWidget from '~/components/playlists/Widget.vue'
import TrackWidget from '~/components/audio/track/Widget.vue'
import AlbumWidget from '~/components/audio/album/Widget.vue'

import useErrorHandler from '~/composables/useErrorHandler'
import useLogger from '~/composables/useLogger'

interface Props {
  scope?: string
}

withDefaults(defineProps<Props>(), {
  scope: 'all'
})

const artists = ref([])

const logger = useLogger()

const { t } = useI18n()
const labels = computed(() => ({
  title: t('components.library.Home.title')
}))

const isLoading = ref(false)
const fetchData = async () => {
  isLoading.value = true
  const stop = logger.time('Loading latest artists')

  const params = {
    ordering: '-creation_date',
    playable: true
  }

  try {
    const response = await axios.get('artists/', { params })
    artists.value = response.data.results
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoading.value = false
  stop()
}

fetchData()
</script>

<template>
  <main
    :key="$route?.name ?? undefined"
    v-title="labels.title"
  >
    <section class="ui vertical stripe segment">
      <div class="ui stackable three column grid">
        <div class="column">
          <track-widget
            :url="'history/listenings/'"
            :filters="{ scope, ordering: '-creation_date' }"
            :websocket-handlers="['Listen']"
          >
            <template #title>
              {{ $t('components.library.Home.header.recentlyListened') }}
            </template>
          </track-widget>
        </div>
        <div class="column">
          <track-widget
            :url="'favorites/tracks/'"
            :filters="{scope: scope, ordering: '-creation_date'}"
          >
            <template #title>
              {{ $t('components.library.Home.header.recentlyFavorited') }}
            </template>
          </track-widget>
        </div>
        <div class="column">
          <playlist-widget
            :url="'playlists/'"
            :filters="{scope: scope, playable: true, ordering: '-modification_date'}"
          >
            <template #title>
              {{ $t('components.library.Home.header.playlists') }}
            </template>
          </playlist-widget>
        </div>
      </div>
      <div class="ui section hidden divider" />
      <div class="ui stackable one column grid">
        <div class="column">
          <album-widget :filters="{scope: scope, playable: true, ordering: '-creation_date'}">
            <template #title>
              {{ $t('components.library.Home.header.recentlyAdded') }}
            </template>
          </album-widget>
        </div>
      </div>
      <template v-if="scope === 'all'">
        <h3 class="ui header">
          {{ $t('components.library.Home.header.newChannels') }}
        </h3>
        <channels-widget
          :show-modification-date="true"
          :limit="12"
          :filters="{ordering: '-creation_date', external: 'false'}"
        />
      </template>
    </section>
  </main>
</template>
