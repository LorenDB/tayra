<template>
  <modal
    v-model:show="showRef"
    @update:show="update"
  >
    <h4 class="header">
      <translate
        v-if="type === 'artist'"
        key="1"
        translate-context="Popup/Moderation/Title/Verb"
        :translate-params="{name: target.name}"
      >
        Do you want to hide content from artist "%{ name }"?
      </translate>
    </h4>
    <div class="scrolling content">
      <div class="description">
        <div
          v-if="errors.length > 0"
          role="alert"
          class="ui negative message"
        >
          <h4 class="header">
            <translate translate-context="Popup/Moderation/Error message">
              Error while creating filter
            </translate>
          </h4>
          <ul class="list">
            <li
              v-for="(error, key) in errors"
              :key="key"
            >
              {{ error }}
            </li>
          </ul>
        </div>
        <template v-if="type === 'artist'">
          <p>
            <translate translate-context="Popup/Moderation/Paragraph">
              You will not see tracks, albums and user activity linked to this artist any more:
            </translate>
          </p>
          <ul>
            <li>
              <translate translate-context="Popup/Moderation/List item">
                In other users favorites and listening history
              </translate>
            </li>
            <li>
              <translate translate-context="Popup/Moderation/List item">
                In "Recently added" widget
              </translate>
            </li>
            <li>
              <translate translate-context="Popup/Moderation/List item">
                In artists and album listings
              </translate>
            </li>
            <li>
              <translate translate-context="Popup/Moderation/List item">
                In radio suggestions
              </translate>
            </li>
          </ul>
          <p>
            <translate translate-context="Popup/Moderation/Paragraph">
              You can manage and update your filters any time from your account settings.
            </translate>
          </p>
        </template>
      </div>
    </div>
    <div class="actions">
      <button class="ui basic cancel button">
        <translate translate-context="*/*/Button.Label/Verb">
          Cancel
        </translate>
      </button>
      <button
        :class="['ui', 'success', {loading: isLoading}, 'button']"
        @click="hide"
      >
        <translate translate-context="Popup/*/Button.Label">
          Hide content
        </translate>
      </button>
    </div>
  </modal>
</template>

<script>
import axios from 'axios'
import { mapState } from 'vuex'
import { computed } from 'vue'

import Modal from '~/components/semantic/Modal.vue'
import useLogger from '~/composables/useLogger'
import { useStore } from '~/store'

const logger = useLogger()

export default {
  components: {
    Modal
  },
  setup () {
    const store = useStore()
    const showRef = computed(() => store.state.moderation.showFilterModal)
    return { showRef }
  },
  data () {
    return {
      formKey: String(new Date()),
      errors: [],
      isLoading: false
    }
  },
  computed: {
    ...mapState({
      type: state => state.moderation.filterModalTarget.type,
      target: state => state.moderation.filterModalTarget.target
    })
  },
  methods: {
    update (v) {
      this.$store.commit('moderation/showFilterModal', v)
      this.errors.length = 0
    },
    hide () {
      const self = this
      self.isLoading = true
      const payload = {
        target: {
          type: this.type,
          id: this.target.id
        }
      }
      return axios.post('moderation/content-filters/', payload).then(response => {
        logger.info('Successfully added track to playlist')
        self.update(false)
        self.$store.moderation.state.lastUpdate = new Date()
        self.isLoading = false
        const msg = this.$pgettext('*/Moderation/Message', 'Content filter successfully added')
        self.$store.commit('moderation/contentFilter', response.data)
        self.$store.commit('ui/addMessage', {
          content: msg,
          date: new Date()
        })
      }, error => {
        logger.error(`Error while hiding ${self.type} ${self.target.id}`)
        self.errors = error.backendErrors
        self.isLoading = false
      })
    }
  }
}
</script>
