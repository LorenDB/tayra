<script setup lang="ts">
import SemanticModal from '~/components/semantic/Modal.vue'
import { ref } from 'vue'

interface Props {
  action?: () => void
  disabled?: boolean
  // TODO (wvffle): Find correct type
  confirmColor?: 'danger'
}

// TODO (wvffle): MOVE ALL defineEmits ABOVE defineProps
const emit = defineEmits()

const props = withDefaults(defineProps<Props>(), {
  action: () => {},
  disabled: false,
  confirmColor: 'danger'
})

const showModal = ref(false)

const confirm = () => {
  showModal.value = false
  emit('confirm')
  props.action?.()
}
</script>

<template>
  <button
    :class="[{disabled: disabled}]"
    :disabled="disabled || null"
    @click.prevent.stop="showModal = true"
  >
    <slot />

    <semantic-modal
      v-model:show="showModal"
      class="small"
    >
      <h4 class="header">
        <slot name="modal-header">
          <translate translate-context="Modal/*/Title">
            Do you want to confirm this action?
          </translate>
        </slot>
      </h4>
      <div class="scrolling content">
        <div class="description">
          <slot name="modal-content" />
        </div>
      </div>
      <div class="actions">
        <button class="ui basic cancel button">
          <translate translate-context="*/*/Button.Label/Verb">
            Cancel
          </translate>
        </button>
        <button
          :class="['ui', 'confirm', confirmColor, 'button']"
          @click="confirm"
        >
          <slot name="modal-confirm">
            <translate translate-context="Modal/*/Button.Label/Short, Verb">
              Confirm
            </translate>
          </slot>
        </button>
      </div>
    </semantic-modal>
  </button>
</template>
