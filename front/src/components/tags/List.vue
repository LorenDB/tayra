<template>
  <div class="component-tags-list">
    <router-link
      v-for="tag in toDisplay"
      :key="tag"
      :to="{name: detailRoute, params: {id: tag}}"
      :class="['ui', 'circular', 'hashtag', 'label', labelClasses]"
    >
      #{{ tag|truncate(truncateSize) }}
    </router-link>
    <div
      v-if="showMore && toDisplay.length < tags.length"
      role="button"
      class="ui circular inverted accent label"
      @click.prevent="honorLimit = false"
    >
      <translate
        translate-context="Content/*/Button/Label/Verb"
        :translate-params="{count: tags.length - toDisplay.length}"
        :translate-n="tags.length - toDisplay.length"
        translate-plural="Show %{ count } more tags"
      >
        Show 1 more tag
      </translate>
    </div>
  </div>
</template>
<script>
export default {
  props: {
    tags: { type: Array, required: true },
    showMore: { type: Boolean, default: true },
    truncateSize: { type: Number, default: 25 },
    limit: { type: Number, default: 5 },
    labelClasses: { type: String, default: '' },
    detailRoute: { type: String, default: 'library.tags.detail' }
  },
  data () {
    return {
      honorLimit: true
    }
  },
  computed: {
    toDisplay () {
      if (!this.honorLimit) {
        return this.tags
      }
      return (this.tags || []).slice(0, this.limit)
    }
  }
}
</script>
