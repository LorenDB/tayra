<script setup lang="ts">
import type { Radio } from '~/types'

import { ref, computed } from 'vue'
import { useStore } from '~/store'

import RadioButton from './Button.vue'

interface Props {
  type: string
  customRadio?: Radio | null
  objectId?: string | null
}

const props = withDefaults(defineProps<Props>(), {
  customRadio: null,
  objectId: null
})

const store = useStore()

const isDescriptionExpanded = ref(false)

const radio = computed(() => props.customRadio
  ? props.customRadio
  : store.getters['radios/types'][props.type]
)

const customRadioId = computed(() => props.customRadio?.id ?? null)
</script>

<template>
  <div class="ui card">
    <div class="content">
      <h4 class="header">
        <router-link
          v-if="radio.id"
          class="discrete link"
          :to="{name: 'library.radios.detail', params: {id: radio.id}}"
        >
          {{ radio.name }}
        </router-link>
        <template v-else>
          {{ radio.name }}
        </template>
      </h4>
      <div
        class="description"
        :class="{expanded: isDescriptionExpanded}"
        @click="isDescriptionExpanded = !isDescriptionExpanded"
      >
        {{ radio.description }}
      </div>
    </div>
    <div class="extra content">
      <user-link
        v-if="radio.user"
        :user="radio.user"
        class="left floated"
      />
      <div class="ui hidden divider" />
      <radio-button
        class="right floated button"
        :type="type"
        :custom-radio-id="customRadioId"
        :object-id="objectId"
      />
      <router-link
        v-if="$store.state.auth.authenticated && type === 'custom' && radio.user.id === $store.state.auth.profile?.id"
        class="ui success button right floated"
        :to="{name: 'library.radios.edit', params: {id: customRadioId }}"
      >
        <translate translate-context="Content/*/Button.Label/Verb">
          Edit
        </translate>
      </router-link>
    </div>
  </div>
</template>
