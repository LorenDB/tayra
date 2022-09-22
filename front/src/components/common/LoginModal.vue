<script setup lang="ts">
import type { RouteLocationRaw } from 'vue-router'
import type { Cover } from '~/types'

import SemanticModal from '~/components/semantic/Modal.vue'
import { ref, computed } from 'vue'
import { useI18n } from 'vue-i18n'

interface Props {
  nextRoute: RouteLocationRaw
  message: string
  cover: Cover
}

defineProps<Props>()

const show = ref(false)

const { t } = useI18n()
const labels = computed(() => ({
  header: t('components.common.LoginModal.header.unauthenticated'),
  login: t('components.common.LoginModal.link.login'),
  signup: t('components.common.LoginModal.link.signup'),
  description: t('components.common.LoginModal.description.noAccess')
}))
</script>

<template>
  <semantic-modal v-model:show="show">
    <h4 class="header">
      {{ labels.header }}
    </h4>
    <div
      v-if="cover"
      class="image content"
    >
      <div class="ui medium image">
        <img :src="cover.urls.medium_square_crop">
      </div>
      <div class="description">
        <div class="ui header">
          {{ labels.description }}
        </div>
        <p>
          {{ message }}
        </p>
      </div>
    </div>
    <div
      v-else
      class="content"
    >
      <div class="ui centered header">
        {{ labels.description }}
      </div>
      <p style="text-align: center;">
        {{ message }}
      </p>
    </div>
    <div class="actions">
      <router-link
        :to="{path: '/login', query: { next: nextRoute as string }}"
        class="ui labeled icon button"
      >
        <i class="key icon" />
        {{ labels.login }}
      </router-link>
      <router-link
        v-if="$store.state.instance.settings.users.registration_enabled.value"
        :to="{path: '/signup'}"
        class="ui labeled icon button"
      >
        <i class="user icon" />
        {{ labels.signup }}
      </router-link>
    </div>
  </semantic-modal>
</template>
