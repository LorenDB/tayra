<script setup lang="ts">
import type { Library } from '~/types'

import { onBeforeRouteUpdate, useRoute, useRouter } from 'vue-router'
import { computed, ref, watch, watchEffect } from 'vue'
import { humanSize } from '~/utils/filters'
import { useI18n } from 'vue-i18n'
import { useStore } from '~/store'

import axios from 'axios'

import LibraryFollowButton from '~/components/audio/LibraryFollowButton.vue'
import RadioButton from '~/components/radios/Button.vue'

import useErrorHandler from '~/composables/useErrorHandler'
import useReport from '~/composables/moderation/useReport'

interface Props {
  id: number
}

const props = defineProps<Props>()

const { report, getReportableObjects } = useReport()
const store = useStore()

const object = ref<Library | null>(null)

const isOwner = computed(() => store.state.auth.authenticated && object.value?.actor.full_username === store.state.auth.fullUsername)
const isPlayable = computed(() => (object.value?.uploads_count ?? 0) > 0 && (
  isOwner.value
    || object.value?.privacy_level === 'everyone'
    || (object.value?.privacy_level === 'instance' && store.state.auth.authenticated && object.value.actor.domain === store.getters['instance/domain'])
    || (store.getters['libraries/follow'](object.value?.uuid) || {}).approved === true
))

const { t } = useI18n()
const labels = computed(() => ({
  title: t('views.library.LibraryBase.title'),
  visibility: {
    me: t('views.library.LibraryBase.label.private'),
    instance: t('views.library.LibraryBase.label.instance'),
    everyone: t('views.library.LibraryBase.label.public')
  },
  tooltips: {
    me: t('views.library.LibraryBase.tooltip.private'),
    instance: t('views.library.LibraryBase.tooltip.instance'),
    everyone: t('views.library.LibraryBase.tooltip.public')
  }
}))

onBeforeRouteUpdate((to) => {
  to.meta.preserveScrollPosition = true
})

