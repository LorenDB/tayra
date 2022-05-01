<template>
  <section>
    <track-table
      :key="object.uploads_count"
      :display-actions="false"
      :search="true"
      :filters="{playable: true, library: object.uuid, ordering: '-creation_date'}"
    >
      <template #empty-state>
        <empty-state>
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
      </template>
    </track-table>
  </section>
</template>

<script>
import TrackTable from '~/components/audio/track/Table.vue'

export default {
  components: {
    TrackTable
  },
  props: {
    object: { type: [Object, String], required: true },
    isOwner: { type: Boolean, required: true }
  }
}
</script>
