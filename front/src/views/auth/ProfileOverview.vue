<script setup lang="ts">
import type { Actor } from '~/types'

import SemanticModal from '~/components/semantic/Modal.vue'
import LibraryWidget from '~/components/federation/LibraryWidget.vue'
import ChannelsWidget from '~/components/audio/ChannelsWidget.vue'
import ChannelForm from '~/components/audio/ChannelForm.vue'
import { ref } from 'vue'

interface Props {
  object: Actor
}

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
        @updated="$emit('updated', $event)"
      />
      <div class="ui hidden divider" />
    </div>
    <div>
      <h2 class="ui with-actions header">
        <translate translate-context="*/*/*">
          Channels
        </translate>
        <div
          v-if="$store.state.auth.authenticated && object.full_username === $store.state.auth.fullUsername"
          class="actions"
        >
          <a
            href=""
            @click.stop.prevent="showCreateModal = true"
          >
            <i class="plus icon" />
            <translate translate-context="Content/Profile/Button">Add new</translate>
          </a>
        </div>
      </h2>
      <channels-widget :filters="{scope: `actor:${object.full_username}`}" />
      <h2 class="ui with-actions header">
        <translate translate-context="Content/Profile/Header">
          User Libraries
        </translate>
        <div
          v-if="$store.state.auth.authenticated && object.full_username === $store.state.auth.fullUsername"
          class="actions"
        >
          <router-link :to="{name: 'content.libraries.index'}">
            <i class="plus icon" />
            <translate translate-context="Content/Profile/Button">
              Add new
            </translate>
          </router-link>
        </div>
      </h2>
      <library-widget :url="`federation/actors/${object.full_username}/libraries/`">
        <template #title>
          <translate translate-context="Content/Profile/Paragraph">
            This user shared the following libraries
          </translate>
        </template>
      </library-widget>
    </div>

    <semantic-modal v-model:show="showCreateModal">
      <h4 class="header">
        <translate
          v-if="step === 1"
          translate-context="Content/Channel/*/Verb"
        >
          Create channel
        </translate>
        <translate
          v-else-if="category === 'podcast'"
          translate-context="Content/Channel/*"
        >
          Podcast channel
        </translate>
        <translate
          v-else
          translate-context="Content/Channel/*"
        >
          Artist channel
        </translate>
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
          <translate translate-context="*/*/Button.Label/Verb">
            Cancel
          </translate>
        </button>
        <button
          v-if="step > 1"
          class="ui basic button"
          @click.stop.prevent="step -= 1"
        >
          <translate translate-context="*/*/Button.Label/Verb">
            Previous step
          </translate>
        </button>
        <button
          v-if="step === 1"
          class="ui primary button"
          @click.stop.prevent="step += 1"
        >
          <translate translate-context="*/*/Button.Label">
            Next step
          </translate>
        </button>
        <button
          v-if="step === 2"
          :class="['ui', 'primary button', { loading }]"
          type="submit"
          :disabled="!submittable && !loading"
          @click.prevent.stop="createForm.submit"
        >
          <translate translate-context="*/Channels/Button.Label">
            Create channel
          </translate>
        </button>
      </div>
    </semantic-modal>
  </section>
</template>
