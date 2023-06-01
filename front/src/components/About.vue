<script setup lang="ts">
import { useStore } from '~/store'
import { useI18n } from 'vue-i18n'
import { get } from 'lodash-es'
import { humanSize } from '~/utils/filters'
import { computed } from 'vue'

import SignupForm from '~/components/auth/SignupForm.vue'
import LogoText from '~/components/LogoText.vue'

const store = useStore()
const nodeinfo = computed(() => store.state.instance.nodeinfo)

const { t } = useI18n()
const labels = computed(() => ({
  title: t('components.About.title')
}))

const podName = computed(() => get(nodeinfo.value, 'metadata.nodeName') ?? 'Funkwhale')
const banner = computed(() => get(nodeinfo.value, 'metadata.banner'))
const shortDescription = computed(() => get(nodeinfo.value, 'metadata.shortDescription'))

const stats = computed(() => {
  const users = get(nodeinfo.value, 'usage.users.activeMonth', 0)
  const hours = get(nodeinfo.value, 'metadata.library.music.hours', 0)

  if (users === null) {
    return null
  }

  return { users, hours }
})

const openRegistrations = computed(() => get(nodeinfo.value, 'openRegistrations'))
const defaultUploadQuota = computed(() => humanSize(get(nodeinfo.value, 'metadata.defaultUploadQuota', 0) * 1000 * 1000))

const headerStyle = computed(() => {
  if (!banner.value) {
    return ''
  }

  return {
    backgroundImage: `url(${store.getters['instance/absoluteUrl'](banner.value)})`
  }
})
</script>

<template>
  <main
    v-title="labels.title"
    class="main pusher page-about"
  >
    <div class="ui container">
      <div class="ui horizontally fitted basic stripe segment">
        <div class="ui horizontally fitted basic very padded segment">
          <div class="ui center aligned text container">
            <div class="ui text container">
              <div class="ui equal width compact stackable grid">
                <div class="column" />
                <div class="ten wide column">
                  <div class="ui vertically fitted basic segment">
                    <router-link to="/">
                      <logo-text />
                    </router-link>
                  </div>
                </div>
                <div class="column" />
              </div>
              <h2 class="header">
                {{ $t('components.About.header.funkwhale') }}
              </h2>
              <p>
                {{ $t('components.About.description.funkwhale') }}
              </p>
            </div>
          </div>
        </div>
        <div class="ui hidden divider" />
        <div class="ui vertically fitted basic stripe segment">
          <div class="ui two stackable cards">
            <div class="ui card">
              <div
                v-if="!$store.state.auth.authenticated"
                class="signup-form content"
              >
                <h3 class="header">
                  {{ $t('components.About.header.signup') }}
                </h3>
                <template v-if="openRegistrations">
                  <p>
                    {{ $t('components.About.description.signup') }}
                  </p>
                  <p v-if="defaultUploadQuota">
                    {{ $t('components.About.description.quota', {quota: defaultUploadQuota}) }}
                  </p>
                  <signup-form
                    button-classes="success"
                    :show-login="false"
                  />
                </template>
                <div v-else>
                  <p>
                    {{ $t('components.About.help.closedRegistrations') }}
                  </p>

                  <a
                    target="_blank"
                    rel="noopener"
                    href="https://funkwhale.audio/#get-started"
                  >
                    {{ $t('components.About.link.findOtherPod') }}
                    &nbsp;<i class="external alternate icon" />
                  </a>
                </div>
              </div>
              <div
                v-else
                class="signup-form content"
              >
                <h3 class="header">
                  {{ $t('components.About.header.signup') }}
                  <div class="ui positive message">
                    <div class="header">
                      {{ $t('components.About.message.loggedIn') }}
                    </div>
                    <p>
                      {{ $t('components.About.message.greeting', {username: $store.state.auth.username}) }}
                    </p>
                  </div>
                </h3>
              </div>
            </div>
            <div class="ui card">
              <section
                :class="['ui', 'head', {'with-background': banner}, 'vertical', 'center', 'aligned', 'stripe', 'segment']"
                :style="headerStyle"
              >
                <h1>
                  <i class="music icon" />
                  {{ podName }}
                </h1>
              </section>
              <div class="content pod-description">
                <h3
                  id="description"
                  class="ui header"
                >
                  {{ $t('components.About.header.aboutPod') }}
                </h3>
                <div
                  v-if="shortDescription"
                  class="sub header"
                >
                  {{ shortDescription }}
                </div>
                <p v-else>
                  {{ $t('components.About.placeholder.noDescription') }}
                </p>

                <template v-if="stats">
                  <div class="statistics-container ui doubling grid">
                    <div class="two column row">
                      <div class="column">
                        <span class="statistics-figure ui text">
                          <span class="ui big text"><strong>{{ stats.users.toLocaleString($store.state.ui.momentLocale) }}</strong></span>
                          <br>
                          {{ $t('components.About.stat.activeUsers', stats.users) }}
                        </span>
                      </div>
                      <div class="column">
                        <span class="statistics-figure ui text">
                          <span class="ui big text"><strong>{{ stats.hours.toLocaleString($store.state.ui.momentLocale) }}</strong></span>
                          <br>
                          {{ $t('components.About.stat.hoursOfMusic', stats.hours) }}
                        </span>
                      </div>
                    </div>
                  </div>
                </template>

                <router-link
                  to="/about/pod"
                  class="ui fluid basic secondary button"
                >
                  {{ $t('components.About.link.learnMore') }}
                </router-link>
              </div>
            </div>
          </div>
          <!-- TODO (wvffle): Remove style when migrate away from fomantic -->
          <div
            class="ui three stackable cards"
            style="z-index: 1; position: relative;"
          >
            <router-link
              to="/"
              class="ui card"
            >
              <div class="content">
                <h3
                  id="description"
                  class="ui header"
                >
                  {{ $t('components.About.header.publicContent') }}
                </h3>
                <p>
                  {{ $t('components.About.description.publicContent') }}
                </p>
              </div>
            </router-link>
            <a
              href="https://funkwhale.audio/#get-started"
              class="ui card"
              target="_blank"
            >
              <div class="content">
                <h3
                  id="description"
                  class="ui header"
                >
                  {{ $t('components.About.link.findOtherPod') }}
                  &nbsp;<i class="external alternate icon" />
                </h3>
                <p>
                  {{ $t('components.About.description.publicContent') }}
                </p>
              </div>
            </a>
            <a
              href="https://funkwhale.audio/apps"
              class="ui card"
              target="_blank"
            >
              <div class="content">
                <h3
                  id="description"
                  class="ui header"
                >
                  {{ $t('components.About.header.findApp') }}
                  &nbsp;<i class="external alternate icon" />
                </h3>
                <p>
                  {{ $t('components.About.description.findApp') }}
                </p>
              </div>
            </a>
          </div>
          <div class="ui fluid horizontally fitted basic clearing segment container">
            <router-link
              to="/about/pod"
              class="ui right floated basic secondary button"
            >
              {{ $t('components.About.header.aboutPod') }}
              <i class="icon arrow right" />
            </router-link>
          </div>
        </div>
      </div>
    </div>
  </main>
</template>
