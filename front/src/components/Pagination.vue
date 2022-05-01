<template>
  <div
    v-if="maxPage > 1"
    class="ui pagination menu component-pagination"
    role="navigation"
    :aria-label="labels.pagination"
  >
    <a
      href
      :disabled="current - 1 < 1 || null"
      role="button"
      :aria-label="labels.previousPage"
      :class="[{'disabled': current - 1 < 1}, 'item']"
      @click.prevent.stop="selectPage(current - 1)"
    ><i class="angle left icon" /></a>
    <template v-if="!compact">
      <a
        v-for="page in pages"
        :key="page"
        href
        :class="[{'active': page === current}, {'disabled': page === 'skip'}, 'item']"
        @click.prevent.stop="selectPage(page)"
      >
        <span v-if="page !== 'skip'">{{ page }}</span>
        <span v-else>…</span>
      </a>
    </template>
    <a
      href
      :disabled="current + 1 > maxPage || null"
      role="button"
      :aria-label="labels.nextPage"
      :class="[{'disabled': current + 1 > maxPage}, 'item']"
      @click.prevent.stop="selectPage(current + 1)"
    ><i class="angle right icon" /></a>
  </div>
</template>

<script>
import { range as lodashRange, sortBy, uniq } from 'lodash-es'

export default {
  props: {
    current: { type: Number, default: 1 },
    paginateBy: { type: Number, default: 25 },
    total: { type: Number, required: true },
    compact: { type: Boolean, default: false }
  },
  computed: {
    labels () {
      return {
        pagination: this.$pgettext('Content/*/Hidden text/Noun', 'Pagination'),
        previousPage: this.$pgettext('Content/*/Link', 'Previous Page'),
        nextPage: this.$pgettext('Content/*/Link', 'Next Page')
      }
    },
    pages: function () {
      const range = 2
      const current = this.current
      const beginning = lodashRange(1, Math.min(this.maxPage, 1 + range))
      const middle = lodashRange(
        Math.max(1, current - range + 1),
        Math.min(this.maxPage, current + range)
      )
      const end = lodashRange(this.maxPage, Math.max(1, this.maxPage - range))
      let allowed = beginning.concat(middle, end)
      allowed = uniq(allowed)
      allowed = sortBy(allowed, [
        e => {
          return e
        }
      ])
      const final = []
      allowed.forEach(p => {
        const last = final.slice(-1)[0]
        let consecutive = true
        if (last === 'skip') {
          consecutive = false
        } else {
          if (!last) {
            consecutive = true
          } else {
            consecutive = last + 1 === p
          }
        }
        if (consecutive) {
          final.push(p)
        } else {
          if (p !== 'skip') {
            final.push('skip')
            final.push(p)
          }
        }
      })
      return final
    },
    maxPage: function () {
      return Math.ceil(this.total / this.paginateBy)
    }
  },
  methods: {
    selectPage: function (page) {
      if (page > this.maxPage || page < 1) {
        return
      }
      if (this.current !== page) {
        this.$emit('page-changed', page)
      }
    }
  }
}
</script>