const isLoading = ref(false)
const fetchData = async () => {
  isLoading.value = true
  try {
    const response = await axios.get(`libraries/${props.id}`)
    object.value = response.data
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoading.value = false
}

watch(() => props.id, fetchData, { immediate: true })

const route = useRoute()
const router = useRouter()
watchEffect(() => {
  if (!store.state.auth.authenticated && object.value && store.getters['instance/domain'] !== object.value.actor.domain) {
    router.push({ name: 'login', query: { next: route.fullPath } })
  }
})

const updateUploads = (count: number) => {
  if (object.value) {
    object.value.uploads_count += count
  }
}
</script>

<template>
  <main v-title="labels.title">
    <div class="ui vertical stripe segment container">
      <div
        v-if="isLoading"
        class="ui centered active inline loader"
      />
      <div
        v-else-if="object"
        class="ui stackable grid"
      >
        <div class="ui five wide column">
          <button
            ref="dropdown"
            v-dropdown="{direction: 'downward'}"
            class="ui pointing dropdown icon small basic right floated button"
            style="position: absolute; right: 1em; top: 1em;"
          >
            <i class="ellipsis vertical icon" />
            <div class="menu">
              <a
                v-if="object.actor.domain != $store.getters['instance/domain']"
                :href="object.fid"
                target="_blank"
                class="basic item"
              >
                <i class="external icon" />
                {{ $t('views.library.LibraryBase.link.domain', {domain: object.actor.domain}) }}
              </a>
              <div
                v-for="obj in getReportableObjects({library: object})"
                :key="obj.target.type + obj.target.id"
                role="button"
                class="basic item"
                @click.stop.prevent="report(obj)"
              >
                <i class="share icon" /> {{ obj.label }}
              </div>

              <div class="divider" />
              <router-link
                v-if="$store.state.auth.availablePermissions['moderation']"
                class="basic item"
                :to="{name: 'manage.library.libraries.detail', params: {id: object.uuid}}"
              >
                <i class="wrench icon" />
                {{ $t('views.library.LibraryBase.link.moderation') }}
              </router-link>
            </div>
          </button>
          <h1 class="ui header">
            <div class="ui hidden divider" />
            <div class="ellipsis content">
              <i class="layer group small icon" />
              <span>{{ object.name }}</span>
              <div class="ui very small hidden divider" />
              <div
                class="sub header ellipsis"
                :title="object.actor.full_username"
              >
                <actor-link
                  :avatar="false"
                  :actor="object.actor"
                  :truncate-length="0"
                >
                  {{ $t('views.library.LibraryBase.link.owner', {username: object.actor.full_username}) }}
                </actor-link>
              </div>
            </div>
          </h1>
          <p>
            <span
              v-if="object.privacy_level === 'me'"
              :title="labels.tooltips.me"
            >
              <i class="lock icon" />
              {{ labels.visibility.me }}
            </span>
            <span
              v-else-if="object.privacy_level === 'instance'"
              :title="labels.tooltips.instance"
            >
              <i class="lock open icon" />
              {{ labels.visibility.instance }}
            </span>
            <span
              v-else-if="object.privacy_level === 'everyone'"
              :title="labels.tooltips.everyone"
              class="middledot icon"
            >
              <i class="globe icon" />
              {{ labels.visibility.everyone }}
            </span>
            <span class="middledot icon">
              <i class="music icon" />
              {{ $t('views.library.LibraryBase.meta.tracks', object.uploads_count) }}
            </span>
            <span v-if="object.size">
              <i class="database icon" />
              {{ humanSize(object.size) }}
            </span>
          </p>

          <div class="header-buttons">
            <div class="ui small buttons">
              <radio-button
                :disabled="!isPlayable || null"
                type="library"
                :object-id="object.uuid"
              />
            </div>
            <div
              v-if="!isOwner"
              class="ui small buttons"
            >
              <library-follow-button
                v-if="$store.state.auth.authenticated"
                :library="object"
              />
            </div>
          </div>

          <template v-if="$store.getters['ui/layoutVersion'] === 'large'">
            <rendered-description
              :content="object.description ? {html: object.description} : null"
              :update-url="`channels/${object.uuid}/`"
              :can-update="false"
            />
            <div class="ui hidden divider" />
          </template>
          <div class="ui form">
            <div class="field">
              <label for="copy-input">
                {{ $t('views.library.LibraryBase.label.sharingLink') }}
              </label>
              <p>
                {{ $t('views.library.LibraryBase.description.sharingLink') }}
              </p>
              <copy-input :value="object.fid" />
            </div>
          </div>
        </div>
        <div class="ui eleven wide column">
          <div class="ui head vertical stripe segment">
            <div class="ui container">
              <div class="ui secondary pointing center aligned menu">
                <router-link
                  class="item"
                  exact-active-class="active"
                  active-class=""
                  :to="{name: 'library.detail'}"
                >
                  {{ $t('views.library.LibraryBase.link.artists') }}
                </router-link>
                <router-link
                  class="item"
                  exact-active-class="active"
                  active-class=""
                  :to="{name: 'library.detail.albums'}"
                >
                  {{ $t('views.library.LibraryBase.link.albums') }}
                </router-link>
                <router-link
                  class="item"
                  exact-active-class="active"
                  active-class=""
                  :to="{name: 'library.detail.tracks'}"
                >
                  {{ $t('views.library.LibraryBase.link.tracks') }}
                </router-link>
                <router-link
                  v-if="isOwner"
                  class="item"
                  exact-active-class="active"
                  active-class=""
                  :to="{name: 'library.detail.upload'}"
                >
                  <i class="upload icon" />
                  {{ $t('views.library.LibraryBase.button.upload') }}
                </router-link>
                <router-link
                  v-if="isOwner"
                  class="item"
                  exact-active-class="active"
                  active-class=""
                  :to="{name: 'library.detail.edit'}"
                >
                  <i class="pencil icon" />
                  {{ $t('views.library.LibraryBase.button.edit') }}
                </router-link>
              </div>
              <div class="ui hidden divider" />
              <router-view
                :is-owner="isOwner"
                :object="object"
                @updated="fetchData"
                @uploads-finished="updateUploads"
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  </main>
</template>
