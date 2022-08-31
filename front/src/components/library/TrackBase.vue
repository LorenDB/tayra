<script setup lang="ts">
import type { Track, Artist, Library } from '~/types'

import { momentFormat } from '~/utils/filters'
import { computed, ref, watch } from 'vue'
import { useGettext } from 'vue3-gettext'
import { useRouter } from 'vue-router'
import { getDomain } from '~/utils'
import { useStore } from '~/store'

import axios from 'axios'

import TrackFavoriteIcon from '~/components/favorites/TrackFavoriteIcon.vue'
import TrackPlaylistIcon from '~/components/playlists/TrackPlaylistIcon.vue'
import EmbedWizard from '~/components/audio/EmbedWizard.vue'
import SemanticModal from '~/components/semantic/Modal.vue'
import PlayButton from '~/components/audio/PlayButton.vue'

import updateQueryString from '~/composables/updateQueryString'
import useErrorHandler from '~/composables/useErrorHandler'
import useReport from '~/composables/moderation/useReport'
import useLogger from '~/composables/useLogger'

interface Events {
  (e: 'deleted'): void
}

interface Props {
  id: number
}

const emit = defineEmits<Events>()
const props = defineProps<Props>()

const { report, getReportableObjects } = useReport()

const track = ref<Track | null>(null)
const artist = ref<Artist | null>(null)
const showEmbedModal = ref(false)
const libraries = ref([] as Library[])

const logger = useLogger()
const router = useRouter()
const store = useStore()

const domain = computed(() => getDomain(track.value?.fid ?? ''))
const publicLibraries = computed(() => libraries.value?.filter(library => library.privacy_level === 'everyone') ?? [])
const isEmbedable = computed(() => artist.value?.channel?.actor || publicLibraries.value.length)
const upload = computed(() => track.value?.uploads?.[0] ?? null)
const wikipediaUrl = computed(() => `https://en.wikipedia.org/w/index.php?search=${encodeURI(`${track.value?.title ?? ''} ${track.value?.artist?.name ?? ''}`)}`)
const discogsUrl = computed(() => `https://discogs.com/search/?type=release&title=${encodeURI(track.value?.album?.title ?? '')}&artist=${encodeURI(track.value?.artist?.name ?? '')}&title=${encodeURI(track.value?.title ?? '')}`)
const downloadUrl = computed(() => {
  const url = store.getters['instance/absoluteUrl'](upload.value?.listen_url ?? '')
  return store.state.auth.authenticated
    ? updateQueryString(url, 'token', encodeURI(store.state.auth.scopedTokens.listen ?? ''))
    : url
})

const attributedToUrl = computed(() => router.resolve({
  name: 'profile.full.overview',
  params: {
    username: track.value?.attributed_to.preferred_username,
    domain: track.value?.attributed_to.domain
  }
})?.href)

const escapeHtml = (unsafe: string) => document.createTextNode(unsafe).textContent ?? ''
const subtitle = computed(() => {
  if (track.value?.attributed_to) {
    return $pgettext(
      'Content/Track/Paragraph',
      'Uploaded by <a class="internal" href="%{ uploaderUrl }">%{ uploader }</a> on <time title="%{ date }" datetime="%{ date }">%{ prettyDate }</time>',
      {
        uploaderUrl: attributedToUrl.value,
        uploader: escapeHtml(`@${track.value.attributed_to.full_username}`),
        date: escapeHtml(track.value.creation_date),
        prettyDate: escapeHtml(momentFormat(new Date(track.value.creation_date), 'LL'))
      }
    )
  }

  return $pgettext(
    'Content/Track/Paragraph',
    'Uploaded on <time title="%{ date }" datetime="%{ date }">%{ prettyDate }</time>',
    {
      date: escapeHtml(track.value?.creation_date ?? ''),
      prettyDate: escapeHtml(momentFormat(new Date(track.value?.creation_date ?? '1970-01-01'), 'LL'))
    }
  )
})

const { $pgettext } = useGettext()
const labels = computed(() => ({
  title: $pgettext('*/*/*/Noun', 'Track'),
  download: $pgettext('Content/Track/Link/Verb', 'Download'),
  more: $pgettext('*/*/Button.Label/Noun', 'More…')
}))

const isLoading = ref(false)
const fetchData = async () => {
  isLoading.value = true
  logger.debug(`Fetching track "${props.id}"`)
  try {
    const trackResponse = await axios.get(`tracks/${props.id}/`, { params: { refresh: 'true' } })
    track.value = trackResponse.data
    const artistResponse = await axios.get(`artists/${trackResponse.data.artist.id}/`)
    artist.value = artistResponse.data
  } catch (error) {
    useErrorHandler(error as Error)
  }
  isLoading.value = false
}

watch(() => props.id, fetchData, { immediate: true })

