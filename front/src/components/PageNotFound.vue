<script setup lang="ts">
import { computed } from 'vue'
import { useGettext } from 'vue3-gettext'

const path = window.location.href

const { $pgettext } = useGettext()
const labels = computed(() => ({ 
  title: $pgettext('Head/*/Title', 'Page Not Found')
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
            <translate translate-context="Content/*/Title">
              Page not found!
            </translate>
          </div>
        </h1>
        <p>
          <translate translate-context="Content/*/Paragraph">
            Sorry, the page you asked for does not exist:
          </translate>
        </p>
        <a :href="path">{{ path }}</a>
        <div class="ui hidden divider" />
        <router-link
          class="ui icon labeled right button"
          to="/"
        >
          <translate translate-context="Content/*/Button.Label/Verb">
            Go to home page
          </translate>
          <i class="right arrow icon" />
        </router-link>
      </div>
    </section>
  </main>
</template>
