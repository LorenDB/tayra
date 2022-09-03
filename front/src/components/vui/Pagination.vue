<script setup lang="ts">
import { useVModel } from '@vueuse/core'
import { range, clamp } from 'lodash-es'
import { computed } from 'vue'
import { useGettext } from 'vue3-gettext'

const RANGE = 2

interface Events {
  (e: 'update:current', page: number): void
}

interface Props {
  current?: number
  paginateBy?: number
  total: number,
  compact?: boolean
}

const emit = defineEmits<Events>()
const props = withDefaults(defineProps<Props>(), {
  current: 1,
  paginateBy: 25,
  compact: false
})

const current = useVModel(props, 'current', emit)

const pages = computed(() => {
  const start = range(1, 1 + RANGE)
  const end = range(maxPage.value - RANGE + 1, maxPage.value + 1)
  const middle = range(
    clamp(props.current - RANGE + 1, 1, maxPage.value),
    clamp(props.current + RANGE, 1, maxPage.value)
  ).filter(i => !start.includes(i) && !end.includes(i))

  if (end[0] - 1 <= start[RANGE - 1]) {
    return [
      ...start,
      ...end.filter(i => i > start[RANGE - 1])
    ]
  }

  return [
    ...start,
    middle.length === 0 && 'skip',
    middle.length !== 0 && start[start.length - 1] + 1 !== middle[0] && 'skip',
    ...middle,
    middle.length !== 0 && middle[middle.length - 1] + 1 !== end[0] && 'skip',
    ...end
  ].filter(i => i !== false) as Array<'skip' | number>
})

const maxPage = computed(() => Math.ceil(props.total / props.paginateBy))

const setPage = (page: number) => {
  if (page > maxPage.value || page < 1) {
    return
  }

  current.value = page
}

const { $pgettext } = useGettext()
const labels = computed(() => ({
  pagination: $pgettext('Content/*/Hidden text/Noun', 'Pagination'),
  previousPage: $pgettext('Content/*/Link', 'Previous Page'),
  nextPage: $pgettext('Content/*/Link', 'Next Page')
}))
</script>

<template>
  <div
    v-if="maxPage > 1"
    class="ui pagination menu component-pagination"
    role="navigation"
    :aria-label="labels.pagination"
  >
    <a
      href="#"
      :disabled="current - 1 < 1 || null"
      role="button"
      :aria-label="labels.previousPage"
      :class="[{ 'disabled': current - 1 < 1 }, 'item']"
      @click.prevent.stop="setPage(current - 1)"
    >
      <i class="angle left icon" />
    </a>

    <template v-if="!compact">
      <template
        v-for="page in pages"
        :key="page"
      >
        <a
          v-if="page === 'skip'"
          href="#"
          class="item disabled"
        >
          <span>…</span>
        </a>
        <a
          v-else
          href="#"
          :class="[{ active: page === current }, 'item']"
          @click.prevent.stop="setPage(page as number)"
        >
          <span>{{ page }}</span>
        </a>
      </template>
    </template>

    <a
      href="#"
      :disabled="current + 1 > maxPage || null"
      role="button"
      :aria-label="labels.nextPage"
      :class="[{ disabled: current + 1 > maxPage }, 'item']"
      @click.prevent.stop="setPage(current + 1)"
    >
      <i class="angle right icon" />
    </a>
  </div>
</template>
