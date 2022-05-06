<script setup lang="ts">
import { useVModel } from '@vueuse/core'
import { range, clamp } from 'lodash-es'
import { computed } from 'vue'
import { useGettext } from 'vue3-gettext'

interface Props {
  current?: number
  paginateBy?: number
  total: number,
  compact?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  current: 1,
  paginateBy: 25,
  compact: false
})

const emit = defineEmits(['update:current', 'pageChanged'])
const current = useVModel(props, 'current', emit)

const RANGE = 2
const pages = computed(() => {
  const start = range(1, 1 + RANGE)
  const end = range(maxPage.value - RANGE, maxPage.value)
  const middle = range(
    clamp(props.current - RANGE + 1, 1, maxPage.value),
    clamp(props.current + RANGE, 1, maxPage.value)
  ).filter(i => !start.includes(i) && !end.includes(i))

  console.log(middle, end)

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
  // TODO (wvffle): Compat before change to v-model
  emit('pageChanged', page)
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
      <a
        v-for="page in pages"
        :key="page"
        href="#"
        :class="[{ active: page === current, disabled: page === 'skip' }, 'item']"
        @click.prevent.stop="page !== 'skip' && setPage(page)"
      >
        <span v-if="page !== 'skip'">{{ page }}</span>
        <span v-else>…</span>
      </a>
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
