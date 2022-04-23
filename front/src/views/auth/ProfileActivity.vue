<template>
  <section>
    <div>
      <radio-button
        v-if="recentActivity > 0"
        class="right floated"
        type="account"
        :object-id="{username: object.preferred_username, fullUsername: object.full_username}"
        :client-only="true"
      />
      <h2 class="ui header">
        <translate translate-context="Content/Home/Title">
          Recently listened
        </translate>
      </h2>
      <div class="ui divider" />
      <track-widget
        :url="'history/listenings/'"
        :filters="{scope: `actor:${object.full_username}`, ordering: '-creation_date'}"
        @count="recentActivity = $event"
      />
    </div>
    <div class="ui hidden divider" />
    <div>
      <h2 class="ui header">
        <translate translate-context="Content/Home/Title">
          Recently favorited
        </translate>
      </h2>
      <div class="ui divider" />
      <track-widget
        :url="'favorites/tracks/'"
        :filters="{scope: `actor:${object.full_username}`, ordering: '-creation_date'}"
      />
    </div>
    <div class="ui hidden divider" />
    <div>
      <h2 class="ui header">
        <translate translate-context="*/*/*">
          Playlists
        </translate>
      </h2>
      <div class="ui divider" />
      <playlist-widget
        :url="'playlists/'"
        :filters="{scope: `actor:${object.full_username}`, playable: true, ordering: '-modification_date'}"
      />
    </div>
  </section>
</template>

<script>
import TrackWidget from '~/components/audio/track/Widget.vue'
import PlaylistWidget from '~/components/playlists/Widget.vue'
import RadioButton from '~/components/radios/Button.vue'

export default {
  components: { TrackWidget, PlaylistWidget, RadioButton },
  props: { object: { type: Object, required: true } },
  data () {
    return {
      recentActivity: 0
    }
  }
}
</script>
