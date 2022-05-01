<template>
  <modal
    v-model:show="showRef"
    @update:show="isError = false"
  >
    <h3 class="header">
      <translate translate-context="Popup/Instance/Title">
        Choose your instance
      </translate>
    </h3>
    <div class="scrolling content">
      <div
        v-if="isError"
        role="alert"
        class="ui negative message"
      >
        <h4 class="header">
          <translate translate-context="Popup/Instance/Error message.Title">
            It is not possible to connect to the given URL
          </translate>
        </h4>
        <ul class="list">
          <li>
            <translate translate-context="Popup/Instance/Error message.List item">
              The server might be down
            </translate>
          </li>
          <li>
            <translate translate-context="Popup/Instance/Error message.List item">
              The given address is not a Funkwhale server
            </translate>
          </li>
        </ul>
      </div>
      <form
        class="ui form"
        @submit.prevent="checkAndSwitch(instanceUrl)"
      >
        <p
          v-if="$store.state.instance.instanceUrl"
          v-translate="{url: $store.state.instance.instanceUrl, hostname: instanceHostname }"
          class="description"
          translate-context="Popup/Login/Paragraph"
        >
          You are currently connected to <a
            href="%{ url }"
            target="_blank"
          >%{ hostname }&nbsp;<i class="external icon" /></a>. If you continue, you will be disconnected from your current instance and all your local data will be deleted.
        </p>
        <p v-else>
          <translate translate-context="Popup/Instance/Paragraph">
            To continue, please select the Funkwhale instance you want to connect to. Enter the address directly, or select one of the suggested choices.
          </translate>
        </p>
        <div class="field">
          <label for="instance-picker"><translate translate-context="Popup/Instance/Input.Label/Noun">Instance URL</translate></label>
          <div class="ui action input">
            <input
              id="instance-picker"
              v-model="instanceUrl"
              type="text"
              placeholder="https://funkwhale.server"
            >
            <button
              type="submit"
              :class="['ui', 'icon', {loading: isLoading}, 'button']"
            >
              <translate translate-context="*/*/Button.Label/Verb">
                Submit
              </translate>
            </button>
          </div>
        </div>
      </form>
      <div class="ui hidden divider" />
      <form
        class="ui form"
        @submit.prevent=""
      >
        <div class="field">
          <h4>
            <translate translate-context="Popup/Instance/List.Label">
              Suggested choices
            </translate>
          </h4>
          <button
            v-for="(url, key) in suggestedInstances"
            :key="key"
            class="ui basic button"
            @click="checkAndSwitch(url)"
          >
            {{ url }}
          </button>
        </div>
      </form>
    </div>
    <div class="actions">
      <button class="ui basic cancel button">
        <translate translate-context="*/*/Button.Label/Verb">
          Cancel
        </translate>
      </button>
    </div>
  </modal>
</template>

<script>
import Modal from '~/components/semantic/Modal.vue'
import axios from 'axios'
import { uniq } from 'lodash-es'
import { useVModel } from '@vueuse/core'

export default {
  components: {
    Modal
  },
  props: { show: { type: Boolean, required: true } },
  setup (props) {
    // TODO (wvffle): Add defineEmits when rewriting to <script setup>
    const showRef = useVModel(props, 'show'/*, emit*/)
    return { showRef }
  },
  data () {
    return {
      instanceUrl: null,
      nodeinfo: null,
      isError: false,
      isLoading: false,
      path: 'api/v1/instance/nodeinfo/2.0/'
    }
  },
  computed: {
    suggestedInstances () {
      const instances = this.$store.state.instance.knownInstances.slice(0)
      if (this.$store.state.instance.frontSettings.defaultServerUrl) {
        let serverUrl = this.$store.state.instance.frontSettings.defaultServerUrl
        if (!serverUrl.endsWith('/')) {
          serverUrl = serverUrl + '/'
        }
        instances.push(serverUrl)
      }
      const self = this
      instances.push(this.$store.getters['instance/defaultUrl'](), 'https://demo.funkwhale.audio/')
      return uniq(instances.filter((e) => { return e !== self.$store.state.instance.instanceUrl }))
    },
    instanceHostname () {
      const url = this.$store.state.instance.instanceUrl
      const parser = document.createElement('a')
      parser.href = url
      return parser.hostname
    }
  },
  watch: {
    '$store.state.instance.instanceUrl' () {
      this.$store.dispatch('instance/fetchSettings')
      this.fetchNodeInfo()
    }
  },
  methods: {
    fetchNodeInfo () {
      const self = this
      axios.get('instance/nodeinfo/2.0/').then(response => {
        self.nodeinfo = response.data
      })
    },
    fetchUrl (url) {
      let urlFetch = url
      if (!urlFetch.endsWith('/')) {
        urlFetch = `${urlFetch}/${this.path}`
      } else {
        urlFetch = `${urlFetch}${this.path}`
      }
      if (!urlFetch.startsWith('https://') && !urlFetch.startsWith('http://')) {
        urlFetch = `https://${urlFetch}`
      }
      return urlFetch
    },
    requestDistantNodeInfo (url) {
      const self = this
      axios.get(this.fetchUrl(url)).then(function (response) {
        self.isLoading = false
        if (!url.startsWith('https://') && !url.startsWith('http://')) {
          url = `https://${url}`
        }
        self.switchInstance(url)
      }).catch(function () {
        self.isLoading = false
        self.isError = true
      })
    },
    switchInstance (url) {
      // Here we disconnect from the current instance and reconnect to the new one. No check is performed…
      this.$emit('update:show', false)
      this.isError = false
      const msg = this.$pgettext('*/Instance/Message', 'You are now using the Funkwhale instance at %{ url }')
      this.$store.commit('ui/addMessage', {
        content: this.$gettextInterpolate(msg, { url: url }),
        date: new Date()
      })
      const self = this
      this.$nextTick(() => {
        self.$store.commit('instance/instanceUrl', null)
        self.$store.dispatch('instance/setUrl', url)
      })
    },
    checkAndSwitch (url) {
      // First we have to check if the address is a valid FW server. If yes, we switch:
      this.isError = false // Clear error message if any…
      this.isLoading = true
      this.requestDistantNodeInfo(url)
    }
  }
}
</script>
