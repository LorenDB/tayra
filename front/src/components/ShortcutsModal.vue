<script setup lang="ts">
import SemanticModal from '~/components/semantic/Modal.vue'
import { useVModel } from '@vueuse/core'
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'

interface Events {
  (e: 'update:show', show: boolean): void
}

interface Props {
  show: boolean
}

const emit = defineEmits<Events>()
const props = defineProps<Props>()

const showRef = useVModel(props, 'show', emit)

const { t } = useI18n()
const general = computed(() => [
  {
    title: t('General shortcuts'),
    shortcuts: [
      {
        key: 'h',
        summary: t('Show available keyboard shortcuts')
      },
      {
        key: 'shift + f',
        summary: t('Focus searchbar')
      },
      {
        key: 'esc',
        summary: t('Unfocus searchbar')
      }
    ]
  }
])

const player = computed(() => [
  {
    title: t('Audio player shortcuts'),
    shortcuts: [
      {
        key: 'p',
        summary: t('Pause/play the current track')
      },
      {
        key: 'left',
        summary: t('Seek backwards 5s')
      },
      {
        key: 'right',
        summary: t('Seek forwards 5s')
      },
      {
        key: 'shift + left',
        summary: t('Seek backwards 30s')
      },
      {
        key: 'shift + right',
        summary: t('Seek forwards 30s')
      },
      {
        key: 'ctrl + shift + left',
        summary: t('Play previous track')
      },
      {
        key: 'ctrl + shift + right',
        summary: t('Play next track')
      },
      {
        key: 'shift + up',
        summary: t('Increase volume')
      },
      {
        key: 'shift + down',
        summary: t('Decrease volume')
      },
      {
        key: 'm',
        summary: t('Toggle mute')
      },
      {
        key: 'e',
        summary: t('Expand queue/player view')
      },
      {
        key: 'l',
        summary: t('Toggle queue looping')
      },
      {
        key: 's',
        summary: t('Shuffle queue')
      },
      {
        key: 'q',
        summary: t('Clear queue')
      },
      {
        key: 'f',
        summary: t('Toggle favorite')
      }
    ]
  }
])
</script>

<template>
  <semantic-modal v-model:show="showRef">
    <header class="header">
      Keyboard shortcuts
    </header>
    <section class="scrolling content">
      <div class="ui stackable two column grid">
        <div class="column">
          <table
            v-for="section in player"
            :key="section.title"
            class="ui compact basic table"
          >
            <caption>{{ section.title }}</caption>
            <tbody>
              <tr
                v-for="shortcut in section.shortcuts"
                :key="shortcut.summary"
              >
                <td>{{ shortcut.summary }}</td>
                <td><span class="ui label">{{ shortcut.key }}</span></td>
              </tr>
            </tbody>
          </table>
        </div>
        <div class="column">
          <table
            v-for="section in general"
            :key="section.title"
            class="ui compact basic table"
          >
            <caption>{{ section.title }}</caption>
            <tbody>
              <tr
                v-for="shortcut in section.shortcuts"
                :key="shortcut.summary"
              >
                <td>{{ shortcut.summary }}</td>
                <td><span class="ui label">{{ shortcut.key }}</span></td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </section>
    <footer class="actions">
      <button class="ui basic cancel button">
        Close
      </button>
    </footer>
  </semantic-modal>
</template>
