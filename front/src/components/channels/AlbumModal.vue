<template>
  <modal
    class="small"
    :show.sync="show"
  >
    <h4 class="header">
      <translate
        v-if="channel.content_category === 'podcasts'"
        key="1"
        translate-context="Popup/Channels/Title/Verb"
      >
        New series
      </translate>
      <translate
        v-else
        key="2"
        translate-context="Popup/Channels/Title"
      >
        New album
      </translate>
    </h4>
    <div class="scrolling content">
      <channel-album-form
        ref="albumForm"
        :channel="channel"
        @loading="isLoading = $event"
        @submittable="submittable = $event"
        @created="$emit('created', $event)"
      />
    </div>
    <div class="actions">
      <button class="ui basic cancel button">
        <translate translate-context="*/*/Button.Label/Verb">
          Cancel
        </translate>
      </button>
      <button
        :class="['ui', 'primary', {loading: isLoading}, 'button']"
        :disabled="!submittable"
        @click.stop.prevent="$refs.albumForm.submit()"
      >
        <translate translate-context="*/*/Button.Label">
          Create
        </translate>
      </button>
    </div>
  </modal>
</template>

<script>
import Modal from '~/components/semantic/Modal.vue'
import ChannelAlbumForm from '~/components/channels/AlbumForm.vue'

export default {
  components: {
    Modal,
    ChannelAlbumForm
  },
  props: { channel: { type: Object, required: true } },
  data () {
    return {
      isLoading: false,
      submittable: false,
      show: false
    }
  },
  watch: {
    show () {
      this.isLoading = false
      this.submittable = false
    }
  }
}
</script>