const remove = async () => {
  isLoading.value = true
  try {
    await axios.delete(`tracks/${track.value?.id}`)
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
    <template v-if="track">
      <section
        v-title="track.title"
        :class="['ui', 'head', 'vertical', 'center', 'aligned', 'stripe', 'segment']"
      >
        <div class="ui basic padded segment">
          <div class="ui stackable grid row container">
            <div class="eight wide left aligned column">
              <h1 class="ui header">
                {{ track.title }}
                <sanitized-html
                  class="sub header"
                  :html="subtitle"
                />
              </h1>
            </div>
            <div class="eight wide right aligned column button-group">
              <play-button
                class="vibrant"
                :track="track"
              >
                <translate translate-context="*/Queue/Button.Label/Short, Verb">
                  Play
                </translate>
              </play-button>
              &nbsp;
              <track-favorite-icon
                v-if="$store.state.auth.authenticated"
                :border="true"
                :track="track"
              />
              <track-playlist-icon
                v-if="$store.state.auth.authenticated"
                class="circular"
                :border="true"
                :track="track"
              />
              <a
                v-if="upload"
                role="button"
                :aria-label="labels.download"
                :href="downloadUrl"
                target="_blank"
                class="ui basic circular icon button"
                :title="labels.download"
              >
                <i class="download icon" />
              </a>
              <semantic-modal
                v-if="isEmbedable"
                v-model:show="showEmbedModal"
              >
                <h4 class="header">
                  <translate translate-context="Popup/Track/Title">
                    Embed this track on your website
                  </translate>
                </h4>
                <div class="scrolling content">
                  <div class="description">
                    <embed-wizard
                      :id="track.id"
                      type="track"
                    />
                  </div>
                </div>
                <div class="actions">
                  <button class="ui basic deny button">
                    <translate translate-context="*/*/Button.Label/Verb">
                      Cancel
                    </translate>
                  </button>
                </div>
              </semantic-modal>
              <button
                v-dropdown="{direction: 'downward'}"
                class="ui floating dropdown circular icon basic button"
                :title="labels.more"
              >
                <i class="ellipsis vertical icon" />
                <div
                  class="menu"
                  style="right: 0; left: auto"
                >
                  <a
                    v-if="domain != $store.getters['instance/domain']"
                    :href="track.fid"
                    target="_blank"
                    class="basic item"
                  >
                    <i class="external icon" />
                    <translate
                      :translate-params="{domain: domain}"
                      translate-context="Content/*/Button.Label/Verb"
                    >View on %{ domain }</translate>
                  </a>
                  <div
                    v-if="isEmbedable"
                    role="button"
                    class="basic item"
                    @click="showEmbedModal = !showEmbedModal"
                  >
                    <i class="code icon" />
                    <translate translate-context="Content/*/Button.Label/Verb">
                      Embed
                    </translate>
                  </div>
                  <a
                    :href="wikipediaUrl"
                    target="_blank"
                    rel="noreferrer noopener"
                    class="basic item"
                  >
                    <i class="wikipedia w icon" />
                    <translate translate-context="Content/*/Button.Label/Verb">Search on Wikipedia</translate>
                  </a>
                  <a
                    v-if="discogsUrl"
                    :href="discogsUrl"
                    target="_blank"
                    rel="noreferrer noopener"
                    class="basic item"
                  >
                    <i class="external icon" />
                    <translate translate-context="Content/*/Button.Label/Verb">Search on Discogs</translate>
                  </a>
                  <router-link
                    v-if="track.is_local"
                    :to="{name: 'library.tracks.edit', params: {id: track.id }}"
                    class="basic item"
                  >
                    <i class="edit icon" />
                    <translate translate-context="Content/*/Button.Label/Verb">
                      Edit
                    </translate>
                  </router-link>
                  <dangerous-button
                    v-if="artist && $store.state.auth.authenticated && artist.channel && artist.attributed_to.full_username === $store.state.auth.fullUsername"
                    :class="['ui', {loading: isLoading}, 'item']"
                    @confirm="remove()"
                  >
                    <i class="ui trash icon" />
                    <translate translate-context="*/*/*/Verb">
                      Delete…
                    </translate>
                    <template #modal-header>
                      <p>
                        <translate translate-context="Popup/Channel/Title">
                          Delete this track?
                        </translate>
                      </p>
                    </template>
                    <template #modal-content>
                      <div>
                        <p>
                          <translate translate-context="Content/Moderation/Paragraph">
                            The track will be deleted, as well as any related files and data. This action is irreversible.
                          </translate>
                        </p>
                      </div>
                    </template>
                    <template #modal-confirm>
                      <p>
                        <translate translate-context="*/*/*/Verb">
                          Delete
                        </translate>
                      </p>
                    </template>
                  </dangerous-button>
                  <div class="divider" />
                  <div
                    v-for="obj in getReportableObjects({track})"
                    :key="obj.target.type + obj.target.id"
                    role="button"
                    class="basic item"
                    @click.stop.prevent="report(obj)"
                  >
                    <i class="share icon" /> {{ obj.label }}
                  </div>
                  <div class="divider" />
                  <router-link
                    v-if="$store.state.auth.availablePermissions['library']"
                    class="basic item"
                    :to="{name: 'manage.library.tracks.detail', params: {id: track.id}}"
                  >
                    <i class="wrench icon" />
                    <translate translate-context="Content/Moderation/Link">
                      Open in moderation interface
                    </translate>
                  </router-link>
                  <a
                    v-if="$store.state.auth.profile && $store.state.auth.profile.is_superuser"
                    class="basic item"
                    :href="$store.getters['instance/absoluteUrl'](`/api/admin/music/track/${track.id}`)"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    <i class="wrench icon" />
                    <translate translate-context="Content/Moderation/Link/Verb">View in Django's admin</translate>&nbsp;
                  </a>
                </div>
              </button>
            </div>
          </div>
        </div>
      </section>
      <router-view
        v-if="track"
        :key="$route.fullPath"
        :track="track"
        :object="track"
        object-type="track"
        @libraries-loaded="libraries = $event"
      />
    </template>
  </main>
</template>
