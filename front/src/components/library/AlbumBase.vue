<script setup lang="ts">
import type { Track, Album, Artist, Library } from '~/types'

import { momentFormat } from '~/utils/filters'
import { useGettext } from 'vue3-gettext'
import { computed, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import { sum } from 'lodash-es'

import axios from 'axios'

import ArtistLabel from '~/components/audio/ArtistLabel.vue'
import PlayButton from '~/components/audio/PlayButton.vue'
import TagsList from '~/components/tags/List.vue'
import AlbumDropdown from './AlbumDropdown.vue'

import useErrorHandler from '~/composables/useErrorHandler'

interface Events {
  (e: 'deleted'): void
}

interface Props {
  id: string
}

const emit = defineEmits<Events>()
const props = defineProps<Props>()

const object = ref<Album | null>(null)
const artist = ref<Artist | null>(null)
const discs = ref([] as Track[][])
const libraries = ref([] as Library[])
const page = ref(1)
const paginateBy = ref(50)

const totalTracks = computed(() => object.value?.tracks_count ?? 0)
const isChannel = computed(() => !!object.value?.artist.channel)
const isAlbum = computed(() => object.value?.artist.content_category === 'music')
const isSerie = computed(() => object.value?.artist.content_category === 'podcast')
const totalDuration = computed(() => sum((object.value?.tracks ?? []).map(track => track.uploads[0]?.duration ?? 0)))
const publicLibraries = computed(() => libraries.value?.filter(library => library.privacy_level === 'everyone') ?? [])

const { $pgettext } = useGettext()
const labels = computed(() => ({
  title: $pgettext('*/*/*', 'Album')
}))

const isLoading = ref(false)
const fetchData = async () => {
  isLoading.value = true

  const albumResponse = await axios.get(`albums/${props.id}/`, { params: { refresh: 'true' } })
  const [artistResponse, tracksResponse] = await Promise.all([
    axios.get(`artists/${albumResponse.data.artist.id}/`),
    axios.get('tracks/', {
      params: {
        ordering: 'disc_number,position',
        album: props.id,
        page_size: paginateBy.value,
        page: page.value,
        include_channels: true
      }
    })
  ])

  artist.value = artistResponse.data
  if (artist.value?.channel) {
    artist.value.channel.artist = artist.value
  }

  object.value = albumResponse.data
  if (object.value) {
    object.value.tracks = tracksResponse.data.results
    discs.value = object.value.tracks.reduce((acc: Track[][], track: Track) => {
      const discNumber = track.disc_number - (object.value?.tracks[0]?.disc_number ?? 1)
      acc[discNumber] ??= []
      acc[discNumber].push(track)
      return acc
    }, [])
  }

  isLoading.value = false
}

watch(() => props.id, fetchData, { immediate: true })
watch(page, fetchData)

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
                    <translate
                      v-if="isSerie"
                      translate-context="Content/Channel/Paragraph"
                      translate-plural="%{ count } episodes"
                      :translate-n="totalTracks"
                      :translate-params="{count: totalTracks}"
                    >
                      %{ count } episode
                    </translate>
                    <translate
                      v-else
                      translate-context="*/*/*"
                      :translate-params="{count: totalTracks}"
                      :translate-n="totalTracks"
                      translate-plural="%{ count } tracks"
                    >
                      %{ count } track
                    </translate>
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
              <span v-if="object.release_date">{{ momentFormat(new Date(object.release_date ?? '1970-01-01'), 'Y') }} · </span>
              <template v-if="totalTracks > 0">
                <translate
                  v-if="isSerie"
                  translate-context="Content/Channel/Paragraph"
                  translate-plural="%{ count } episodes"
                  :translate-n="totalTracks"
                  :translate-params="{count: totalTracks}"
                >
                  %{ count } episode
                </translate>
                <translate
                  v-else
                  translate-context="*/*/*"
                  :translate-params="{count: totalTracks}"
                  :translate-n="totalTracks"
                  translate-plural="%{ count } tracks"
                >
                  %{ count } track
                </translate> ·
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
                  <translate translate-context="Content/*/Button.Label/Verb">
                    Add a description…
                  </translate>
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
                <translate translate-context="Content/*/Button.Label/Verb">
                  Add a description…
                </translate>
              </router-link>
            </template>
          </div>
          <div class="nine wide column">
            <router-view
              v-if="object"
              :key="$route.fullPath"
              :paginate-by="paginateBy"
              :page="page"
              :total-tracks="totalTracks"
              :is-serie="isSerie"
              :artist="artist"
              :discs="discs"
              :object="object"
              object-type="album"
              @libraries-loaded="libraries = $event"
              @page-changed="page = $event"
            />
          </div>
        </div>
      </section>
    </template>
  </main>
</template>
