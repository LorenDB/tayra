<template>
  <div class="card app-card">
    <div
      v-lazy:background-image="imageUrl"
      :class="['ui', 'head-image', {'circular': object.artist.content_category != 'podcast'}, {'padded': object.artist.content_category === 'podcast'}, 'image', {'default-cover': !object.artist.cover}]"
      @click="$router.push({name: 'channels.detail', params: {id: urlId}})"
    >
      <play-button
        :icon-only="true"
        :is-playable="true"
        :button-classes="['ui', 'circular', 'large', 'vibrant', 'icon', 'button']"
        :artist="object.artist"
      />
    </div>
    <div class="content">
      <strong>
        <router-link
          class="discrete link"
          :to="{name: 'channels.detail', params: {id: urlId}}"
        >
          {{ object.artist.name }}
        </router-link>
      </strong>
      <div class="description">
        <translate
          v-if="object.artist.content_category === 'podcast'"
          key="1"
          class="meta ellipsis"
          translate-context="Content/Channel/Paragraph"
          translate-plural="%{ count } episodes"
          :translate-n="object.artist.tracks_count"
          :translate-params="{count: object.artist.tracks_count}"
        >
          %{ count } episode
        </translate>
        <translate
          v-else
          key="2"
          translate-context="*/*/*"
          :translate-params="{count: object.artist.tracks_count}"
          :translate-n="object.artist.tracks_count"
          translate-plural="%{ count } tracks"
        >
          %{ count } track
        </translate>
        <tags-list
          label-classes="tiny"
          :truncate-size="20"
          :limit="2"
          :show-more="false"
          :tags="object.artist.tags"
        />
      </div>
    </div>
    <div class="extra content">
      <time
        v-translate
        class="meta ellipsis"
        :datetime="object.artist.modification_date"
        :title="updatedTitle"
      >
        %{ updatedAgo }
      </time>
      <play-button
        class="right floated basic icon"
        :dropdown-only="true"
        :is-playable="true"
        :dropdown-icon-classes="['ellipsis', 'horizontal', 'large really discrete']"
        :artist="object.artist"
        :channel="object"
        :account="object.attributed_to"
      />
    </div>
  </div>
</template>

<script>
import PlayButton from '~/components/audio/PlayButton.vue'
import TagsList from '~/components/tags/List.vue'

import { momentFormat } from '~/utils/filters'
import moment from 'moment'

export default {
  components: {
    PlayButton,
    TagsList
  },
  props: {
    object: { type: Object, required: true }
  },
  computed: {
    imageUrl () {
      if (this.object.artist.cover) {
        return this.$store.getters['instance/absoluteUrl'](this.object.artist.cover.urls.medium_square_crop)
      }
      return null
    },
    urlId () {
      if (this.object.actor && this.object.actor.is_local) {
        return this.object.actor.preferred_username
      } else if (this.object.actor) {
        return this.object.actor.full_username
      } else {
        return this.object.uuid
      }
    },
    updatedTitle () {
      const d = momentFormat(this.object.artist.modification_date)
      const message = this.$pgettext('*/*/*', 'Updated on %{ date }')
      return this.$gettextInterpolate(message, { date: d })
    },
    updatedAgo () {
      return moment(this.object.artist.modification_date).fromNow()
    }
  }
}
</script>
