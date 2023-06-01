<script setup lang="ts">
import type { Album, Artist, Library } from '~/types'

import { computed, ref } from 'vue'
import { useI18n } from 'vue-i18n'

import { getDomain } from '~/utils'

import useReport from '~/composables/moderation/useReport'

import EmbedWizard from '~/components/audio/EmbedWizard.vue'
import SemanticModal from '~/components/semantic/Modal.vue'

interface Events {
  (e: 'remove'): void
}

interface Props {
  isLoading: boolean
  artist: Artist | null
  object: Album
  publicLibraries: Library[]
  isAlbum: boolean
  isChannel: boolean
  isSerie: boolean
}

const emit = defineEmits<Events>()
const props = defineProps<Props>()
const { report, getReportableObjects } = useReport()

const showEmbedModal = ref(false)

const domain = computed(() => getDomain(props.object.fid))

const { t } = useI18n()
const labels = computed(() => ({
  more: t('components.library.AlbumDropdown.button.more')
}))

const isEmbedable = computed(() => (props.isChannel && props.artist?.channel?.actor) || props.publicLibraries.length)
const musicbrainzUrl = computed(() => props.object?.mbid ? `https://musicbrainz.org/release/${props.object.mbid}` : null)
const discogsUrl = computed(() => `https://discogs.com/search/?type=release&title=${encodeURI(props.object?.title)}&artist=${encodeURI(props.object?.artist.name)}`)

const remove = () => emit('remove')
</script>

<template>
  <span>

    <semantic-modal
      v-if="isEmbedable"
      v-model:show="showEmbedModal"
    >
      <h4 class="header">
        {{ $t('components.library.AlbumDropdown.modal.embed.header') }}
      </h4>
      <div class="scrolling content">
        <div class="description">
          <embed-wizard
            :id="object.id"
            type="album"
          />

        </div>
      </div>
      <div class="actions">
        <button class="ui basic deny button">
          {{ $t('components.library.AlbumDropdown.button.cancel') }}
        </button>
      </div>
    </semantic-modal>
    <button
      v-dropdown="{direction: 'downward'}"
      class="ui floating dropdown circular icon basic button"
      :title="labels.more"
    >
      <i class="ellipsis vertical icon" />
      <div class="menu">
        <a
          v-if="domain != $store.getters['instance/domain']"
          :href="object.fid"
          target="_blank"
          class="basic item"
        >
          <i class="external icon" />
          {{ $t('components.library.AlbumDropdown.link.domain') }}
        </a>

        <div
          v-if="isEmbedable"
          role="button"
          class="basic item"
          @click="showEmbedModal = !showEmbedModal"
        >
          <i class="code icon" />
          {{ $t('components.library.AlbumDropdown.button.embed') }}
        </div>
        <a
          v-if="isAlbum && musicbrainzUrl"
          :href="musicbrainzUrl"
          target="_blank"
          rel="noreferrer noopener"
          class="basic item"
        >
          <i class="external icon" />
          {{ $t('components.library.AlbumDropdown.link.musicbrainz') }}
        </a>
        <a
          v-if="!isChannel && isAlbum"
          :href="discogsUrl"
          target="_blank"
          rel="noreferrer noopener"
          class="basic item"
        >
          <i class="external icon" />
          {{ $t('components.library.AlbumDropdown.link.discogs') }}
        </a>
        <router-link
          v-if="object.is_local"
          :to="{name: 'library.albums.edit', params: {id: object.id }}"
          class="basic item"
        >
          <i class="edit icon" />
          {{ $t('components.library.AlbumDropdown.button.edit') }}
        </router-link>
        <dangerous-button
          v-if="artist && $store.state.auth.authenticated && artist.channel && artist.attributed_to.full_username === $store.state.auth.fullUsername"
          :class="['ui', {loading: isLoading}, 'item']"
          @confirm="remove()"
        >
          <i class="ui trash icon" />
          {{ $t('components.library.AlbumDropdown.button.delete') }}
          <template #modal-header>
            <p>
              {{ $t('components.library.AlbumDropdown.modal.delete.header') }}
            </p>
          </template>
          <template #modal-content>
            <div>
              <p>
                {{ $t('components.library.AlbumDropdown.modal.delete.content.warning') }}
              </p>
            </div>
          </template>
          <template #modal-confirm>
            <p>
              {{ $t('components.library.AlbumDropdown.button.delete') }}
            </p>
          </template>
        </dangerous-button>
        <div class="divider" />
        <div
          v-for="obj in getReportableObjects({album: object, channel: artist?.channel})"
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
          :to="{name: 'manage.library.albums.detail', params: {id: object.id}}"
        >
          <i class="wrench icon" />
          {{ $t('components.library.AlbumDropdown.link.moderation') }}
        </router-link>
        <a
          v-if="$store.state.auth.profile && $store.state.auth.profile?.is_superuser"
          class="basic item"
          :href="$store.getters['instance/absoluteUrl'](`/api/admin/music/album/${object.id}`)"
          target="_blank"
          rel="noopener noreferrer"
        >
          <i class="wrench icon" />
          {{ $t('components.library.AlbumDropdown.link.django') }}
        </a>
      </div>
    </button>
  </span>
</template>
