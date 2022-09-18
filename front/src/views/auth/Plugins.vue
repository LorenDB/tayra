<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { computed, ref } from 'vue'

import axios from 'axios'

import PluginForm from '~/components/auth/Plugin.vue'

import useErrorHandler from '~/composables/useErrorHandler'

const { t } = useI18n()

const labels = computed(() => ({
  title: t('views.auth.Plugins.title')
}))

const isLoading = ref(false)
const plugins = ref()
const libraries = ref()
const fetchData = async () => {
  isLoading.value = true

  try {
    const [pluginsResponse, librariesResponse] = await Promise.all([
      axios.get('plugins'),
      axios.get('libraries', { params: { scope: 'me', page_size: 50 } })
    ])

    plugins.value = pluginsResponse.data
    libraries.value = librariesResponse.data.results
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoading.value = false
}

fetchData()
</script>

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
