<script setup lang="ts">
import type { Track, Album, Artist, Library } from '~/types'

import { momentFormat } from '~/utils/filters'
import { computed, reactive, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import { sum } from 'lodash-es'

import axios from 'axios'

import ArtistLabel from '~/components/audio/ArtistLabel.vue'
import PlayButton from '~/components/audio/PlayButton.vue'
import TagsList from '~/components/tags/List.vue'
import AlbumDropdown from './AlbumDropdown.vue'

import useErrorHandler from '~/composables/useErrorHandler'
import useLogger from '~/composables/useLogger'

interface Events {
  (e: 'deleted'): void
}

interface Props {
  id: number
}

const emit = defineEmits<Events>()
const props = defineProps<Props>()

const object = ref<Album | null>(null)
const artist = ref<Artist | null>(null)
const libraries = ref([] as Library[])
const paginateBy = ref(50)

const totalTracks = computed(() => object.value?.tracks_count ?? 0)
const isChannel = computed(() => !!object.value?.artist.channel)
const isAlbum = computed(() => object.value?.artist.content_category === 'music')
const isSerie = computed(() => object.value?.artist.content_category === 'podcast')
const totalDuration = computed(() => sum((object.value?.tracks ?? []).map(track => track.uploads[0]?.duration ?? 0)))
const publicLibraries = computed(() => libraries.value?.filter(library => library.privacy_level === 'everyone') ?? [])

const logger = useLogger()

const { t } = useI18n()
const labels = computed(() => ({
  title: t('components.library.AlbumBase.title')
}))

const isLoading = ref(false)
const fetchData = async () => {
  isLoading.value = true

  const albumResponse = await axios.get(`albums/${props.id}/`, { params: { refresh: 'true' } })
  const artistResponse = await axios.get(`artists/${albumResponse.data.artist.id}/`)

  artist.value = artistResponse.data
  if (artist.value?.channel) {
    artist.value.channel.artist = artist.value
  }

  object.value = albumResponse.data
  if (object.value) {
    object.value.tracks = []
  }

  fetchTracks()
  isLoading.value = false
}

const tracks = reactive([] as Track[])
watch(tracks, (tracks) => {
  if (object.value) {
    object.value.tracks = tracks
  }
})

const isLoadingTracks = ref(false)
const fetchTracks = async () => {
  if (isLoadingTracks.value) return
  isLoadingTracks.value = true
  tracks.length = 0
  let url = 'tracks/'
  try {
    while (url) {
      const response = await axios.get(url, {
        params: {
          ordering: 'disc_number,position',
          album: props.id,
          page_size: paginateBy.value,
          include_channels: true
        }
      })

      url = response.data.next
      tracks.push(...response.data.results)
    }
  } catch (error) {
    logger.error(error)
  } finally {
    isLoadingTracks.value = false
  }
}

watch(() => props.id, fetchData, { immediate: true })

const router = useRouter()
const remove = async () => {
  isLoading.value = true
  try {
    await axios.delete(`albums/${object.value?.id}`)
    emit('deleted')
    router.push({ name: 'library.artists.detail', params: { id: artist.value?.id } })
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoading.value = false
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
    <template v-if="object">
      <section class="ui vertical stripe segment channel-serie">
        <div class="ui stackable grid container">
          <div class="ui seven wide column">
            <div
              v-if="isSerie"
              class="padded basic segment"
            >
              <div
                v-if="isSerie"
                class="ui two column grid"
              >
                <div class="column">
                  <div class="large two-images">
                    <img
                      v-if="object.cover && object.cover.urls.original"
                      v-lazy="$store.getters['instance/absoluteUrl'](object.cover.urls.medium_square_crop)"
                      alt=""
                      class="channel-image"
                    >
                    <img
                      v-else
                      alt=""
                      class="channel-image"
                      src="../../assets/audio/default-cover.png"
                    >
                    <img
                      v-if="object.cover && object.cover.urls.original"
                      v-lazy="$store.getters['instance/absoluteUrl'](object.cover.urls.medium_square_crop)"
                      alt=""
                      class="channel-image"
                    >
                    <img
                      v-else
                      alt=""
                      class="channel-image"
                      src="../../assets/audio/default-cover.png"
                    >
                  </div>
                </div>
                <div class="ui column right aligned">
                  <tags-list
                    v-if="object.tags && object.tags.length > 0"
                    :tags="object.tags"
                  />
                  <div class="ui small hidden divider" />
                  <human-duration
                    v-if="totalDuration > 0"
                    :duration="totalDuration"
                  />
                  <template v-if="totalTracks > 0">
                    <div class="ui hidden very small divider" />
                    <span v-if="isSerie">
                      {{ $t('components.library.AlbumBase.meta.episodes', totalTracks) }}
                    </span>
                    <span v-else>
                      {{ $t('components.library.AlbumBase.meta.tracks', totalTracks) }}
                    </span>
                  </template>
                  <div class="ui small hidden divider" />
                  <play-button
                    class="vibrant"
                    :tracks="object.tracks"
                    :is-playable="object.is_playable"
                  />
                  <div class="ui hidden horizontal divider" />
                  <album-dropdown
                    :object="object"
                    :public-libraries="publicLibraries"
                    :is-loading="isLoading"
                    :is-album="isAlbum"
                    :is-serie="isSerie"
                    :is-channel="isChannel"
                    :artist="artist"
                    @remove="remove"
                  />
                </div>
              </div>
              <div class="ui small hidden divider" />
              <header>
                <h2
                  class="ui header"
                  :title="object.title"
                >
                  {{ object.title }}
                </h2>
                <artist-label
                  v-if="artist"
                  :artist="artist"
                />
              </header>
            </div>
            <div
              v-else
              class="ui center aligned text padded basic segment"
            >
              <img
                v-if="object.cover && object.cover.urls.original"
                v-lazy="$store.getters['instance/absoluteUrl'](object.cover.urls.medium_square_crop)"
                alt=""
                class="channel-image"
              >
              <img
                v-else
                alt=""
                class="channel-image"
                src="../../assets/audio/default-cover.png"
              >
              <div class="ui hidden divider" />
              <header>
                <h2
                  class="ui header"
                  :title="object.title"
                >
                  {{ object.title }}
                </h2>
                <artist-label
                  v-if="artist"
                  :artist="artist"
                  class="rounded"
                />
              </header>
              <div
                v-if="object.release_date || (totalTracks > 0)"
                class="ui small hidden divider"
              />
              <template v-if="object.release_date">
                {{ momentFormat(new Date(object.release_date ?? '1970-01-01'), 'Y') }}
                <span class="middle middledot symbol" />
              </template>
              <template v-if="totalTracks > 0">
                <span v-if="isSerie">
                  {{ $t('components.library.AlbumBase.meta.episodes', totalTracks) }}
                </span>
                <span v-else>
                  {{ $t('components.library.AlbumBase.meta.tracks', totalTracks) }}
                </span>
                <span class="middle middledot symbol" />
              </template>
              <human-duration
                v-if="totalDuration > 0"
                :duration="totalDuration"
              />
              <div class="ui small hidden divider" />
              <play-button
                class="vibrant"
                :album="object"
                :is-playable="object.is_playable"
              />
              <div class="ui horizontal hidden divider" />
              <album-dropdown
                :object="object"
                :public-libraries="publicLibraries"
                :is-loading="isLoading"
                :is-album="isAlbum"
                :is-serie="isSerie"
                :is-channel="isChannel"
                :artist="artist"
                @remove="remove"
              />
              <div v-if="(object.tags && object.tags.length > 0) || object.description || $store.state.auth.authenticated && object.is_local">
                <div class="ui small hidden divider" />
                <div class="ui divider" />
                <div class="ui small hidden divider" />
                <template v-if="object.tags && object.tags.length > 0">
                  <tags-list :tags="object.tags" />
                  <div class="ui small hidden divider" />
                </template>
                <rendered-description
                  v-if="object.description"
                  :content="object.description"
                  :can-update="false"
                />
                <router-link
                  v-else-if="$store.state.auth.authenticated && object.is_local"
                  :to="{name: 'library.albums.edit', params: {id: object.id }}"
                >
                  <i class="pencil icon" />
                  {{ $t('components.library.AlbumBase.link.addDescription') }}
                </router-link>
              </div>
            </div>
            <template v-if="isSerie">
              <div class="ui hidden divider" />
              <rendered-description
                v-if="object.description"
                :content="object.description"
                :can-update="false"
              />
              <router-link
                v-else-if="$store.state.auth.authenticated && object.is_local"
                :to="{name: 'library.albums.edit', params: {id: object.id }}"
              >
                <i class="pencil icon" />
                {{ $t('components.library.AlbumBase.link.addDescription') }}
              </router-link>
            </template>
          </div>
          <div class="nine wide column">
            <router-view
              v-if="object"
              :key="$route.fullPath"
              :paginate-by="paginateBy"
              :total-tracks="totalTracks"
              :is-serie="isSerie"
              :artist="artist"
              :object="object"
              :is-loading-tracks="isLoadingTracks"
              object-type="album"
              @libraries-loaded="libraries = $event"
            />
          </div>
        </div>
      </section>
    </template>
  </main>
</template>
