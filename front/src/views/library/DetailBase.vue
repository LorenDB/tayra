<script setup lang="ts">
// TODO (wvffle): Rename to LibraryBase
import type { Library } from '~/types'

import { onBeforeRouteUpdate, useRoute, useRouter } from 'vue-router'
import { computed, ref, watch, watchEffect } from 'vue'
import { humanSize } from '~/utils/filters'
import { useGettext } from 'vue3-gettext'
import { useStore } from '~/store'

import axios from 'axios'

import LibraryFollowButton from '~/components/audio/LibraryFollowButton.vue'
import RadioButton from '~/components/radios/Button.vue'

import useErrorHandler from '~/composables/useErrorHandler'
import useReport from '~/composables/moderation/useReport'

interface Props {
  id: string
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

const { $pgettext } = useGettext()
const labels = computed(() => ({
  title: $pgettext('*/*/*', 'Library'),
  visibility: {
    me: $pgettext('Content/Library/Card.Help text', 'Private'),
    instance: $pgettext('Content/Library/Card.Help text', 'Restricted'),
    everyone: $pgettext('Content/Library/Card.Help text', 'Public')
  },
  tooltips: {
    me: $pgettext('Content/Library/Card.Help text', 'This library is private and your approval from its owner is needed to access its content'),
    instance: $pgettext('Content/Library/Card.Help text', 'This library is restricted to users on this pod only'),
    everyone: $pgettext('Content/Library/Card.Help text', 'This library is public and you can access its content freely')
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
                <translate
                  :translate-params="{domain: object.actor.domain}"
                  translate-context="Content/*/Button.Label/Verb"
                >View on %{ domain }</translate>
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
                <translate translate-context="Content/Moderation/Link">
                  Open in moderation interface
                </translate>
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
                  <translate
                    translate-context="*/*/*"
                    :translate-params="{username: object.actor.full_username}"
                  >
                    Owned by %{ username }
                  </translate>
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
            >
              <i class="globe icon" />
              {{ labels.visibility.everyone }}
            </span> ·
            <i class="music icon" />
            <translate
              translate-context="*/*/*"
              :translate-params="{count: object.uploads_count}"
              :translate-n="object.uploads_count"
              translate-plural="%{ count } tracks"
            >
              %{ count } track
            </translate>
            <span v-if="object.size">
              · <i class="database icon" />
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
                <translate translate-context="Content/Library/Title">Sharing link</translate>
              </label>
              <p>
                <translate translate-context="Content/Library/Paragraph">
                  Share this link with other users so they can request access to this library by copy-pasting it in their pod search bar.
                </translate>
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

                  :to="{name: 'library.detail'}"
                >
                  <translate translate-context="*/*/*">
                    Artists
                  </translate>
                </router-link>
                <router-link
                  class="item"

                  :to="{name: 'library.detail.albums'}"
                >
                  <translate translate-context="*/*/*">
                    Albums
                  </translate>
                </router-link>
                <router-link
                  class="item"

                  :to="{name: 'library.detail.tracks'}"
                >
                  <translate translate-context="*/*/*">
                    Tracks
                  </translate>
                </router-link>
                <router-link
                  v-if="isOwner"
                  class="item"

                  :to="{name: 'library.detail.upload'}"
                >
                  <i class="upload icon" />
                  <translate translate-context="Content/Library/Card.Button.Label/Verb">
                    Upload
                  </translate>
                </router-link>
                <router-link
                  v-if="isOwner"
                  class="item"

                  :to="{name: 'library.detail.edit'}"
                >
                  <i class="pencil icon" />
                  <translate translate-context="Content/*/Button.Label/Verb">
                    Edit
                  </translate>
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
