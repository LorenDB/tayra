<script setup lang="ts">
import type { Channel } from '~/types'

import { momentFormat } from '~/utils/filters'
import { useI18n } from 'vue-i18n'
import { useStore } from '~/store'
import { computed } from 'vue'

import moment from 'moment'

import PlayButton from '~/components/audio/PlayButton.vue'
import TagsList from '~/components/tags/List.vue'

interface Props {
  object: Channel
}

const props = defineProps<Props>()
const store = useStore()

const imageUrl = computed(() => props.object.artist?.cover
  ? store.getters['instance/absoluteUrl'](props.object.artist.cover.urls.medium_square_crop)
  : null
)

const urlId = computed(() => props.object.actor?.is_local
  ? props.object.actor.preferred_username
  : props.object.actor
    ? props.object.actor.full_username
    : props.object.uuid
)

const { t } = useI18n()
const updatedTitle = computed(() => {
  const date = momentFormat(new Date(props.object.artist?.modification_date ?? '1970-01-01'))
  return t('components.audio.ChannelCard.title', { date })
})

// TODO (wvffle): Use time ago
const updatedAgo = computed(() => moment(props.object.artist?.modification_date).fromNow())
</script>

<template>
  <div class="card app-card">
    <div
      v-lazy:background-image="imageUrl"
      :class="['ui', 'head-image', {'circular': object.artist?.content_category != 'podcast'}, {'padded': object.artist?.content_category === 'podcast'}, 'image', {'default-cover': !object.artist?.cover}]"
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
          {{ object.artist?.name }}
        </router-link>
      </strong>
      <div class="description">
        <span
          v-if="object.artist?.content_category === 'podcast'"
          class="meta ellipsis"
        >
          {{ $t('components.audio.ChannelCard.meta.episodes', object.artist.tracks_count) }}
        </span>
        <span v-else>
          {{ $t('components.audio.ChannelCard.meta.tracks', object.artist?.tracks_count ?? 0) }}
        </span>
        <tags-list
          label-classes="tiny"
          :truncate-size="20"
          :limit="2"
          :show-more="false"
          :tags="object.artist?.tags ?? []"
        />
      </div>
    </div>
    <div class="extra content">
      <time
        class="meta ellipsis"
        :datetime="object.artist?.modification_date"
        :title="updatedTitle"
      >
        {{ updatedAgo }}
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
