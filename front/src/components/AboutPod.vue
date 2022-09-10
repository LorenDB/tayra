<script setup lang="ts">
import { humanSize } from '~/utils/filters'
import { useStore } from '~/store'
import { get } from 'lodash-es'
import { computed } from 'vue'

import axios from 'axios'

import useMarkdown from '~/composables/useMarkdown'
import type { NodeInfo } from '~/store/instance'
import { useI18n } from 'vue-i18n'

const store = useStore()
const nodeinfo = computed(() => store.state.instance.nodeinfo)

const fetchData = async () => {
  const response = await axios.get('instance/nodeinfo/2.0/')
  store.commit('instance/nodeinfo', response.data)
}
fetchData()

const { t } = useI18n()
const labels = computed(() => ({
  title: t('About')
}))

const podName = computed(() => get(nodeinfo.value, 'metadata.nodeName') || 'Funkwhale')
const banner = computed(() => get(nodeinfo.value, 'metadata.banner'))
const longDescription = useMarkdown(() => get(nodeinfo.value, 'metadata.longDescription', ''))
const rules = useMarkdown(() => get(nodeinfo.value, 'metadata.rules', ''))
const terms = useMarkdown(() => get(nodeinfo.value, 'metadata.terms', ''))
const contactEmail = computed(() => get(nodeinfo.value, 'metadata.contactEmail'))
const anonymousCanListen = computed(() => get(nodeinfo.value, 'metadata.library.anonymousCanListen'))
const allowListEnabled = computed(() => get(nodeinfo.value, 'metadata.allowList.enabled'))
const version = computed(() => get(nodeinfo.value, 'software.version'))
const openRegistrations = computed(() => get(nodeinfo.value, 'openRegistrations'))
const defaultUploadQuota = computed(() => get(nodeinfo.value, 'metadata.defaultUploadQuota'))
const federationEnabled = computed(() => get(nodeinfo.value, 'metadata.library.federationEnabled'))

const onDesktop = computed(() => window.innerWidth > 800)

