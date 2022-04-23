<template>
  <main
    v-title="labels.title"
    class="main pusher"
  >
    <section class="ui vertical stripe segment">
      <div class="ui small text container">
        <h2>{{ labels.title }}</h2>
        <div
          v-if="isLoading"
          class="ui inverted active dimmer"
        >
          <div class="ui loader" />
        </div>

        <template v-if="plugins && plugins.length > 0">
          <plugin-form
            v-for="plugin in plugins"
            :key="plugin.name"
            :plugin="plugin"
            :libraries="libraries"
          />
        </template>
        <empty-state v-else />
      </div>
    </section>
  </main>
</template>

<script>
import axios from 'axios'
import PluginForm from '~/components/auth/Plugin.vue'

export default {
  components: {
    PluginForm
  },
  data () {
    return {
      isLoading: true,
      plugins: null,
      libraries: null
    }
  },
  computed: {
    labels () {
      const title = this.$pgettext('Head/Login/Title', 'Manage plugins')
      return {
        title
      }
    }
  },
  async created () {
    await this.fetchData()
  },
  methods: {
    async fetchData () {
      this.isLoading = true
      let response = await axios.get('plugins')
      this.plugins = response.data
      response = await axios.get('libraries', { paramis: { scope: 'me', page_size: 50 } })
      this.libraries = response.data.results
      this.isLoading = false
    }
  }
}
</script>
