<template>
  <section class="ui vertical aligned stripe segment">
    <div
      v-if="isLoading"
      :class="['ui', {'active': isLoading}, 'inverted', 'dimmer']"
    >
      <div class="ui text loader">
        <translate translate-context="Content/Library/Paragraph">
          Loading Libraries…
        </translate>
      </div>
    </div>
    <div
      v-else
      class="ui text container"
    >
      <h1 class="ui header">
        <translate translate-context="Content/Library/Title">
          My libraries
        </translate>
      </h1>

      <p v-if="libraries.length == 0">
        <translate translate-context="Content/Library/Paragraph">
          Looks like you don't have a library, it's time to create one.
        </translate>
      </p>
      <a
        :aria-expanded="!hiddenForm"
        href=""
        @click.prevent="hiddenForm = !hiddenForm"
      >
        <i
          v-if="hiddenForm"
          class="plus icon"
        />
        <i
          v-else
          class="minus icon"
        />
        <translate translate-context="Content/Library/Link/Verb">Create a new library</translate>
      </a>
      <library-form
        v-if="!hiddenForm"
        :library="null"
        @created="libraryCreated"
      />
      <div class="ui hidden divider" />
      <quota />
      <div class="ui hidden divider" />
      <div
        v-if="libraries.length > 0"
        class="ui two column grid"
      >
        <div
          v-for="library in libraries"
          :key="library.uuid"
          class="column"
        >
          <library-card :library="library" />
        </div>
      </div>
    </div>
  </section>
</template>

<script>
import axios from 'axios'
import LibraryForm from './Form'
import LibraryCard from './Card'
import Quota from './Quota'

export default {
  components: {
    LibraryForm,
    LibraryCard,
    Quota
  },
  data () {
    return {
      isLoading: false,
      hiddenForm: true,
      libraries: []
    }
  },
  created () {
    this.fetch()
  },
  methods: {
    fetch () {
      this.isLoading = true
      const self = this
      axios.get('libraries/', { params: { scope: 'me' } }).then(response => {
        self.isLoading = false
        self.libraries = response.data.results
        if (self.libraries.length === 0) {
          self.hiddenForm = false
        }
      })
    },
    libraryCreated (library) {
      this.$router.push({ name: 'library.detail', params: { id: library.uuid } })
    }
  }
}
</script>
