<script setup lang="ts">
import { get } from 'lodash-es'
import AlbumWidget from '~/components/audio/album/Widget.vue'
import ChannelsWidget from '~/components/audio/ChannelsWidget.vue'
import LoginForm from '~/components/auth/LoginForm.vue'
import SignupForm from '~/components/auth/SignupForm.vue'
import useMarkdown from '~/composables/useMarkdown'
import { humanSize } from '~/utils/filters'
import { useStore } from '~/store'
import { computed } from 'vue'
import { whenever } from '@vueuse/core'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'

const { t } = useI18n()
const labels = computed(() => ({
  title: t('Home')
}))

const store = useStore()
const nodeinfo = computed(() => store.state.instance.nodeinfo)

const podName = computed(() => get(nodeinfo.value, 'metadata.nodeName') || 'Funkwhale')
const banner = computed(() => get(nodeinfo.value, 'metadata.banner'))
const shortDescription = computed(() => get(nodeinfo.value, 'metadata.shortDescription'))
const longDescription = useMarkdown(() => get(nodeinfo.value, 'metadata.longDescription', ''))
const rules = computed(() => get(nodeinfo.value, 'metadata.rules'))
const contactEmail = computed(() => get(nodeinfo.value, 'metadata.contactEmail'))
const anonymousCanListen = computed(() => get(nodeinfo.value, 'metadata.library.anonymousCanListen'))
const openRegistrations = computed(() => get(nodeinfo.value, 'openRegistrations'))
const defaultUploadQuota = computed(() => get(nodeinfo.value, 'metadata.defaultUploadQuota'))

const stats = computed(() => {
  const users = get(nodeinfo.value, 'usage.users.activeMonth', 0)
  const hours = get(nodeinfo.value, 'metadata.library.music.hours', 0)

  if (users === null) {
    return null
  }

  return { users, hours }
})

const headerStyle = computed(() => {
  if (!banner.value) {
    return ''
  }

  return {
    backgroundImage: `url(${store.getters['instance/absoluteUrl'](banner.value)})`
  }
})

// TODO (wvffle): Check if needed
const router = useRouter()
whenever(() => store.state.auth.authenticated, () => {
  console.log('Authenticated, redirecting to /library…')
  router.push('/library')
})
</script>

