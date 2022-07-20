<script setup lang="ts">
import type { BackendError } from '~/types'

import axios from 'axios'

import { ref, computed } from 'vue'

import InstancePolicyForm from '~/components/manage/moderation/InstancePolicyForm.vue'
import InstancePolicyCard from '~/components/manage/moderation/InstancePolicyCard.vue'
import SemanticModal from '~/components/semantic/Modal.vue'

interface Props {
  target: string
  type: 'domain' | 'actor'
}

const props = defineProps<Props>()

const show = ref(false)
const showForm = ref(false)

const errors = ref([] as string[])
const result = ref()

const obj = computed(() => result.value?.results[0] ?? null)

const isLoading = ref(false)
const fetchData = async () => {
  const [username, domain] = props.target.split('@')

  const params = {
    target_domain: props.type === 'domain'
      ? props.target
      : undefined,

    target_account_username: props.type === 'actor'
      ? username
      : undefined,

    target_account_domain: props.type === 'actor'
      ? domain
      : undefined,
  }

  isLoading.value = true

  try {
    const response = await axios.get('/manage/moderation/instance-policies/', { params })
    result.value = response.data
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }

  isLoading.value = false
}
</script>

<template>
  <button
    class="ui button"
    @click.prevent="show = !show"
  >
    <i class="shield icon" />&nbsp;
    <slot>
      <translate translate-context="Content/Moderation/Button.Label">
        Moderation rules…
      </translate>
    </slot>
    <semantic-modal
      v-model:show="show"
      @show="fetchData"
    >
      <h4 class="header">
        <translate
          :translate-params="{obj: target}"
          translate-context="Popup/Moderation/Title/Verb"
        >
          Manage moderation rules for %{ obj }
        </translate>
      </h4>
      <div class="content">
        <div class="description">
          <div
            v-if="isLoading"
            class="ui active loader"
          />
          <instance-policy-card
            v-else-if="obj && !showForm"
            :object="obj"
            @update="showForm = true"
          >
            <header class="ui header">
              <h3>
                <translate translate-context="Content/Moderation/Card.Title">
                  This entity is subject to specific moderation rules
                </translate>
              </h3>
            </header>
          </instance-policy-card>
          <instance-policy-form
            v-else
            :object="obj"
            :type="type"
            :target="target"
            @cancel="showForm = false"
            @save="showForm = false; result = {count: 1, results: [$event]}"
            @delete="result = {count: 0, results: []}; showForm = false"
          />
        </div>
        <div class="ui hidden divider" />
        <div class="ui hidden divider" />
      </div>
      <div class="actions">
        <button class="ui deny button">
          <translate translate-context="*/*/Button.Label/Verb">
            Close
          </translate>
        </button>
      </div>
    </semantic-modal>
  </button>
</template>
