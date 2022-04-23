<template>
  <span>

    <modal
      v-if="isEmbedable"
      :show.sync="showEmbedModal"
    >
      <h4 class="header">
        <translate translate-context="Popup/Album/Title/Verb">Embed this album on your website</translate>
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
          <translate translate-context="*/*/Button.Label/Verb">Cancel</translate>
        </button>
      </div>
    </modal>
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
          <translate translate-context="Content/*/Button.Label/Verb">Embed</translate>
        </div>
        <a
          v-if="isAlbum && musicbrainzUrl"
          :href="musicbrainzUrl"
          target="_blank"
          rel="noreferrer noopener"
          class="basic item"
        >
          <i class="external icon" />
          <translate translate-context="Content/*/*/Clickable, Verb">View on MusicBrainz</translate>
        </a>
        <a
          v-if="!isChannel && isAlbum"
          :href="discogsUrl"
          target="_blank"
          rel="noreferrer noopener"
          class="basic item"
        >
          <i class="external icon" />
          <translate translate-context="Content/*/Button.Label/Verb">Search on Discogs</translate>
        </a>
        <router-link
          v-if="object.is_local"
          :to="{name: 'library.albums.edit', params: {id: object.id }}"
          class="basic item"
        >
          <i class="edit icon" />
          <translate translate-context="Content/*/Button.Label/Verb">Edit</translate>
        </router-link>
        <dangerous-button
          v-if="artist && $store.state.auth.authenticated && artist.channel && artist.attributed_to.full_username === $store.state.auth.fullUsername"
          :class="['ui', {loading: isLoading}, 'item']"
          @confirm="remove()"
        >
          <i class="ui trash icon" />
          <translate translate-context="*/*/*/Verb">Delete…</translate>
          <p slot="modal-header"><translate translate-context="Popup/Channel/Title">Delete this album?</translate></p>
          <div slot="modal-content">
            <p><translate translate-context="Content/Moderation/Paragraph">The album will be deleted, as well as any related files and data. This action is irreversible.</translate></p>
          </div>
          <p slot="modal-confirm"><translate translate-context="*/*/*/Verb">Delete</translate></p>
        </dangerous-button>
        <div class="divider" />
        <div
          v-for="obj in getReportableObjs({album: object, channel: artist.channel})"
          :key="obj.target.type + obj.target.id"
          role="button"
          class="basic item"
          @click.stop.prevent="$store.dispatch('moderation/report', obj.target)"
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
          <translate translate-context="Content/Moderation/Link">Open in moderation interface</translate>
        </router-link>
        <a
          v-if="$store.state.auth.profile && $store.state.auth.profile.is_superuser"
          class="basic item"
          :href="$store.getters['instance/absoluteUrl'](`/api/admin/music/album/${object.id}`)"
          target="_blank"
          rel="noopener noreferrer"
        >
          <i class="wrench icon" />
          <translate translate-context="Content/Moderation/Link/Verb">View in Django's admin</translate>&nbsp;
        </a>
      </div>
    </button>
  </span>
</template>
<script>
import EmbedWizard from '~/components/audio/EmbedWizard.vue'
import Modal from '~/components/semantic/Modal.vue'
import ReportMixin from '~/components/mixins/Report.vue'

import { getDomain } from '~/utils'

export default {
  components: {
    EmbedWizard,
    Modal
  },
  mixins: [ReportMixin],
  props: {
    isLoading: Boolean,
    artist: { type: Object, required: true },
    object: { type: Object, required: true },
    publicLibraries: { type: Array, required: true },
    isAlbum: Boolean,
    isChannel: Boolean,
    isSerie: Boolean
  },
  data () {
    return {
      showEmbedModal: false
    }
  },
  computed: {
    domain () {
      if (this.object) {
        return getDomain(this.object.fid)
      }
      return null
    },
    labels () {
      return {
        more: this.$pgettext('*/*/Button.Label/Noun', 'More…')
      }
    },
    isEmbedable () {
      return (this.isChannel && this.artist.channel.actor) || this.publicLibraries.length > 0
    },

    musicbrainzUrl () {
      if (this.object.mbid) {
        return 'https://musicbrainz.org/release/' + this.object.mbid
      }
      return null
    },
    discogsUrl () {
      return (
        'https://discogs.com/search/?type=release&title=' +
        encodeURI(this.object.title) + '&artist=' +
        encodeURI(this.object.artist.name)
      )
    }
  }
}
</script>
