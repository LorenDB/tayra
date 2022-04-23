<template>
  <div :class="['ui', {loading: isLoading}, 'form']">
    <div class="ui required field">
      <label for="upload-title">
        <translate translate-context="*/*/*/Noun">Title</translate>
      </label>
      <input
        v-model="newValues.title"
        type="text"
      >
    </div>
    <attachment-input
      v-model="newValues.cover"
      :required="false"
      @delete="newValues.cover = null"
    >
      <translate
        slot="label"
        translate-context="Content/Channel/*"
      >
        Track Picture
      </translate>
    </attachment-input>
    <div class="ui small hidden divider" />
    <div class="ui two fields">
      <div class="ui field">
        <label for="upload-tags">
          <translate translate-context="*/*/*/Noun">Tags</translate>
        </label>
        <tags-selector
          id="upload-tags"
          v-model="newValues.tags"
          :required="false"
        />
      </div>
      <div class="ui field">
        <label for="upload-position">
          <translate translate-context="*/*/*/Short, Noun">Position</translate>
        </label>
        <input
          v-model="newValues.position"
          type="number"
          min="1"
          step="1"
        >
      </div>
    </div>
    <div class="ui field">
      <label for="upload-description">
        <translate translate-context="*/*/*">Description</translate>
      </label>
      <content-form
        v-model="newValues.description"
        field-id="upload-description"
      />
    </div>
  </div>
</template>

<script>
import TagsSelector from '~/components/library/TagsSelector.vue'
import AttachmentInput from '~/components/common/AttachmentInput.vue'

export default {
  components: {
    TagsSelector,
    AttachmentInput
  },
  props: {
    upload: { type: Object, required: true },
    values: { type: Object, required: true }
  },
  data () {
    return {
      newValues: { ...this.values } || this.upload.import_metadata
    }
  },
  computed: {
    isLoading () {
      return !!this.metadata
    }
  },
  watch: {
    newValues: {
      handler (v) {
        this.$emit('values', v)
      },
      immediate: true
    }
  }
}
</script>
