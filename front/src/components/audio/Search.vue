<script setup lang="ts">
import type { Artist, Album } from '~/types'

import { useGettext } from 'vue3-gettext'
import { ref, computed, reactive, watch, onMounted } from 'vue'
import { refDebounced } from '@vueuse/core'

import axios from 'axios'
import AlbumCard from '~/components/audio/album/Card.vue'
import ArtistCard from '~/components/audio/artist/Card.vue'

import useErrorHandler from '~/composables/useErrorHandler'
import useLogger from '~/composables/useLogger'

interface Props {
  autofocus?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  autofocus: false
})

const logger = useLogger()
const { $pgettext } = useGettext()

const query = ref('')
const queryDebounced = refDebounced(query, 500)

const results = reactive({
  artists: [] as Artist[],
  albums: [] as Album[]
})

const isLoading = ref(false)
const search = async () => {
  if (queryDebounced.value.length < 1) {
    return
  }

  isLoading.value = true
  logger.debug(`Searching track matching "${queryDebounced.value}"`)

  const params = {
    query: queryDebounced.value
  }

  try {
    const response = await axios.get('search/', { params })
    results.artists = response.data.artists
    results.albums = response.data.albums
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoading.value = false
}

watch(queryDebounced, search, { immediate: true })

const searchInput = ref()
onMounted(() => {
  if (props.autofocus) {
    searchInput.value.focus()
  }
})

const labels = computed(() => ({
  searchPlaceholder: $pgettext('*/Search/Input.Placeholder', 'Artist, album, track…')
}))

</script>

<template>
  <div>
    <h2>
      <translate translate-context="Content/Search/Title">
        Search for some music
      </translate>
    </h2>
    <div :class="['ui', {'loading': isLoading }, 'search']">
      <div class="ui icon big input">
        <i class="search icon" />
        <input
          ref="searchInput"
          v-model.trim="query"
          class="prompt"
          :placeholder="labels.searchPlaceholder"
          type="text"
        >
      </div>
    </div>
    <template v-if="query.length > 0">
      <h3 class="ui title">
        <translate translate-context="*/*/*/Noun">
          Artists
        </translate>
      </h3>
      <div v-if="results.artists.length > 0">
        <div class="ui cards">
          <artist-card
            v-for="artist in results.artists"
            :key="artist.id"
            :artist="artist"
          />
        </div>
      </div>
      <p v-else>
        <translate translate-context="Content/Search/Paragraph">
          No artist matched your query
        </translate>
      </p>
    </template>
    <template v-if="query.length > 0">
      <h3 class="ui title">
        <translate translate-context="*/*/*">
          Albums
        </translate>
      </h3>
      <div
        v-if="results.albums.length > 0"
        class="ui stackable three column grid"
      >
        <div
          v-for="album in results.albums"
          :key="album.id"
          class="column"
        >
          <album-card
            class="fluid"
            :album="album"
          />
        </div>
      </div>
      <p v-else>
        <translate translate-context="Content/Search/Paragraph">
          No album matched your query
        </translate>
      </p>
    </template>
  </div>
</template>
