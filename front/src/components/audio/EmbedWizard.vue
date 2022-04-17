<template>
  <div>
    <div
      v-if="!anonymousCanListen"
      role="alert"
      class="ui warning message"
    >
      <p>
        <strong>
          <translate translate-context="Content/Embed/Message">Sharing will not work because this pod doesn't allow anonymous users to access content.</translate>
        </strong>
      </p>
      <p>
        <translate translate-context="Content/Embed/Message">
          Please contact your admins and ask them to update the corresponding setting.
        </translate>
      </p>
    </div>
    <div class="ui form">
      <div class="two fields">
        <div class="field">
          <div class="field">
            <label for="embed-width"><translate translate-context="Popup/Embed/Input.Label">Widget width</translate></label>
            <p>
              <translate translate-context="Popup/Embed/Paragraph">
                Leave empty for a responsive widget
              </translate>
            </p>
            <input
              id="embed-width"
              v-model.number="width"
              type="number"
              min="0"
              step="10"
            >
          </div>
          <template v-if="type != 'track'">
            <br>
            <div class="field">
              <label for="embed-height"><translate translate-context="Popup/Embed/Input.Label">Widget height</translate></label>
              <input
                id="embed-height"
                v-model="height"
                type="number"
                :min="minHeight"
                max="1000"
                step="10"
              >
            </div>
          </template>
        </div>
        <div class="field">
          <button
            class="ui right accent labeled icon floated button"
            @click="copy"
          >
            <i class="copy icon" /><translate translate-context="*/*/Button.Label/Short, Verb">
              Copy
            </translate>
          </button>
          <label for="embed-width"><translate translate-context="Popup/Embed/Input.Label/Noun">Embed code</translate></label>
          <p>
            <translate translate-context="Popup/Embed/Paragraph">
              Copy/paste this code in your website HTML
            </translate>
          </p>
          <textarea
            ref="textarea"
            :value="embedCode"
            rows="5"
            readonly
          />
          <div class="ui right">
            <p
              v-if="copied"
              class="message"
            >
              <translate translate-context="Content/*/Paragraph">
                Text copied to clipboard!
              </translate>
            </p>
          </div>
        </div>
      </div>
    </div>
    <div class="preview">
      <h3>
        <a
          :href="iframeSrc"
          target="_blank"
        >
          <translate translate-context="Popup/Embed/Title/Noun">Preview</translate>
        </a>
      </h3>
      <iframe
        :width="frameWidth"
        :height="height"
        scrolling="no"
        frameborder="no"
        :src="iframeSrc"
      />
    </div>
  </div>
</template>

<script>

import { mapState } from 'vuex'
import { get } from 'lodash-es'

export default {
  props: {
    type: { type: String, required: true },
    id: { type: Number, required: true }
  },
  data () {
    const d = {
      width: null,
      height: 150,
      minHeight: 100,
      copied: false
    }
    if (this.type === 'album' || this.type === 'artist' || this.type === 'playlist') {
      d.height = 330
      d.minHeight = 250
    }
    return d
  },
  computed: {
    ...mapState({
      nodeinfo: state => state.instance.nodeinfo
    }),
    anonymousCanListen () {
      return get(this.nodeinfo, 'metadata.library.anonymousCanListen', false)
    },
    iframeSrc () {
      let base = import.meta.env.BASE_URL
      if (base.startsWith('/')) {
        // include hostname/protocol too so that the iframe link is absolute
        base = `${window.location.protocol}//${window.location.host}${base}`
      }
      const instanceUrl = this.$store.state.instance.instanceUrl
      let b = ''
      if (!window.location.href.startsWith(instanceUrl)) {
        // the frontend is running on a separate domain, so we need to provide
        // the b= parameter in the iframe
        b = `&b=${instanceUrl}`
      }
      return `${base}embed.html?&type=${this.type}&id=${this.id}${b}`
    },
    frameWidth () {
      if (this.width) {
        return this.width
      }
      return '100%'
    },
    embedCode () {
      const src = this.iframeSrc.replace(/&/g, '&amp;')
      return `<iframe width="${this.frameWidth}" height="${this.height}" scrolling="no" frameborder="no" src="${src}"></iframe>`
    }
  },
  methods: {
    copy () {
      this.$refs.textarea.select()
      document.execCommand('Copy')
      const self = this
      self.copied = true
      this.timeout = setTimeout(() => {
        self.copied = false
      }, 5000)
    }
  }
}
</script>
