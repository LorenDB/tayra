<script setup lang="ts">
import { computed } from 'vue'
import { useGettext } from 'vue3-gettext'

const { $pgettext } = useGettext()
const labels = computed(() => ({
  title: $pgettext('Head/Admin/Title', 'Manage library'),
  secondaryMenu: $pgettext('Menu/*/Hidden text', 'Secondary menu')
}))
</script>

<template>
  <div
    v-title="labels.title"
    class="main pusher page-admin-library"
  >
    <nav
      class="ui secondary pointing menu"
      role="navigation"
      :aria-label="labels.secondaryMenu"
    >
      <router-link
        class="ui item"
        :to="{name: 'manage.library.edits'}"
      >
        <translate translate-context="*/Admin/*/Noun">
          Edits
        </translate>
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.channels'}"
      >
        <translate translate-context="*/*/*">
          Channels
        </translate>
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.library.artists'}"
      >
        <translate translate-context="*/*/*/Noun">
          Artists
        </translate>
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.library.albums'}"
      >
        <translate translate-context="*/*/*">
          Albums
        </translate>
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.library.tracks'}"
      >
        <translate translate-context="*/*/*">
          Tracks
        </translate>
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.library.libraries'}"
      >
        <translate translate-context="*/*/*/Noun">
          Libraries
        </translate>
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.library.uploads'}"
      >
        <translate translate-context="*/*/*">
          Uploads
        </translate>
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.library.tags'}"
      >
        <translate translate-context="*/*/*/Noun">
          Tags
        </translate>
      </router-link>
    </nav>
    <router-view :key="$route.fullPath" />
  </div>
</template>