<template>
  <main
    v-title="labels.title"
    class="main pusher page-home"
  >
    <section
      :class="['ui', 'head', {'with-background': banner}, 'vertical', 'center', 'aligned', 'stripe', 'segment']"
      :style="headerStyle"
    >
      <div class="segment-content">
        <h1 class="ui center aligned large header">
          <span>
            {{ $t('Welcome to %{ podName }!', { podName }) }}
          </span>
          <div
            v-if="shortDescription"
            class="sub header"
          >
            {{ shortDescription }}
          </div>
        </h1>
      </div>
    </section>
    <section class="ui vertical stripe segment">
      <div class="ui stackable grid">
        <div class="ten wide column">
          <h2 class="header">
            About this Funkwhale pod
          </h2>
          <div
            id="pod"
            class="ui raised segment"
          >
            <div class="ui stackable grid">
              <div class="eight wide column">
                <p v-if="!longDescription">
                  No description available.
                </p>
                <template v-if="longDescription || rules">
                  <sanitized-html
                    v-if="longDescription"
                    id="renderedDescription"
                    :html="longDescription"
                  />
                  <div
                    v-if="longDescription"
                    class="ui hidden divider"
                  />
                  <div class="ui relaxed list">
                    <div
                      v-if="longDescription"
                      class="item"
                    >
                      <i class="arrow right icon" />
                      <div class="content">
                        <router-link
                          class="ui link"
                          :to="{name: 'about'}"
                        >
                          Learn more
                        </router-link>
                      </div>
                    </div>
                    <div
                      v-if="rules"
                      class="item"
                    >
                      <i class="book open icon" />
                      <div class="content">
                        <router-link
                          v-if="rules"
                          class="ui link"
                          :to="{name: 'about', hash: '#rules'}"
                        >
                          Server rules
                        </router-link>
                      </div>
                    </div>
                  </div>
                </template>
              </div>
              <div class="eight wide column">
                <template v-if="stats">
                  <h3 class="sub header">
                    Statistics
                  </h3>
                  <p>
                    <i class="user icon" />
                    {{ $t('%{ users } active user | %{ users } active users', stats, stats.users) }}
                  </p>
                  <p>
                    <i class="music icon" />
                    {{ $t('%{ hours } hour of music | %{ hours } hours of music', stats, stats.hours) }}
                  </p>
                </template>
                <template v-if="contactEmail">
                  <h3 class="sub header">
                    Contact
                  </h3>
                  <i class="at icon" />
                  <a :href="`mailto:${contactEmail}`">{{ contactEmail }}</a>
                </template>
              </div>
            </div>
          </div>
        </div>

        <div class="six wide column">
          <img
            class="ui image"
            src="../assets/network.png"
            alt=""
          >
        </div>
      </div>
      <div class="ui hidden divider" />
      <div class="ui hidden divider" />
      <div class="ui stackable grid">
        <div class="four wide column">
          <h3 class="header">
            About Funkwhale
          </h3>
          <p>
            This pod runs Funkwhale, a community-driven project that lets you listen and share music and audio within a decentralized, open network.
          </p>
          <p>
            Funkwhale is free and developed by a friendly community of volunteers.
          </p>
          <a
            target="_blank"
            rel="noopener"
            href="https://funkwhale.audio"
          >
            <i class="external alternate icon" />
            Visit funkwhale.audio
          </a>
        </div>
        <div class="four wide column">
          <h3 class="header">
            Log In
          </h3>
          <login-form
            button-classes="success"
            :show-signup="false"
          />
          <div class="ui hidden clearing divider" />
        </div>
        <div class="four wide column">
          <h3 class="header">
            Sign up
          </h3>
          <template v-if="openRegistrations">
            <p>
              Sign up now to keep track of your favorites, create playlists, discover new content and much more!
            </p>
            <p v-if="defaultUploadQuota">
              {{ $t('Users on this pod also get %{ quota } of free storage to upload their own content!', { quota: humanSize(defaultUploadQuota * 1000 * 1000) }) }}
            </p>
            <signup-form
              button-classes="success"
              :show-login="false"
            />
          </template>
          <div v-else>
            <p>
              Registrations are closed on this pod. You can signup on another pod using the link below.
            </p>
            <a
              target="_blank"
              rel="noopener"
              href="https://funkwhale.audio/#get-started"
            >
              <i class="external alternate icon" />
              Find another pod
            </a>
          </div>
        </div>

        <div class="four wide column">
          <h3 class="header">
            Useful links
          </h3>
          <div class="ui relaxed list">
            <div class="item">
              <i class="headphones icon" />
              <div class="content">
                <router-link
                  v-if="anonymousCanListen"
                  class="header"
                  to="/library"
                >
                  Browse public content
                </router-link>
                <div class="description">
                  Listen to public albums and playlists shared on this pod
                </div>
              </div>
            </div>
            <div class="item">
              <i class="mobile alternate icon" />
              <div class="content">
                <a
                  class="header"
                  href="https://funkwhale.audio/en_US/apps"
                  target="_blank"
                  rel="noopener"
                >
                  Mobile apps
                </a>
                <div class="description">
                  Use Funkwhale on other devices with our apps
                </div>
              </div>
            </div>
            <div class="item">
              <i class="book icon" />
              <div class="content">
                <a
                  class="header"
                  href="https://docs.funkwhale.audio/users/index.html"
                  target="_blank"
                  rel="noopener"
                >
                  User guides
                </a>
                <div class="description">
                  Discover everything you need to know about Funkwhale and its features
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
    <section
      v-if="anonymousCanListen"
      class="ui vertical stripe segment"
    >
      <album-widget
        :filters="{playable: true, ordering: '-creation_date'}"
        :limit="10"
      >
        <template #title>
          Recently added albums
        </template>
        <router-link to="/library">
          View more…
          <div class="ui hidden divider" />
        </router-link>
      </album-widget>
      <div class="ui hidden section divider" />
      <h3 class="ui header">
        New channels
      </h3>
      <channels-widget
        :show-modification-date="true"
        :limit="10"
        :filters="{ordering: '-creation_date', external: 'false'}"
      />
    </section>
  </main>
</template>
