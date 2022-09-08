<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'

const path = window.location.href

const { t } = useI18n()
const labels = computed(() => ({
  title: t('Page Not Found')
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
            <translate >
              Page not found!
            </translate>
          </div>
        </h1>
        <p>
          <translate >
            Sorry, the page you asked for does not exist:
          </translate>
        </p>
        <a :href="path">{{ path }}</a>
        <div class="ui hidden divider" />
        <router-link
          class="ui icon labeled right button"
          to="/"
        >
          <translate >
            Go to home page
          </translate>
          <i class="right arrow icon" />
        </router-link>
      </div>
    </section>
  </main>
</template>
