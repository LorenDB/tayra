<script setup lang="ts">
import type { Channel } from '~/types'

import { onBeforeRouteUpdate, useRoute, useRouter } from 'vue-router'
import { computed, ref, reactive, watch, watchEffect } from 'vue'
import { useI18n } from 'vue-i18n'
import { useStore } from '~/store'

import axios from 'axios'

import SubscribeButton from '~/components/channels/SubscribeButton.vue'
import ChannelForm from '~/components/audio/ChannelForm.vue'
import EmbedWizard from '~/components/audio/EmbedWizard.vue'
import SemanticModal from '~/components/semantic/Modal.vue'
import PlayButton from '~/components/audio/PlayButton.vue'
import TagsList from '~/components/tags/List.vue'

import useErrorHandler from '~/composables/useErrorHandler'
import useReport from '~/composables/moderation/useReport'

interface Events {
  (e: 'deleted'): void
}

interface Props {
  id: number
}

const emit = defineEmits<Events>()
const props = defineProps<Props>()
const { report, getReportableObjects } = useReport()
const store = useStore()

const object = ref<Channel | null>(null)
const editForm = ref()
const totalTracks = ref(0)

const edit = reactive({
  submittable: false,
  loading: false
})

const showEmbedModal = ref(false)
const showEditModal = ref(false)
const showSubscribeModal = ref(false)

const isOwner = computed(() => store.state.auth.authenticated && object.value?.attributed_to.full_username === store.state.auth.fullUsername)
const isPodcast = computed(() => object.value?.artist?.content_category === 'podcast')
const isPlayable = computed(() => totalTracks.value > 0)
const externalDomain = computed(() => {
  const parser = document.createElement('a')
  parser.href = object.value?.url ?? object.value?.rss_url ?? ''
  return parser.hostname
})

const { t } = useI18n()
const labels = computed(() => ({
  title: t('views.channels.DetailBase.title')
}))

onBeforeRouteUpdate((to) => {
  to.meta.preserveScrollPosition = true
})

