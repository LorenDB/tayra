<template>
  <section>
    <album-widget
      :key="String(object.uploads_count)"
      :header="false"
      :search="true"
      :controls="false"
      :filters="{playable: true, ordering: '-creation_date', library: object.uuid}"
    >
      <empty-state slot="empty-state">
        <p>
          <translate
            v-if="isOwner"
            key="1"
            translate-context="*/*/*"
          >
            This library is empty, you should upload something in it!
          </translate>
          <translate
            v-else
            key="2"
            translate-context="*/*/*"
          >
            You may need to follow this library to see its content.
          </translate>
        </p>
      </empty-state>
    </album-widget>
  </section>
</template>

<script>
import AlbumWidget from '~/components/audio/album/Widget.vue'

export default {
  components: {
    AlbumWidget
  },
  props: {
    object: { type: Object, required: true },
    isOwner: { type: Boolean, required: true }
  }
}
</script>
