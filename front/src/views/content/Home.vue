<script setup lang="ts">
import { humanSize } from '~/utils/filters'
import { useI18n } from 'vue-i18n'
import { computed } from 'vue'
import { useStore } from '~/store'

const { t } = useI18n()

const labels = computed(() => ({
  title: t('Add and manage content')
}))

const store = useStore()
const quota = computed(() => store.state.instance.settings.users.upload_quota.value)
const defaultQuota = computed(() => humanSize(quota.value * 1e6))
</script>

<template>
  <section
    v-title="labels.title"
    class="ui vertical aligned stripe segment"
  >
    <div class="ui text container">
      <h1>{{ labels.title }}</h1>
      <p>
        <strong>{{ $t('This instance offers up to %{quota} of storage space for every user.', { quota: defaultQuota }) }}</strong>
      </p>
      <div class="ui segment">
        <h2>
          <i class="feed icon" />&nbsp;
          Publish your work in a channel
        </h2>
        <p>
          If you are a musician or a podcaster, channels are designed for you!&#32;            If you are a musician or a podcaster, channels are designed for you! work publicly and get subscribers on Funkwhale, the Fediverse or any podcasting application.
        </p>
        <router-link
          :to="{name: 'profile.overview', params: {username: store.state.auth.username}, hash: '#channels'}"
          class="ui primary button"
        >
          Get started
        </router-link>
      </div>
      <div class="ui segment">
        <h2>
          <i class="cloud icon" />&nbsp;
          Upload third-party content in a library
        </h2>
        <p>
          Upload your personal music library to Funkwhale to enjoy it from anywhere and share it with friends and family.
        </p>
        <router-link
          :to="{name: 'content.libraries.index'}"
          class="ui primary button"
        >
          Get started
        </router-link>
      </div>
      <div class="ui segment">
        <h2>
          <i class="download icon" />&nbsp;
          Follow remote libraries
        </h2>
        <p>
          Follow libraries from other users to get access to new music. Public libraries can be followed immediately, while following a private library requires approval from its owner.
        </p>
        <router-link
          :to="{name: 'content.remote.index'}"
          class="ui primary button"
        >
          Get started
        </router-link>
      </div>
    </div>
  </section>
</template>
