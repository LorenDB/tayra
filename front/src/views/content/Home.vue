<script setup lang="ts">
import { humanSize } from '~/utils/filters'
import { useI18n } from 'vue-i18n'
import { computed } from 'vue'
import { useStore } from '~/store'

const { t } = useI18n()

const labels = computed(() => ({
  title: t('views.content.Home.title')
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
        <strong>{{ $t('views.content.Home.uploadQuota', { quota: defaultQuota }) }}</strong>
      </p>
      <div class="ui segment">
        <h2>
          <i class="feed icon" />&nbsp;
          {{ $t('views.content.Home.channelHeader') }}
        </h2>
        <p>
          {{ $t('views.content.Home.channelDescription') }}&#32;{{ $t('views.content.Home.channelDescriptionContinued') }}
        </p>
        <router-link
          :to="{name: 'profile.overview', params: {username: store.state.auth.username}, hash: '#channels'}"
          class="ui primary button"
        >
          {{ $t('views.content.Home.getStartedButton') }}
        </router-link>
      </div>
      <div class="ui segment">
        <h2>
          <i class="cloud icon" />&nbsp;
          {{ $t('views.content.Home.libraryUploadHeader') }}
        </h2>
        <p>
          {{ $t('views.content.Home.libraryUploadDescription') }}
        </p>
        <router-link
          :to="{name: 'content.libraries.index'}"
          class="ui primary button"
        >
          {{ $t('views.content.Home.getStartedButton') }}
        </router-link>
      </div>
      <div class="ui segment">
        <h2>
          <i class="download icon" />&nbsp;
          {{ $t('views.content.Home.followLibrariesHeader') }}
        </h2>
        <p>
          {{ $t('views.content.Home.followLibrariesDescription') }}
        </p>
        <router-link
          :to="{name: 'content.remote.index'}"
          class="ui primary button"
        >
          {{ $t('views.content.Home.getStartedButton') }}
        </router-link>
      </div>
    </div>
  </section>
</template>