const stats = computed(() => {
  const info = nodeinfo.value ?? {} as NodeInfo

  const data = {
    users: get(info, 'usage.users.activeMonth', null),
    hours: get(info, 'metadata.library.music.hours', null),
    artists: get(info, 'metadata.library.artists.total', null),
    albums: get(info, 'metadata.library.albums.total', null),
    tracks: get(info, 'metadata.library.tracks.total', null),
    listenings: get(info, 'metadata.usage.listenings.total', null)
  }

  if (data.users === null || data.artists === null) {
    return data
  }

  return data
})

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
    <div
      class="ui"
      :class="{ container: onDesktop}"
    >
      <div class="ui horizontally fitted stripe basic segment">
        <div class="ui basic vertically fitted stripe segment content">
          <section
            :class="['ui', 'head', {'with-background': banner}, 'vertical', 'center', 'aligned', 'stripe', 'segment']"
            :style="headerStyle"
          >
            <h1>
              <i class="music icon" />
              {{ podName }}
            </h1>
          </section>
        </div>
        <div class="ui basic vertically fitted stripe segment content">
          <!-- See layout in _about.scss -->
          <div class="about-pod-info-container">
            <div class="about-pod-info-toc">
              <div class="ui vertical pointing secondary menu">
                <router-link
                  to="/about/pod"
                  class="item"
                >
                  About this pod
                </router-link>
                <router-link
                  to="/about/pod#rules"
                  class="item"
                >
                  Rules
                </router-link>
                <router-link
                  to="/about/pod#terms"
                  class="item"
                >
                  Terms and privacy policy
                </router-link>
                <router-link
                  to="/about/pod#features"
                  class="item"
                >
                  Features
                </router-link>
                <router-link
                  v-if="stats"
                  to="/about/pod#statistics"
                  class="item"
                >
                  Statistics
                </router-link>
              </div>
            </div>

            <div class="about-pod-info">
              <h2
                id="description about-this-pod"
                class="ui header"
              >
                About this pod
              </h2>
              <sanitized-html
                v-if="longDescription"
                :html="longDescription"
              />
              <p v-else>
                No description available.
              </p>

              <h3
                id="rules"
                class="ui header"
              >
                Rules
              </h3>
              <sanitized-html
                v-if="rules"
                :html="rules"
              />
              <p v-else>
                No rules available.
              </p>

              <h3
                id="terms"
                class="ui header"
              >
                Terms and privacy policy
              </h3>
              <sanitized-html
                v-if="terms"
                :html="terms"
              />
              <p v-else>
                No terms available.
              </p>

              <h3
                id="features"
                class="header"
              >
                Features
              </h3>
              <div class="features-container ui two column stackable grid">
                <div class="column">
                  <table class="ui very basic table unstackable">
                    <tbody>
                      <tr>
                        <td>
                          Funkwhale version
                        </td>
                        <td
                          v-if="version"
                          class="right aligned"
                        >
                          <span class="features-status ui text">
                            {{ version }}
                          </span>
                        </td>
                        <td
                          v-else
                          class="right aligned"
                        >
                          <span class="features-status ui text">
                            N/A
                          </span>
                        </td>
                      </tr>
                      <tr>
                        <td>
                          Federation
                        </td>
                        <td
                          v-if="federationEnabled"
                          class="right aligned"
                        >
                          <span class="features-status ui text">
                            <i class="check icon" />
                            Enabled
                          </span>
                        </td>
                        <td
                          v-else
                          class="right aligned"
                        >
                          <span class="features-status ui text">
                            <i class="x icon" />
                            Disabled
                          </span>
                        </td>
                      </tr>
                      <tr>
                        <td>
                          Allow-list
                        </td>
                        <td
                          v-if="allowListEnabled"
                          class="right aligned"
                        >
                          <span class="features-status ui text">
                            <i class="check icon" />
                            Enabled
                          </span>
                        </td>
                        <td
                          v-else
                          class="right aligned"
                        >
                          <span class="features-status ui text">
                            <i class="x icon" />
                            Disabled
                          </span>
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>
                <div class="column">
                  <table class="ui very basic table unstackable">
                    <tbody>
                      <tr>
                        <td>
                          Anonymous access
                        </td>
                        <td
                          v-if="anonymousCanListen"
                          class="right aligned"
                        >
                          <span class="features-status ui text">
                            <i class="check icon" />
                            Enabled
                          </span>
                        </td>
                        <td
                          v-else
                          class="right aligned"
                        >
                          <span class="features-status ui text">
                            <i class="x icon" />
                            Disabled
                          </span>
                        </td>
                      </tr>
                      <tr>
                        <td>
                          Registrations
                        </td>
                        <td
                          v-if="openRegistrations"
                          class="right aligned"
                        >
                          <span class="features-status ui text">
                            <i class="check icon" />
                            Open
                          </span>
                        </td>
                        <td
                          v-else
                          class="right aligned"
                        >
                          <span class="features-status ui text">
                            <i class="x icon" />
                            Closed
                          </span>
                        </td>
                      </tr>
                      <tr>
                        <td>
                          Upload quota
                        </td>
                        <td
                          v-if="defaultUploadQuota"
                          class="right aligned"
                        >
                          <span class="features-status ui text">
                            {{ humanSize(defaultUploadQuota * 1000 * 1000) }}
                          </span>
                        </td>
                        <td
                          v-else
                          class="right aligned"
                        >
                          <span class="features-status ui text">
                            N/A
                          </span>
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              </div>

              <template v-if="stats">
                <h3
                  id="statistics"
                  class="header"
                >
                  Statistics
                </h3>
                <div class="statistics-container">
                  <div
                    v-if="stats.hours"
                    class="statistics-statistic"
                  >
                    <span class="statistics-figure ui text">
                      <span class="ui big text"><strong>{{ stats.hours.toLocaleString($store.state.ui.momentLocale) }}</strong></span>
                      <br>
                      {{ $t('hour of music | hours of music', stats.hours) }}
                    </span>
                  </div>
                  <div
                    v-if="stats.artists"
                    class="statistics-statistic"
                  >
                    <span class="statistics-figure ui text">
                      <span class="ui big text"><strong>{{ stats.artists.toLocaleString($store.state.ui.momentLocale) }}</strong></span>
                      <br>
                      {{ $t('artist | artists', stats.artists) }}
                    </span>
                  </div>
                  <div
                    v-if="stats.albums"
                    class="statistics-statistic"
                  >
                    <span class="statistics-figure ui text">
                      <span class="ui big text"><strong>{{ stats.albums.toLocaleString($store.state.ui.momentLocale) }}</strong></span>
                      <br>
                      {{ $t('album | albums', stats.albums) }}
                    </span>
                  </div>
                  <div
                    v-if="stats.tracks"
                    class="statistics-statistic"
                  >
                    <span class="statistics-figure ui text">
                      <span class="ui big text"><strong>{{ stats.tracks.toLocaleString($store.state.ui.momentLocale) }}</strong></span>
                      <br>
                      {{ $t('track | tracks', stats.tracks) }}
                    </span>
                  </div>
                  <div
                    v-if="stats.users"
                    class="statistics-statistic"
                  >
                    <span class="statistics-figure ui text">
                      <span class="ui big text"><strong>{{ stats.users.toLocaleString($store.state.ui.momentLocale) }}</strong></span>
                      <br>
                      {{ $t('active user | active users', stats.users) }}
                    </span>
                  </div>
                  <div
                    v-if="stats.listenings"
                    class="statistics-statistic"
                  >
                    <span class="statistics-figure ui text">
                      <span class="ui big text"><strong>{{ stats.listenings.toLocaleString($store.state.ui.momentLocale) }}</strong></span>
                      <br>
                      {{ $t('listening | listenings', stats.listenings) }}
                    </span>
                  </div>
                </div>
              </template>

              <template v-if="contactEmail">
                <h3
                  id="contact"
                  class="ui header"
                >
                  Contact
                </h3>
                <a
                  v-if="contactEmail"
                  :href="`mailto:${contactEmail}`"
                >
                  {{ $t('Send us an email: %{ contactEmail }', { contactEmail }) }}
                </a>
              </template>

              <div class="ui hidden divider" />
              <div class="ui fluid horizontally fitted basic clearing segment container">
                <router-link
                  to="/about"
                  class="ui left floated basic secondary button"
                >
                  <i class="icon arrow left" />
                  Introduction
                </router-link>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </main>
</template>
