<script setup lang="ts">
import { get } from 'lodash-es'
import AlbumWidget from '~/components/audio/album/Widget.vue'
import ChannelsWidget from '~/components/audio/ChannelsWidget.vue'
import LoginForm from '~/components/auth/LoginForm.vue'
import SignupForm from '~/components/auth/SignupForm.vue'
import useMarkdown from '~/composables/useMarkdown'
import useLogger from '~/composables/useLogger'
import { humanSize } from '~/utils/filters'
import { useStore } from '~/store'
import { computed } from 'vue'
import { whenever } from '@vueuse/core'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'

const { t } = useI18n()
const labels = computed(() => ({
  title: t('components.Home.title')
}))

const store = useStore()
const logger = useLogger()
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
  logger.log('Authenticated, redirecting to /library…')
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
            {{ $t('components.Home.header.welcome', {podName: podName}) }}
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
            {{ $t('components.Home.header.about') }}
          </h2>
          <div
            id="pod"
            class="ui raised segment"
          >
            <div class="ui stackable grid">
              <div class="eight wide column">
                <p v-if="!longDescription">
                  {{ $t('components.Home.placeholder.noDescription') }}
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
                          {{ $t('components.Home.link.learnMore') }}
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
                          {{ $t('components.Home.link.rules') }}
                        </router-link>
                      </div>
                    </div>
                  </div>
                </template>
              </div>
              <div class="eight wide column">
                <template v-if="stats">
                  <h3 class="sub header">
                    {{ $t('components.Home.header.statistics') }}
                  </h3>
                  <p>
                    <i class="user icon" />
                    {{ $t('components.Home.stat.activeUsers', stats.users) }}
                  </p>
                  <p>
                    <i class="music icon" />
                    {{ $t('components.Home.stat.hoursOfMusic', stats.hours) }}
                  </p>
                </template>
                <template v-if="contactEmail">
                  <h3 class="sub header">
                    {{ $t('components.Home.header.contact') }}
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
            {{ $t('components.Home.header.aboutFunkwhale') }}
          </h3>
          <p>
            {{ $t('components.Home.description.funkwhale.paragraph1') }}
          </p>
          <p>
            {{ $t('components.Home.description.funkwhale.paragraph2') }}
          </p>
          <a
            target="_blank"
            rel="noopener"
            href="https://funkwhale.audio"
          >
            <i class="external alternate icon" />
            {{ $t('components.Home.link.funkwhale') }}
          </a>
        </div>
        <div class="four wide column">
          <h3 class="header">
            {{ $t('components.Home.header.login') }}
          </h3>
          <login-form
            button-classes="success"
            :show-signup="false"
          />
          <div class="ui hidden clearing divider" />
        </div>
        <div class="four wide column">
          <h3 class="header">
            {{ $t('components.Home.header.signup') }}
          </h3>
          <template v-if="openRegistrations">
            <p>
              {{ $t('components.Home.description.signup') }}
            </p>
            <p v-if="defaultUploadQuota">
              {{ $t('components.Home.description.quota', { quota: humanSize(defaultUploadQuota * 1000 * 1000) }) }}
            </p>
            <signup-form
              button-classes="success"
              :show-login="false"
            />
          </template>
          <div v-else>
            <p>
              {{ $t('components.Home.help.registrationsClosed') }}
            </p>
            <a
              target="_blank"
              rel="noopener"
              href="https://funkwhale.audio/#get-started"
            >
              <i class="external alternate icon" />
              {{ $t('components.Home.link.findOtherPod') }}
            </a>
          </div>
        </div>

        <div class="four wide column">
          <h3 class="header">
            {{ $t('components.Home.header.links') }}
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
                  {{ $t('components.Home.link.publicContent.label') }}
                </router-link>
                <div class="description">
                  {{ $t('components.Home.link.publicContent.description') }}
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
                  {{ $t('components.Home.link.mobileApps.label') }}
                </a>
                <div class="description">
                  {{ $t('components.Home.link.mobileApps.description') }}
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
                  {{ $t('components.Home.link.userGuides.label') }}
                </a>
                <div class="description">
                  {{ $t('components.Home.link.userGuides.description') }}
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
          {{ $t('components.Home.header.newAlbums') }}
        </template>
        <router-link to="/library">
          {{ $t('components.Home.link.viewMore') }}
          <div class="ui hidden divider" />
        </router-link>
      </album-widget>
      <div class="ui hidden section divider" />
      <h3 class="ui header">
        {{ $t('components.Home.header.newChannels') }}
      </h3>
      <channels-widget
        :show-modification-date="true"
        :limit="10"
        :filters="{ordering: '-creation_date', external: 'false'}"
      />
    </section>
  </main>
</template>