const router = useRouter()
const isLoading = ref(false)
const fetchData = async () => {
  showEditModal.value = false
  edit.loading = false
  isLoading.value = true

  try {
    const response = await axios.get(`channels/${props.id}`, { params: { refresh: 'true' } })
    object.value = response.data
    totalTracks.value = response.data.artist.tracks_count

    if (props.id === response.data.uuid && response.data.actor) {
      // replace with the pretty channel url if possible
      const actor = response.data.actor
      if (actor.is_local) {
        await router.replace({ name: 'channels.detail', params: { id: actor.preferred_username } })
      } else {
        await router.replace({ name: 'channels.detail', params: { id: actor.full_username } })
      }
    }
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoading.value = false
}

watch(() => props.id, fetchData, { immediate: true })

const uuid = computed(() => store.state.channels.latestPublication?.channel.uuid)
watch([uuid, object], ([uuid, object], [lastUuid, lastObject]) => {
  if (object?.uuid && object.uuid === lastObject?.uuid) return

  if (uuid && uuid === object?.uuid) {
    fetchData()
  }
})

const route = useRoute()
watchEffect(() => {
  if (!object.value) return
  if (!store.state.auth.authenticated && store.getters['instance/domain'] !== object.value.actor.domain) {
    router.push({ name: 'login', query: { next: route.fullPath } })
  }
})

const remove = async () => {
  isLoading.value = true
  try {
    await axios.delete(`channels/${object.value?.uuid}`)
    emit('deleted')
    return router.push({ name: 'profile.overview', params: { username: store.state.auth.username } })
  } catch (error) {
    useErrorHandler(error as Error)
  }
}

const updateSubscriptionCount = (delta: number) => {
  if (object.value) {
    object.value.subscriptions_count += delta
  }
}
</script>

<template>
  <main
    v-title="labels.title"
    class="main pusher"
  >
    <div
      v-if="isLoading"
      class="ui vertical segment"
    >
      <div :class="['ui', 'centered', 'active', 'inline', 'loader']" />
    </div>
    <template v-if="object && !isLoading">
      <section
        v-title="object.artist?.name"
        class="ui head vertical stripe segment container"
      >
        <div class="ui stackable grid">
          <div class="seven wide column">
            <div class="ui two column grid">
              <div class="column">
                <img
                  v-if="object.artist?.cover"
                  alt=""
                  class="huge channel-image"
                  :src="$store.getters['instance/absoluteUrl'](object.artist.cover.urls.medium_square_crop)"
                >
                <i
                  v-else
                  class="huge circular inverted users violet icon"
                />
              </div>
              <div class="ui column right aligned">
                <tags-list
                  v-if="object.artist?.tags && object.artist?.tags.length > 0"
                  :tags="object.artist.tags"
                />
                <actor-link
                  v-if="object.actor"
                  :avatar="false"
                  :actor="object.attributed_to"
                  :display-name="true"
                />
                <template v-if="totalTracks > 0">
                  <div class="ui hidden very small divider" />
                  <span
                    v-if="object.artist?.content_category === 'podcast'"
                  >
                    {{ $t('views.channels.DetailBase.meta.episodes', totalTracks) }}
                  </span>
                  <span
                    v-else
                  >
                    {{ $t('views.channels.DetailBase.meta.tracks', totalTracks) }}
                  </span>
                </template>
                <template v-if="object.attributed_to.full_username === $store.state.auth.fullUsername || $store.getters['channels/isSubscribed'](object.uuid)">
                  <br>
                  {{ $t('views.channels.DetailBase.meta.subscribers', object?.subscriptions_count ?? 0) }}
                  <br>
                  {{ $t('views.channels.DetailBase.meta.listenings', object?.downloads_count ?? 0) }}
                </template>
                <div class="ui hidden small divider" />
                <a
                  class="ui icon small basic button"
                  @click.stop.prevent="showSubscribeModal = true"
                >
                  <i class="feed icon" />
                </a>
                <semantic-modal
                  v-model:show="showSubscribeModal"
                  class="tiny"
                >
                  <h4 class="header">
                    {{ $t('views.channels.DetailBase.modal.subscribe.header') }}
                  </h4>
                  <div class="scrollable content">
                    <div class="description">
                      <template v-if="$store.state.auth.authenticated">
                        <h3>
                          <i class="user icon" />
                          {{ $t('views.channels.DetailBase.modal.subscribe.funkwhale.header') }}
                        </h3>
                        <subscribe-button
                          :channel="object"
                          @subscribed="updateSubscriptionCount(1)"
                          @unsubscribed="updateSubscriptionCount(-1)"
                        />
                      </template>
                      <template v-if="object.rss_url">
                        <h3>
                          <i class="feed icon" />
                          {{ $t('views.channels.DetailBase.modal.subscribe.rss.header') }}
                        </h3>
                        <p>
                          {{ $t('views.channels.DetailBase.modal.subscribe.rss.content.help') }}
                        </p>
                        <copy-input :value="object.rss_url" />
                      </template>
                      <template v-if="object.actor">
                        <h3>
                          <i class="bell icon" />
                          {{ $t('views.channels.DetailBase.modal.subscribe.fediverse.header') }}
                        </h3>
                        <p>
                          {{ $t('views.channels.DetailBase.modal.subscribe.fediverse.content.help') }}
                        </p>
                        <copy-input
                          id="copy-tag"
                          :value="`@${object.actor.full_username}`"
                        />
                      </template>
                    </div>
                  </div>
                  <div class="actions">
                    <button class="ui basic deny button">
                      {{ $t('views.channels.DetailBase.button.cancel') }}
                    </button>
                  </div>
                </semantic-modal>
                <button
                  ref="dropdown"
                  v-dropdown="{direction: 'downward'}"
                  class="ui right floated pointing dropdown icon small basic button"
                >
                  <i class="ellipsis vertical icon" />
                  <div class="menu">
                    <a
                      v-if="totalTracks > 0"
                      href=""
                      class="basic item"
                      @click.prevent="showEmbedModal = !showEmbedModal"
                    >
                      <i class="code icon" />
                      {{ $t('views.channels.DetailBase.button.embed') }}
                    </a>
                    <a
                      v-if="object.actor && object.actor.domain != $store.getters['instance/domain']"
                      :href="object.url"
                      target="_blank"
                      class="basic item"
                    >
                      <i class="external icon" />
                      {{ $t('views.channels.DetailBase.link.domainView', {domain: object.actor.domain}) }}
                    </a>
                    <div class="divider" />
                    <a
                      v-for="obj in getReportableObjects({account: object.attributed_to, channel: object})"
                      :key="obj.target.type + obj.target.id"
                      href=""
                      class="basic item"
                      @click.stop.prevent="report(obj)"
                    >
                      <i class="share icon" /> {{ obj.label }}
                    </a>

                    <template v-if="isOwner">
                      <div class="divider" />
                      <a
                        class="item"
                        href=""
                        @click.stop.prevent="showEditModal = true"
                      >
                        <i class="edit icon" />
                        {{ $t('views.channels.DetailBase.button.edit') }}
                      </a>
                      <dangerous-button
                        v-if="object"
                        :class="['ui', {loading: isLoading}, 'item']"
                        @confirm="remove()"
                      >
                        <i class="ui trash icon" />
                        {{ $t('views.channels.DetailBase.button.delete') }}
                        <template #modal-header>
                          <p>
                            {{ $t('views.channels.DetailBase.modal.delete.header') }}
                          </p>
                        </template>
                        <template #modal-content>
                          <div>
                            <p>
                              {{ $t('views.channels.DetailBase.modal.delete.content.warning') }}
                            </p>
                          </div>
                        </template>
                        <template #modal-confirm>
                          <p>
                            {{ $t('views.channels.DetailBase.button.confirm') }}
                          </p>
                        </template>
                      </dangerous-button>
                    </template>
                    <template v-if="$store.state.auth.availablePermissions['library']">
                      <div class="divider" />
                      <router-link
                        class="basic item"
                        :to="{name: 'manage.channels.detail', params: {id: object.uuid}}"
                      >
                        <i class="wrench icon" />
                        {{ $t('views.channels.DetailBase.link.moderation') }}
                      </router-link>
                    </template>
                  </div>
                </button>
              </div>
            </div>
            <h1 class="ui header">
              <div
                class="left aligned"
                :title="object.artist?.name"
              >
                {{ object.artist?.name }}
                <div class="ui hidden very small divider" />
                <div
                  v-if="object.actor"
                  class="sub header ellipsis"
                  :title="object.actor.full_username"
                >
                  {{ object.actor.full_username }}
                </div>
                <div
                  v-else
                  class="sub header ellipsis"
                >
                  <a
                    :href="object.url || object.rss_url"
                    rel="noopener noreferrer"
                    target="_blank"
                  >
                    <i class="external link icon" />
                    {{ $t('views.channels.DetailBase.link.mirrored', {domain: externalDomain}) }}
                  </a>
                </div>
              </div>
            </h1>
            <div class="header-buttons">
              <div
                v-if="isOwner"
                class="ui buttons"
              >
                <button
                  class="ui basic labeled icon button"
                  @click.prevent.stop="$store.commit('channels/showUploadModal', {show: true, config: {channel: object}})"
                >
                  <i class="upload icon" />
                  {{ $t('views.channels.DetailBase.button.upload') }}
                </button>
              </div>
              <div class="ui buttons">
                <play-button
                  :is-playable="isPlayable"
                  class="vibrant"
                  :artist="object.artist"
                >
                  {{ $t('views.channels.DetailBase.button.play') }}
                </play-button>
              </div>
              <div class="ui buttons">
                <subscribe-button
                  :channel="object"
                  @subscribed="updateSubscriptionCount(1)"
                  @unsubscribed="updateSubscriptionCount(-1)"
                />
              </div>

              <semantic-modal
                v-if="totalTracks > 0"
                v-model:show="showEmbedModal"
              >
                <h4 class="header">
                  {{ $t('views.channels.DetailBase.modal.embed.header') }}
                </h4>
                <div class="scrolling content">
                  <div class="description">
                    <embed-wizard
                      :id="object.artist!.id"
                      type="artist"
                    />
                  </div>
                </div>
                <div class="actions">
                  <button class="ui basic deny button">
                    {{ $t('views.channels.DetailBase.button.cancel') }}
                  </button>
                </div>
              </semantic-modal>
              <semantic-modal
                v-if="isOwner"
                v-model:show="showEditModal"
              >
                <h4 class="header">
                  <span
                    v-if="object.artist?.content_category === 'podcast'"
                  >
                    {{ $t('views.channels.DetailBase.header.podcastChannel') }}
                  </span>
                  <span
                    v-else
                  >
                    {{ $t('views.channels.DetailBase.header.artistChannel') }}
                  </span>
                </h4>
                <div class="scrolling content">
                  <channel-form
                    ref="editForm"
                    :object="object"
                    @loading="edit.loading = $event"
                    @submittable="edit.submittable = $event"
                    @updated="fetchData"
                  />
                  <div class="ui hidden divider" />
                </div>
                <div class="actions">
                  <button class="ui left floated basic deny button">
                    {{ $t('views.channels.DetailBase.button.cancel') }}
                  </button>
                  <button
                    :class="['ui', 'primary', 'confirm', {loading: edit.loading}, 'button']"
                    :disabled="!edit.submittable"
                    @click.stop="editForm?.submit"
                  >
                    {{ $t('views.channels.DetailBase.button.updateChannel') }}
                  </button>
                </div>
              </semantic-modal>
            </div>
            <div v-if="$store.getters['ui/layoutVersion'] === 'large'">
              <rendered-description
                :content="object.artist?.description"
                :update-url="`channels/${object.uuid}/`"
                :can-update="false"
                @updated="object = $event"
              />
            </div>
          </div>
          <div class="nine wide column">
            <div class="ui secondary pointing center aligned menu">
              <router-link
                class="item"

                :to="{name: 'channels.detail', params: {id: id}}"
              >
                {{ $t('views.channels.DetailBase.link.channelOverview') }}
              </router-link>
              <router-link
                class="item"

                :to="{name: 'channels.detail.episodes', params: {id: id}}"
              >
                <span
                  v-if="isPodcast"
                >
                  {{ $t('views.channels.DetailBase.link.channelEpisodes') }}
                </span>
                <span
                  v-else
                >
                  {{ $t('views.channels.DetailBase.link.channelTracks') }}
                </span>
              </router-link>
            </div>
            <div class="ui hidden divider" />
            <router-view
              v-if="object"
              :object="object"
              @tracks-loaded="totalTracks = $event"
            />
          </div>
        </div>
      </section>
    </template>
  </main>
</template>
