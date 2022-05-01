<template>
  <div
    ref="dropdown"
    class="ui multiple search selection dropdown"
  >
    <input type="hidden">
    <i class="dropdown icon" />
    <input
      id="tags-search"
      type="text"
      class="search"
    >
    <div class="default text">
      <translate translate-context="*/Dropdown/Placeholder/Verb">
        Search…
      </translate>
    </div>
  </div>
</template>
<script>
import $ from 'jquery'

import { isEqual } from 'lodash-es'
export default {
  props: { modelValue: { type: Array, required: true } },
  watch: {
    modelValue: {
      handler (v) {
        const current = $(this.$refs.dropdown).dropdown('get value').split(',').sort()
        if (!isEqual([...v].sort(), current)) {
          $(this.$refs.dropdown).dropdown('set exactly', v)
        }
      },
      deep: true
    }
  },
  mounted () {
    this.$nextTick(() => {
      this.initDropdown()
    })
  },
  methods: {
    initDropdown () {
      const self = this
      const handleUpdate = () => {
        const value = $(self.$refs.dropdown).dropdown('get value').split(',')
        self.$emit('update:modelValue', value)
        return value
      }
      const settings = {
        keys: {
          delimiter: 32
        },
        forceSelection: false,
        saveRemoteData: false,
        filterRemoteData: true,
        preserveHTML: false,
        apiSettings: {
          url: this.$store.getters['instance/absoluteUrl']('/api/v1/tags/?name__startswith={query}&ordering=length&page_size=5'),
          beforeXHR: function (xhrObject) {
            if (self.$store.state.auth.oauth.accessToken) {
              xhrObject.setRequestHeader('Authorization', self.$store.getters['auth/header'])
            }
            return xhrObject
          },
          onResponse (response) {
            const currentSearch = $(self.$refs.dropdown).dropdown('get query')
            response = {
              results: [],
              ...response
            }
            if (currentSearch) {
              const existingTag = response.results.find((result) => result.name === currentSearch)
              if (existingTag) {
                if (response.results.indexOf(existingTag) !== 0) {
                  response.results = [existingTag, ...response.results]
                  response.results.splice(response.results.indexOf(existingTag) + 1, 1)
                }
              } else {
                response.results = [{ name: currentSearch }, ...response.results]
              }
            }
            return response
          }
        },
        fields: {
          remoteValues: 'results',
          value: 'name'
        },
        allowAdditions: true,
        minCharacters: 1,
        onAdd: handleUpdate,
        onRemove: handleUpdate,
        onLabelRemove: handleUpdate,
        onChange: handleUpdate
      }
      $(this.$refs.dropdown).dropdown(settings)
      $(this.$refs.dropdown).dropdown('set exactly', this.modelValue)
    }
  }
}
</script>
