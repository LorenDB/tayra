<template>
  <div class="ui vertical aligned stripe segment">
    <div
      v-if="isLoading"
      :class="['ui', {'active': isLoading}, 'inverted', 'dimmer']"
    >
      <div class="ui text loader">
        <translate translate-context="Content/Library/Paragraph">
          Loading remote libraries…
        </translate>
      </div>
    </div>
    <div
      v-else
      class="ui text container"
    >
      <h1 class="ui header">
        <translate translate-context="Content/Library/Title/Noun">
          Remote libraries
        </translate>
      </h1>
      <p>
        <translate translate-context="Content/Library/Paragraph">
          Remote libraries are owned by other users on the network. You can access them as long as they are public or you are granted access.
        </translate>
      </p>
      <scan-form @scanned="scanResult = $event" />
      <div class="ui hidden divider" />
      <div
        v-if="scanResult && scanResult.results.length > 0"
        class="ui two cards"
      >
        <library-card
          v-for="library in scanResult.results"
          :key="library.fid"
          :initial-library="library"
        />
      </div>
      <template v-if="existingFollows && existingFollows.count > 0">
        <h2>
          <translate translate-context="Content/Library/Title">
            Known libraries
          </translate>
        </h2>
        <a
          href=""
          class="discrete link"
          @click.prevent="fetch()"
        >
          <i :class="['ui', 'circular', 'refresh', 'icon']" /> <translate translate-context="Content/*/Button.Label/Short, Verb">Refresh</translate>
        </a>
        <div class="ui hidden divider" />
        <div class="ui two cards">
          <library-card
            v-for="follow in existingFollows.results"
            :key="follow.fid"
            :initial-library="getLibraryFromFollow(follow)"
            @deleted="fetch()"
            @followed="fetch()"
          />
        </div>
      </template>
    </div>
  </div>
</template>

<script>
import axios from 'axios'
import ScanForm from './ScanForm'
import LibraryCard from './Card'

export default {
  components: {
    ScanForm,
    LibraryCard
  },
  data () {
    return {
      isLoading: false,
      scanResult: null,
      existingFollows: null,
      errors: []
    }
  },
  created () {
    this.fetch()
  },
  methods: {
    fetch () {
      this.isLoading = true
      const self = this
      axios.get('federation/follows/library/', { params: { page_size: 100, ordering: '-creation_date' } }).then((response) => {
        self.existingFollows = response.data
        self.existingFollows.results.forEach(f => {
          f.target.follow = f
        })
        self.isLoading = false
      }, error => {
        self.isLoading = false
        self.errors.push(error)
      })
    },
    getLibraryFromFollow (follow) {
      const d = follow.target
      d.follow = follow
      return d
    }
  }
}
</script>
