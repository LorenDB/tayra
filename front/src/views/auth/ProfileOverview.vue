<script setup lang="ts">
import type { Actor } from '~/types'

import SemanticModal from '~/components/semantic/Modal.vue'
import LibraryWidget from '~/components/federation/LibraryWidget.vue'
import ChannelsWidget from '~/components/audio/ChannelsWidget.vue'
import ChannelForm from '~/components/audio/ChannelForm.vue'
import { ref } from 'vue'

interface Events {
  (e: 'updated', value: Actor): void
}

interface Props {
  object: Actor
}

const emit = defineEmits<Events>()
defineProps<Props>()

const step = ref(1)
const showCreateModal = ref(false)
const loading = ref(false)
const submittable = ref(false)
const category = ref('podcast')

const modalContent = ref()
const createForm = ref()
</script>

<template>
  <section>
    <div v-if="$store.getters['ui/layoutVersion'] === 'small'">
      <rendered-description
        :content="object.summary"
        :field-name="'summary'"
        :update-url="`users/${$store.state.auth.username}/`"
        :can-update="$store.state.auth.authenticated && object.full_username === $store.state.auth.fullUsername"
        @updated="emit('updated', $event)"
      />
      <div class="ui hidden divider" />
    </div>
    <div>
      <h2 class="ui with-actions header">
        {{ $t('views.auth.ProfileOverview.header.channels') }}
        <div
          v-if="$store.state.auth.authenticated && object.full_username === $store.state.auth.fullUsername"
          class="actions"
        >
          <a
            href=""
            @click.stop.prevent="showCreateModal = true"
          >
            <i class="plus icon" />
            {{ $t('views.auth.ProfileOverview.link.addNew') }}
          </a>
        </div>
      </h2>
      <channels-widget :filters="{scope: `actor:${object.full_username}`}" />
      <h2 class="ui with-actions header">
        {{ $t('views.auth.ProfileOverview.header.libraries') }}
        <div
          v-if="$store.state.auth.authenticated && object.full_username === $store.state.auth.fullUsername"
          class="actions"
        >
          <router-link :to="{name: 'content.libraries.index'}">
            <i class="plus icon" />
            {{ $t('views.auth.ProfileOverview.link.addNew') }}
          </router-link>
        </div>
      </h2>
      <library-widget :url="`federation/actors/${object.full_username}/libraries/`">
        <template #title>
          {{ $t('views.auth.ProfileOverview.header.sharedLibraries') }}
        </template>
      </library-widget>
    </div>

    <semantic-modal v-model:show="showCreateModal">
      <h4 class="header">
        <span
          v-if="step === 1"
        >
          {{ $t('views.auth.ProfileOverview.modal.createChannel.header') }}
        </span>
        <span
          v-else-if="category === 'podcast'"
        >
          {{ $t('views.auth.ProfileOverview.modal.createChannel.podcast.header') }}
        </span>
        <span
          v-else
        >
          {{ $t('views.auth.ProfileOverview.modal.createChannel.artist.header') }}
        </span>
      </h4>
      <div
        ref="modalContent"
        class="scrolling content"
      >
        <channel-form
          ref="createForm"
          :object="null"
          :step="step"
          @loading="loading = $event"
          @submittable="submittable = $event"
          @category="category = $event"
          @errored="modalContent.scrollTop = 0"
          @created="$router.push({name: 'channels.detail', params: {id: $event.actor.preferred_username}})"
        />
        <div class="ui hidden divider" />
      </div>
      <div class="actions">
        <button
          v-if="step === 1"
          class="ui basic deny button"
        >
          {{ $t('views.auth.ProfileOverview.button.cancel') }}
        </button>
        <button
          v-if="step > 1"
          class="ui basic button"
          @click.stop.prevent="step -= 1"
        >
          {{ $t('views.auth.ProfileOverview.button.previous') }}
        </button>
        <button
          v-if="step === 1"
          class="ui primary button"
          @click.stop.prevent="step += 1"
        >
          {{ $t('views.auth.ProfileOverview.button.next') }}
        </button>
        <button
          v-if="step === 2"
          :class="['ui', 'primary button', { loading }]"
          type="submit"
          :disabled="!submittable && !loading"
          @click.prevent.stop="createForm.submit"
        >
          {{ $t('views.auth.ProfileOverview.button.createChannel') }}
        </button>
      </div>
    </semantic-modal>
  </section>
</template>
