<script setup lang="ts">
import { get } from 'lodash-es'
import { ref, computed } from 'vue'
import { useStore } from '~/store'
import { useClipboard } from '@vueuse/core'

interface Props {
  type: string
  id: number
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
          Sharing will not work because this pod doesn't allow anonymous users to access content.
        </strong>
      </p>
      <p>
        Please contact your admins and ask them to update the corresponding setting.
      </p>
    </div>
    <div class="ui form">
      <div class="two fields">
        <div class="field">
          <div class="field">
            <label for="embed-width">Widget width</label>
            <p>
              Leave empty for a responsive widget
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
              <label for="embed-height">Widget height</label>
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
            <i class="copy icon" />              Copy
          </button>
          <label for="embed-width">Embed code</label>
          <p>
            Copy/paste this code in your website HTML
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
              Text copied to clipboard!
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
          Preview
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
