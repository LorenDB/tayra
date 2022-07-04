<script setup lang="ts">
import { get } from 'lodash-es'
import { ref, computed } from 'vue'
import { useStore } from '~/store'
import { useClipboard } from '@vueuse/core'

interface Props {
  type: string
  id: string
}

const props = defineProps<Props>()
const width = ref(null)
const height = ref(150)
const minHeight = ref(100)

if (props.type === 'album' || props.type === 'artist' || props.type === 'playlist') {
  height.value = 330
  minHeight.value = 250
}

const store = useStore()
const nodeinfo = computed(() => store.state.instance.nodeinfo)
const anonymousCanListen = computed(() => get(nodeinfo.value, 'metadata.library.anonymousCanListen', false))
const iframeSrc = computed(() => {
  const base = import.meta.env.BASE_URL.startsWith('/')
    ? `${window.location.origin}${import.meta.env.BASE_URL}`
    : import.meta.env.BASE_URL

  const instanceUrl = store.state.instance.instanceUrl as string

  const bParam = !window.location.href.startsWith(instanceUrl)
    ? `&b=${instanceUrl}`
    : ''
  
  return `${base}embed.html?&type=${props.type}&id=${props.id}${bParam}`
})

const frameWidth = computed(() => width.value ?? '100%')
const embedCode = computed(() => `<iframe width="${frameWidth.value}" height="${height.value}" scrolling="no" frameborder="no" src="${iframeSrc.value.replace(/&/g, '&amp;')}"></iframe>`)

const textarea = ref()
const { copy, copied } = useClipboard({ source: textarea })
</script>

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
            @click="copy()"
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
