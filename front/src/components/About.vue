<script setup lang="ts">
import { useStore } from '~/store'
import { useGettext } from 'vue3-gettext'
import { get } from 'lodash-es'
import { humanSize } from '~/utils/filters'
import { computed } from 'vue'

import SignupForm from '~/components/auth/SignupForm.vue'
import LogoText from '~/components/LogoText.vue'

const store = useStore()
const nodeinfo = computed(() => store.state.instance.nodeinfo)

const { $pgettext } = useGettext()
const labels = computed(() => ({
  title: $pgettext('Head/About/Title', 'About')
}))

const podName = computed(() => get(nodeinfo.value, 'metadata.nodeName') ?? 'Funkwhale')
const banner = computed(() => get(nodeinfo.value, 'metadata.banner'))
const shortDescription = computed(() => get(nodeinfo.value, 'metadata.shortDescription'))

const stats = computed(() => {
  const users = get(nodeinfo.value, 'usage.users.activeMonth', null)
  const hours = get(nodeinfo.value, 'metadata.library.music.hours', 0)
  
  if (users === null) {
    return null
  }

  return { users, hours }
})

const openRegistrations = computed(() => get(nodeinfo.value, 'openRegistrations'))
const defaultUploadQuota = computed(() => humanSize(get(nodeinfo.value, 'metadata.defaultUploadQuota') * 1000 * 1000))

const headerStyle = computed(() => {
  if (!banner.value) {
    return ''
  }

  return (`background-image: url(${store.getters['instance/absoluteUrl'](banner.value)})`)
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
                <translate translate-context="Content/About/Heading">
                  A social platform to enjoy and share music
                </translate>
              </h2>
              <p>
                <translate translate-context="Content/About/Paragraph">
                  Funkwhale is a community-driven project that lets you listen and share music and audio within a decentralized, open network.
                </translate>
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
                  <translate translate-context="*/Signup/Title">
                    Sign up
                  </translate>
                </h3>
                <template v-if="openRegistrations">
                  <p>
                    <translate translate-context="Content/About/Paragraph">
                      Sign up now to keep a track of your favorites, create playlists, discover new content and much more!
                    </translate>
                  </p>
                  <p v-if="defaultUploadQuota">
                    <translate
                      translate-context="Content/About/Paragraph"
                      :translate-params="{quota: defaultUploadQuota}"
                    >
                      Users on this pod also get %{ quota } of free storage to upload their own content!
                    </translate>
                  </p>
                  <signup-form
                    button-classes="success"
                    :show-login="false"
                  />
                </template>
                <div v-else>
                  <p translate-context="Content/About/Paragraph">
                    Registrations are closed on this pod. You can signup on another pod using the link below.
                  </p>

                  <a
                    target="_blank"
                    rel="noopener"
                    href="https://funkwhale.audio/#get-started"
                  >
                    <translate translate-context="Content/About/Link">Find another pod</translate>
                    &nbsp;<i class="external alternate icon" />
                  </a>
                </div>
              </div>
              <div
                v-else
                class="signup-form content"
              >
                <h3 class="header">
                  <translate translate-context="*/Signup/Title">
                    Sign up
                  </translate>
                  <div class="ui positive message">
                    <div class="header">
                      <translate translate-context="Content/About/Message">
                        You're already signed in!
                      </translate>
                    </div>
                    <p>
                      <translate translate-contect="Content/About/Hello">
                        Hello
                      </translate> {{ $store.state.auth.username }}
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
                  <translate translate-context="Content/About/Header">
                    About this pod
                  </translate>
                </h3>
                <div
                  v-if="shortDescription"
                  class="sub header"
                >
                  {{ shortDescription }}
                </div>
                <p v-else>
                  <translate translate-context="Content/About/Paragraph">
                    No description available.
                  </translate>
                </p>

                <template v-if="stats">
                  <div class="statistics-container ui doubling grid">
                    <div class="two column row">
                      <div class="column">
                        <span class="statistics-figure ui text">
                          <span class="ui big text"><strong>{{ stats.users.toLocaleString($store.state.ui.momentLocale) }}</strong></span>
                          <br>
                          <translate
                            translate-context="Content/About/*"
                            :translate-n="stats.users"
                            translate-plural="active users"
                          >active user</translate>
                        </span>
                      </div>
                      <div class="column">
                        <span class="statistics-figure ui text">
                          <span class="ui big text"><strong>{{ parseInt(stats.hours).toLocaleString($store.state.ui.momentLocale) }}</strong></span>
                          <br>
                          <translate
                            translate-context="Content/About/*"
                            :translate-n="parseInt(stats.hours)"
                            translate-plural="hours of music"
                          >hour of music</translate>
                        </span>
                      </div>
                    </div>
                  </div>
                </template>

                <router-link
                  to="/about/pod"
                  class="ui fluid basic secondary button"
                >
                  <translate translate-context="Content/About/Paragraph">
                    Learn More
                  </translate>
                </router-link>
              </div>
            </div>
          </div>
          <div class="ui three stackable cards">
            <router-link
              to="/"
              class="ui card"
            >
              <div class="content">
                <h3
                  id="description"
                  class="ui header"
                >
                  <translate translate-context="Content/About/Header">
                    Browse public content
                  </translate>
                </h3>
                <p>
                  <translate translate-context="Content/About/Paragraph">
                    Listen to public albums and playlists shared on this pod.
                  </translate>
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
                  <translate translate-context="Content/About/Header">Find another pod</translate>
                  &nbsp;<i class="external alternate icon" />
                </h3>
                <p>
                  <translate translate-context="Content/About/Paragraph">Listen to public albums and playlists shared on this pod.</translate>
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
                  <translate translate-context="Content/About/Header">Find an app</translate>
                  &nbsp;<i class="external alternate icon" />
                </h3>
                <p>
                  <translate translate-context="Content/About/Paragraph">Use Funkwhale on other devices with our apps.</translate>
                </p>
              </div>
            </a>
          </div>
          <div class="ui fluid horizontally fitted basic clearing segment container">
            <router-link
              to="/about/pod"
              class="ui right floated basic secondary button"
            >
              <translate translate-context="Content/About/Paragraph">
                About this pod
              </translate>
              <i class="icon arrow right" />
            </router-link>
          </div>
        </div>
      </div>
    </div>
  </main>
</template>
