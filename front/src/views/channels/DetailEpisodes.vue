<template>
  <section>
    <channel-entries
      :default-cover="object.artist.cover"
      :is-podcast="object.artist.content_category === 'podcast'"
      :limit="25"
      :filters="{channel: object.uuid, ordering: 'creation_date'}"
    />
  </section>
</template>

<script>
import ChannelEntries from '~/components/audio/ChannelEntries.vue'

export default {
  components: {
    ChannelEntries
  },
  props: { object: { type: Object, required: true } }
}
</script>
