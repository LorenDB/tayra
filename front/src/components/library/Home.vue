<script setup lang="ts">
import { useGettext } from 'vue3-gettext'
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

const { $pgettext } = useGettext()
const labels = computed(() => ({
  title: $pgettext('Head/Home/Title', 'Library')
}))

const isLoading = ref(false)
const fetchData = async () => {
  isLoading.value = true
  logger.time('Loading latest artists')

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
  logger.timeEnd('Loading latest artists')
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
              <translate translate-context="Content/Home/Title">
                Recently listened
              </translate>
            </template>
          </track-widget>
        </div>
        <div class="column">
          <track-widget
            :url="'favorites/tracks/'"
            :filters="{scope: scope, ordering: '-creation_date'}"
          >
            <template #title>
              <translate translate-context="Content/Home/Title">
                Recently favorited
              </translate>
            </template>
          </track-widget>
        </div>
        <div class="column">
          <playlist-widget
            :url="'playlists/'"
            :filters="{scope: scope, playable: true, ordering: '-modification_date'}"
          >
            <template #title>
              <translate translate-context="*/*/*">
                Playlists
              </translate>
            </template>
          </playlist-widget>
        </div>
      </div>
      <div class="ui section hidden divider" />
      <div class="ui stackable one column grid">
        <div class="column">
          <album-widget :filters="{scope: scope, playable: true, ordering: '-creation_date'}">
            <template #title>
              <translate translate-context="Content/Home/Title">
                Recently added
              </translate>
            </template>
          </album-widget>
        </div>
      </div>
      <template v-if="scope === 'all'">
        <h3 class="ui header">
          <translate translate-context="*/*/*">
            New channels
          </translate>
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
