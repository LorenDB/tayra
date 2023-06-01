<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'

const path = window.location.href

const { t } = useI18n()
const labels = computed(() => ({
  title: t('components.PageNotFound.title')
}))
</script>

<template>
  <main
    class="main pusher"
    :v-title="labels.title"
  >
    <section class="ui vertical stripe segment">
      <div class="ui text container">
        <h1 class="ui huge header">
          <i class="warning icon" />
          <div class="content">
            {{ $t('components.PageNotFound.header.pageNotFound') }}
          </div>
        </h1>
        <p>
          {{ $t('components.PageNotFound.message.pageNotFound') }}
        </p>
        <a :href="path">{{ path }}</a>
        <div class="ui hidden divider" />
        <router-link
          class="ui icon labeled right button"
          to="/"
        >
          {{ $t('components.PageNotFound.link.home') }}
          <i class="right arrow icon" />
        </router-link>
      </div>
    </section>
  </main>
</template>
