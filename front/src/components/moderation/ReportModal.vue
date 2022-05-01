<template>
  <modal
    v-model:show="showRef"
    @update:show="update"
  >
    <h2
      v-if="target"
      class="ui header"
    >
      <translate translate-context="Popup/Moderation/Title/Verb">
        Do you want to report this object?
      </translate>
      <div class="ui sub header">
        {{ target.typeLabel }} - {{ target.label }}
      </div>
    </h2>
    <div class="scrolling content">
      <div class="description">
        <div
          v-if="errors.length > 0"
          role="alert"
          class="ui negative message"
        >
          <h4 class="header">
            <translate translate-context="Popup/Moderation/Error message">
              Error while submitting report
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
      </div>
      <p>
        <translate translate-context="*/Moderation/Popup,Paragraph">
          Use this form to submit a report to our moderation team.
        </translate>
      </p>
      <form
        v-if="canSubmit"
        id="report-form"
        class="ui form"
        @submit.prevent="submit"
      >
        <div class="fields">
          <report-category-dropdown
            v-model="category"
            class="ui required eight wide field"
            :required="true"
            :empty="true"
            :restrict-to="allowedCategories"
            :label="true"
          />
          <div
            v-if="!$store.state.auth.authenticated"
            class="ui eight wide required field"
          >
            <label for="report-submitter-email">
              <translate translate-context="Content/*/*/Noun">Email</translate>
            </label>
            <input
              id="report-submitter-email"
              v-model="submitterEmail"
              type="email"
              name="report-submitter-email"
              required
            >
            <p>
              <translate translate-context="*/*/Field,Help">
                We'll use this e-mail address if we need to contact you regarding this report.
              </translate>
            </p>
          </div>
        </div>
        <div class="ui field">
          <label for="report-summary">
            <translate translate-context="*/*/Field.Label/Noun">Message</translate>
          </label>
          <p>
            <translate translate-context="*/*/Field,Help">
              Use this field to provide additional context to the moderator that will handle your report.
            </translate>
          </p>
          <content-form
            v-model="summary"
            field-id="report-summary"
            :rows="8"
          />
        </div>
        <div
          v-if="!isLocal"
          class="ui field"
        >
          <div class="ui checkbox">
            <input
              id="report-forward"
              v-model="forward"
              type="checkbox"
            >
            <label for="report-forward">
              <strong>
                <translate
                  :translate-params="{domain: targetDomain}"
                  translate-context="*/*/Field.Label/Verb"
                >Forward to %{ domain} </translate>
              </strong>
              <p>
                <translate translate-context="*/*/Field,Help">Forward an anonymized copy of your report to the server hosting this element.</translate>
              </p>
            </label>
          </div>
        </div>
        <div class="ui hidden divider" />
      </form>
      <div
        v-else-if="isLoadingReportTypes"
        class="ui inline active loader"
      />
      <div
        v-else
        role="alert"
        class="ui warning message"
      >
        <h4 class="header">
          <translate translate-context="Popup/Moderation/Error message">
            Anonymous reports are disabled, please sign-in to submit a report.
          </translate>
        </h4>
      </div>
    </div>
    <div class="actions">
      <button class="ui basic cancel button">
        <translate translate-context="*/*/Button.Label/Verb">
          Cancel
        </translate>
      </button>
      <button
        v-if="canSubmit"
        :class="['ui', 'success', {loading: isLoading}, 'button']"
        type="submit"
        form="report-form"
      >
        <translate translate-context="Popup/*/Button.Label">
          Submit report
        </translate>
      </button>
    </div>
  </modal>
</template>

<script>
import axios from 'axios'
import { mapState, useStore } from 'vuex'
import { computed } from 'vue'
import ReportCategoryDropdown from '~/components/moderation/ReportCategoryDropdown.vue'
import Modal from '~/components/semantic/Modal.vue'

function urlDomain (data) {
  const a = document.createElement('a')
  a.href = data
  return a.hostname
}

export default {
  components: {
    ReportCategoryDropdown,
    Modal
  },
  setup () {
    const store = useStore()
    const showRef = computed(() => store.state.moderation.showReportModal)
    return { showRef }
  },
  data () {
    return {
      formKey: String(new Date()),
      errors: [],
      isLoading: false,
      isLoadingReportTypes: false,
      summary: '',
      submitterEmail: '',
      category: null,
      reportTypes: [],
      forward: false
    }
  },
  computed: {
    ...mapState({
      target: state => state.moderation.reportModalTarget
    }),
    allowedCategories () {
      if (this.$store.state.auth.authenticated) {
        return []
      }
      return this.reportTypes.filter((t) => {
        return t.anonymous === true
      }).map((c) => {
        return c.type
      })
    },
    canSubmit () {
      if (this.$store.state.auth.authenticated) {
        return true
      }

      return this.allowedCategories.length > 0
    },
    targetDomain () {
      if (!this.target._obj) {
        return
      }
      let fid = this.target._obj.fid
      if (this.target.type === 'channel' && this.target._obj.actor) {
        fid = this.target._obj.actor.fid
      }
      if (!fid) {
        return this.$store.getters['instance/domain']
      }
      return urlDomain(fid)
    },
    isLocal () {
      return this.$store.getters['instance/domain'] === this.targetDomain
    }
  },
  watch: {
    '$store.state.moderation.showReportModal': function (v) {
      if (!v || this.$store.state.auth.authenticated) {
        return
      }

      const self = this
      self.isLoadingReportTypes = true
      axios.get('instance/nodeinfo/2.0/').then(response => {
        self.isLoadingReportTypes = false
        self.reportTypes = response.data.metadata.reportTypes || []
      }, error => {
        self.isLoadingReportTypes = false
        self.$store.commit('ui/addMessage', {
          content: 'Cannot fetch Node Info: ' + error,
          date: new Date()
        })
      })
    }
  },
  methods: {
    update (v) {
      this.$store.commit('moderation/showReportModal', v)
      this.errors = []
    },
    submit () {
      const self = this
      self.isLoading = true
      const payload = {
        target: { ...this.target, _obj: null },
        summary: this.summary,
        type: this.category,
        forward: this.forward
      }
      if (!this.$store.state.auth.authenticated) {
        payload.submitter_email = this.submitterEmail
      }
      return axios.post('moderation/reports/', payload).then(response => {
        self.update(false)
        self.isLoading = false
        const msg = this.$pgettext('*/Moderation/Message', 'Report successfully submitted, thank you')
        self.$store.commit('moderation/contentFilter', response.data)
        self.$store.commit('ui/addMessage', {
          content: msg,
          date: new Date()
        })
        self.summary = ''
        self.category = ''
      }, error => {
        self.errors = error.backendErrors
        self.isLoading = false
      })
    }
  }
}
</script>
