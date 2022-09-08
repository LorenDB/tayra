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
        <strong><translate

          :translate-params="{quota: defaultQuota}"
        >This instance offers up to %{quota} of storage space for every user.</translate></strong>
      </p>
      <div class="ui segment">
        <h2>
          <i class="feed icon" />&nbsp;
          <translate >
            Publish your work in a channel
          </translate>
        </h2>
        <p>
          <translate >
            If you are a musician or a podcaster, channels are designed for you!
          </translate>&#32;
          <translate >
            Share your work publicly and get subscribers on Funkwhale, the Fediverse or any podcasting application.
          </translate>
        </p>
        <router-link
          :to="{name: 'profile.overview', params: {username: store.state.auth.username}, hash: '#channels'}"
          class="ui primary button"
        >
          <translate >
            Get started
          </translate>
        </router-link>
      </div>
      <div class="ui segment">
        <h2>
          <i class="cloud icon" />&nbsp;
          <translate >
            Upload third-party content in a library
          </translate>
        </h2>
        <p>
          <translate >
            Upload your personal music library to Funkwhale to enjoy it from anywhere and share it with friends and family.
          </translate>
        </p>
        <router-link
          :to="{name: 'content.libraries.index'}"
          class="ui primary button"
        >
          <translate >
            Get started
          </translate>
        </router-link>
      </div>
      <div class="ui segment">
        <h2>
          <i class="download icon" />&nbsp;
          <translate >
            Follow remote libraries
          </translate>
        </h2>
        <p>
          <translate >
            Follow libraries from other users to get access to new music. Public libraries can be followed immediately, while following a private library requires approval from its owner.
          </translate>
        </p>
        <router-link
          :to="{name: 'content.remote.index'}"
          class="ui primary button"
        >
          <translate >
            Get started
          </translate>
        </router-link>
      </div>
    </div>
  </section>
</template>
