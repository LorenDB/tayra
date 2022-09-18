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
    title: t('components.ShortcutsModal.shortcut.general.label'),
    shortcuts: [
      {
        key: 'h',
        summary: t('components.ShortcutsModal.shortcut.general.show')
      },
      {
        key: 'shift + f',
        summary: t('components.ShortcutsModal.shortcut.general.focus')
      },
      {
        key: 'esc',
        summary: t('components.ShortcutsModal.shortcut.general.unfocus')
      }
    ]
  }
])

const player = computed(() => [
  {
    title: t('components.ShortcutsModal.shortcut.audio.label'),
    shortcuts: [
      {
        key: 'p',
        summary: t('components.ShortcutsModal.shortcut.audio.playPause')
      },
      {
        key: 'left',
        summary: t('components.ShortcutsModal.shortcut.audio.seekBack5')
      },
      {
        key: 'right',
        summary: t('components.ShortcutsModal.shortcut.audio.seekForward5')
      },
      {
        key: 'shift + left',
        summary: t('components.ShortcutsModal.shortcut.audio.seekBack30')
      },
      {
        key: 'shift + right',
        summary: t('components.ShortcutsModal.shortcut.audio.seekForward30')
      },
      {
        key: 'ctrl + shift + left',
        summary: t('components.ShortcutsModal.shortcut.audio.playPrevious')
      },
      {
        key: 'ctrl + shift + right',
        summary: t('components.ShortcutsModal.shortcut.audio.playNext')
      },
      {
        key: 'shift + up',
        summary: t('components.ShortcutsModal.shortcut.audio.increaseVolume')
      },
      {
        key: 'shift + down',
        summary: t('components.ShortcutsModal.shortcut.audio.decreaseVolume')
      },
      {
        key: 'm',
        summary: t('components.ShortcutsModal.shortcut.audio.toggleMute')
      },
      {
        key: 'e',
        summary: t('components.ShortcutsModal.shortcut.audio.expandQueue')
      },
      {
        key: 'l',
        summary: t('components.ShortcutsModal.shortcut.audio.toggleLoop')
      },
      {
        key: 's',
        summary: t('components.ShortcutsModal.shortcut.audio.shuffleQueue')
      },
      {
        key: 'q',
        summary: t('components.ShortcutsModal.shortcut.audio.clearQueue')
      },
      {
        key: 'f',
        summary: t('components.ShortcutsModal.shortcut.audio.toggleFavorite')
      }
    ]
  }
])
</script>

<template>
  <semantic-modal v-model:show="showRef">
    <header class="header">
      {{ $t('components.ShortcutsModal.header.modal') }}
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
        {{ $t('components.ShortcutsModal.button.close') }}
      </button>
    </footer>
  </semantic-modal>
</template>
