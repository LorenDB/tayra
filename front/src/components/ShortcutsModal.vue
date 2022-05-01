<script setup lang="ts">
import Modal from '~/components/semantic/Modal.vue'
import { useVModel } from '@vueuse/core'
import { computed } from 'vue'
import { useGettext } from 'vue3-gettext'

interface Props {
  show: boolean
}

const props = defineProps<Props>()
const emit = defineEmits(['update:show'])
const showRef = useVModel(props, 'show', emit)

const { $pgettext } = useGettext()
const general = computed(() => [
  {
    title: $pgettext('Popup/Keyboard shortcuts/Title', 'General shortcuts'),
    shortcuts: [
      {
        key: 'h',
        summary: $pgettext('Popup/Keyboard shortcuts/Table.Label/Verb', 'Show available keyboard shortcuts')
      },
      {
        key: 'shift + f',
        summary: $pgettext('Popup/Keyboard shortcuts/Table.Label/Verb', 'Focus searchbar')
      },
      {
        key: 'esc',
        summary: $pgettext('Popup/Keyboard shortcuts/Table.Label/Verb', 'Unfocus searchbar')
      }
    ]
  }
])

const player = computed(() => [
  {
    title: $pgettext('Popup/Keyboard shortcuts/Title', 'Audio player shortcuts'),
    shortcuts: [
      {
        key: 'p',
        summary: $pgettext('Popup/Keyboard shortcuts/Table.Label/Verb', 'Pause/play the current track')
      },
      {
        key: 'left',
        summary: $pgettext('Popup/Keyboard shortcuts/Table.Label/Verb', 'Seek backwards 5s')
      },
      {
        key: 'right',
        summary: $pgettext('Popup/Keyboard shortcuts/Table.Label/Verb', 'Seek forwards 5s')
      },
      {
        key: 'shift + left',
        summary: $pgettext('Popup/Keyboard shortcuts/Table.Label/Verb', 'Seek backwards 30s')
      },
      {
        key: 'shift + right',
        summary: $pgettext('Popup/Keyboard shortcuts/Table.Label/Verb', 'Seek forwards 30s')
      },
      {
        key: 'ctrl + shift + left',
        summary: $pgettext('Popup/Keyboard shortcuts/Table.Label/Verb', 'Play previous track')
      },
      {
        key: 'ctrl + shift + right',
        summary: $pgettext('Popup/Keyboard shortcuts/Table.Label/Verb', 'Play next track')
      },
      {
        key: 'shift + up',
        summary: $pgettext('Popup/Keyboard shortcuts/Table.Label/Verb', 'Increase volume')
      },
      {
        key: 'shift + down',
        summary: $pgettext('Popup/Keyboard shortcuts/Table.Label/Verb', 'Decrease volume')
      },
      {
        key: 'm',
        summary: $pgettext('Popup/Keyboard shortcuts/Table.Label/Verb', 'Toggle mute')
      },
      {
        key: 'e',
        summary: $pgettext('Popup/Keyboard shortcuts/Table.Label/Verb', 'Expand queue/player view')
      },
      {
        key: 'l',
        summary: $pgettext('Popup/Keyboard shortcuts/Table.Label/Verb', 'Toggle queue looping')
      },
      {
        key: 's',
        summary: $pgettext('Popup/Keyboard shortcuts/Table.Label/Verb', 'Shuffle queue')
      },
      {
        key: 'q',
        summary: $pgettext('Popup/Keyboard shortcuts/Table.Label/Verb', 'Clear queue')
      },
      {
        key: 'f',
        summary: $pgettext('Popup/Keyboard shortcuts/Table.Label/Verb', 'Toggle favorite')
      }
    ]
  }
])
</script>

<template>
  <modal v-model:show="showRef">
    <header class="header">
      <translate translate-context="*/*/*/Noun">
        Keyboard shortcuts
      </translate>
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
        <translate translate-context="*/*/Button.Label/Verb">
          Close
        </translate>
      </button>
    </footer>
  </modal>
</template>
