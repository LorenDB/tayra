<script setup lang="ts">
import type { Track, Listening } from '~/types'
import useWebSocketHandler from '~/composables/useWebSocketHandler'

// TODO (wvffle): Fix websocket update (#1534)
import { clone } from 'lodash-es'
import axios from 'axios'
import PlayButton from '~/components/audio/PlayButton.vue'
import TagsList from '~/components/tags/List.vue'
import { ref, reactive, watch } from 'vue'

interface Props {
  filters: Record<string, string>
  url: string
  isActivity?: boolean
  showCount?: boolean
  limit?: number
  itemClasses?: string
  websocketHandlers?: string[]
}

const props = withDefaults(defineProps<Props>(), {
  isActivity: true,
  showCount: false,
  limit: 5,
  itemClasses: '',
  websocketHandlers: () => []
})

const objects = reactive([] as Listening[])
const count = ref(0)
const nextPage = ref<string | null>(null)

const isLoading = ref(false)
const fetchData = async (url = props.url) => {
  isLoading.value = true

  const params = {
    ...clone(props.filters),
    page_size: props.limit
  }

  try {
    const response = await axios.get(url, { params })
    nextPage.value = response.data.next
    count.value = response.data.count

    const newObjects = !props.isActivity
      ? response.data.results.map((track: Track) => ({ track }))
      : response.data.results

    objects.push(...newObjects)
  } catch (error) {
    // TODO (wvffle): Handle error
  }

  isLoading.value = false
}

fetchData()

const emit = defineEmits(['count'])
watch(count, (to) => emit('count', to))

watch(() => props.websocketHandlers.includes('Listen'), (to) => {
  useWebSocketHandler('Listen', (event) => {
    // TODO (wvffle): Add reactivity to recently listened / favorited / added (#1316, #1534)
    // count.value += 1

    // objects.unshift(event as Listening)
    // objects.pop()
  })
})
</script>

<template>
  <div class="component-track-widget">
    <h3 v-if="!!$slots.title">
      <slot name="title" />
      <span
        v-if="showCount"
        class="ui tiny circular label"
      >{{ count }}</span>
    </h3>
    <div
      v-if="count > 0"
      class="ui divided unstackable items"
    >
      <div
        v-for="object in objects"
        :key="object.id"
        :class="['item', itemClasses]"
      >
        <div class="ui tiny image">
          <img
            v-if="object.track.album && object.track.album.cover"
            v-lazy="$store.getters['instance/absoluteUrl'](object.track.album.cover.urls.medium_square_crop)"
            alt=""
          >
          <img
            v-else-if="object.track.cover"
            v-lazy="$store.getters['instance/absoluteUrl'](object.track.cover.urls.medium_square_crop)"
            alt=""
          >
          <img
            v-else-if="object.track.artist?.cover"
            v-lazy="$store.getters['instance/absoluteUrl'](object.track.artist.cover.urls.medium_square_crop)"
            alt=""
          >
          <img
            v-else
            alt=""
            src="../../../assets/audio/default-cover.png"
          >
          <play-button
            class="play-overlay"
            :icon-only="true"
            :button-classes="['ui', 'circular', 'tiny', 'vibrant', 'icon', 'button']"
            :track="object.track"
          />
        </div>
        <div class="middle aligned content">
          <div class="ui unstackable grid">
            <div class="thirteen wide stretched column">
              <div class="ellipsis">
                <router-link :to="{name: 'library.tracks.detail', params: {id: object.track.id}}">
                  {{ object.track.title }}
                </router-link>
              </div>
              <div
                v-if="object.track.artist"
                class="meta ellipsis"
              >
                <span>
                  <router-link
                    class="discrete link"
                    :to="{name: 'library.artists.detail', params: {id: object.track.artist.id}}"
                  >
                    {{ object.track.artist.name }}
                  </router-link>
                </span>
              </div>
              <tags-list
                label-classes="tiny"
                :truncate-size="20"
                :limit="2"
                :show-more="false"
                :tags="object.track.tags"
              />

              <div
                v-if="isActivity"
                class="extra"
              >
                <router-link
                  class="left floated"
                  :to="{name: 'profile.overview', params: {username: object.user.username}}"
                >
                  @{{ object.user.username }}
                </router-link>
                <span class="right floated"><human-date :date="object.creation_date" /></span>
              </div>
            </div>
            <div class="one wide stretched column">
              <play-button
                class="basic icon"
                :account="object.actor"
                :dropdown-only="true"
                :dropdown-icon-classes="['ellipsis', 'vertical', 'large really discrete']"
                :track="object.track"
              />
            </div>
          </div>
        </div>
      </div>
      <div
        v-if="isLoading"
        class="ui inverted active dimmer"
      >
        <div class="ui loader" />
      </div>
    </div>
    <div
      v-else
      class="ui placeholder segment"
    >
      <div class="ui icon header">
        <i class="music icon" />
        <translate translate-context="Content/Home/Placeholder">
          Nothing found
        </translate>
      </div>
      <div
        v-if="isLoading"
        class="ui inverted active dimmer"
      >
        <div class="ui loader" />
      </div>
    </div>
    <template v-if="nextPage">
      <div class="ui hidden divider" />
      <button
        :class="['ui', 'basic', 'button']"
        @click="fetchData(nextPage as string)"
      >
        <translate translate-context="*/*/Button,Label">
          Show more
        </translate>
      </button>
    </template>
  </div>
</template>
