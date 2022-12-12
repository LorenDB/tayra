<script setup lang="ts">
import { humanSize } from '~/utils/filters'
import { useStore } from '~/store'
import { get } from 'lodash-es'
import { computed } from 'vue'

import useMarkdown from '~/composables/useMarkdown'
import type { NodeInfo } from '~/store/instance'
import { useI18n } from 'vue-i18n'

const store = useStore()
const nodeinfo = computed(() => store.state.instance.nodeinfo)

const { t } = useI18n()
const labels = computed(() => ({
  title: t('components.AboutPod.title')
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
                  {{ $t('components.AboutPod.link.about') }}
                </router-link>
                <router-link
                  to="/about/pod#rules"
                  class="item"
                >
                  {{ $t('components.AboutPod.link.rules') }}
                </router-link>
                <router-link
                  to="/about/pod#terms"
                  class="item"
                >
                  {{ $t('components.AboutPod.link.terms') }}
                </router-link>
                <router-link
                  to="/about/pod#features"
                  class="item"
                >
                  {{ $t('components.AboutPod.link.features') }}
                </router-link>
                <router-link
                  v-if="stats"
                  to="/about/pod#statistics"
                  class="item"
                >
                  {{ $t('components.AboutPod.link.statistics') }}
                </router-link>
              </div>
            </div>

            <div class="about-pod-info">
              <h2
                id="description about-this-pod"
                class="ui header"
              >
                {{ $t('components.AboutPod.header.about') }}
              </h2>
              <sanitized-html
                v-if="longDescription"
                :html="longDescription"
              />
              <p v-else>
                {{ $t('components.AboutPod.placeholder.noDescription') }}
              </p>

              <h3
                id="rules"
                class="ui header"
              >
                {{ $t('components.AboutPod.header.rules') }}
              </h3>
              <sanitized-html
                v-if="rules"
                :html="rules"
              />
              <p v-else>
                {{ $t('components.AboutPod.placeholder.noRules') }}
              </p>

              <h3
                id="terms"
                class="ui header"
              >
                {{ $t('components.AboutPod.header.terms') }}
              </h3>
              <sanitized-html
                v-if="terms"
                :html="terms"
              />
              <p v-else>
                {{ $t('components.AboutPod.placeholder.noTerms') }}
              </p>

              <h3
                id="features"
                class="header"
              >
                {{ $t('components.AboutPod.header.features') }}
              </h3>
              <div class="features-container ui two column stackable grid">
                <div class="column">
                  <table class="ui very basic table unstackable">
                    <tbody>
                      <tr>
                        <td>
                          {{ $t('components.AboutPod.feature.version') }}
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
                            {{ $t('components.AboutPod.notApplicable') }}
                          </span>
                        </td>
                      </tr>
                      <tr>
                        <td>
                          {{ $t('components.AboutPod.feature.federation') }}
                        </td>
                        <td
                          v-if="federationEnabled"
                          class="right aligned"
                        >
                          <span class="features-status ui text">
                            <i class="check icon" />
                            {{ $t('components.AboutPod.feature.status.enabled') }}
                          </span>
                        </td>
                        <td
                          v-else
                          class="right aligned"
                        >
                          <span class="features-status ui text">
                            <i class="x icon" />
                            {{ $t('components.AboutPod.feature.status.disabled') }}
                          </span>
                        </td>
                      </tr>
                      <tr>
                        <td>
                          {{ $t('components.AboutPod.feature.allowList') }}
                        </td>
                        <td
                          v-if="allowListEnabled"
                          class="right aligned"
                        >
                          <span class="features-status ui text">
                            <i class="check icon" />
                            {{ $t('components.AboutPod.feature.status.enabled') }}
                          </span>
                        </td>
                        <td
                          v-else
                          class="right aligned"
                        >
                          <span class="features-status ui text">
                            <i class="x icon" />
                            {{ $t('components.AboutPod.feature.status.disabled') }}
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
                          {{ $t('components.AboutPod.feature.anonymousAccess') }}
                        </td>
                        <td
                          v-if="anonymousCanListen"
                          class="right aligned"
                        >
                          <span class="features-status ui text">
                            <i class="check icon" />
                            {{ $t('components.AboutPod.feature.status.enabled') }}
                          </span>
                        </td>
                        <td
                          v-else
                          class="right aligned"
                        >
                          <span class="features-status ui text">
                            <i class="x icon" />
                            {{ $t('components.AboutPod.feature.status.disabled') }}
                          </span>
                        </td>
                      </tr>
                      <tr>
                        <td>
                          {{ $t('components.AboutPod.feature.registrations') }}
                        </td>
                        <td
                          v-if="openRegistrations"
                          class="right aligned"
                        >
                          <span class="features-status ui text">
                            <i class="check icon" />
                            {{ $t('components.AboutPod.feature.status.open') }}
                          </span>
                        </td>
                        <td
                          v-else
                          class="right aligned"
                        >
                          <span class="features-status ui text">
                            <i class="x icon" />
                            {{ $t('components.AboutPod.feature.status.closed') }}
                          </span>
                        </td>
                      </tr>
                      <tr>
                        <td>
                          {{ $t('components.AboutPod.feature.quota') }}
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
                            {{ $t('components.AboutPod.notApplicable') }}
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
                  {{ $t('components.AboutPod.header.statistics') }}
                </h3>
                <div class="statistics-container">
                  <div
                    v-if="stats.hours"
                    class="statistics-statistic"
                  >
                    <span class="statistics-figure ui text">
                      <span class="ui big text"><strong>{{ stats.hours.toLocaleString($store.state.ui.momentLocale) }}</strong></span>
                      <br>
                      {{ $t('components.AboutPod.stat.hoursOfMusic', stats.hours) }}
                    </span>
                  </div>
                  <div
                    v-if="stats.artists"
                    class="statistics-statistic"
                  >
                    <span class="statistics-figure ui text">
                      <span class="ui big text"><strong>{{ stats.artists.toLocaleString($store.state.ui.momentLocale) }}</strong></span>
                      <br>
                      {{ $t('components.AboutPod.stat.artistsCount', stats.artists) }}
                    </span>
                  </div>
                  <div
                    v-if="stats.albums"
                    class="statistics-statistic"
                  >
                    <span class="statistics-figure ui text">
                      <span class="ui big text"><strong>{{ stats.albums.toLocaleString($store.state.ui.momentLocale) }}</strong></span>
                      <br>
                      {{ $t('components.AboutPod.stat.albumsCount', stats.albums) }}
                    </span>
                  </div>
                  <div
                    v-if="stats.tracks"
                    class="statistics-statistic"
                  >
                    <span class="statistics-figure ui text">
                      <span class="ui big text"><strong>{{ stats.tracks.toLocaleString($store.state.ui.momentLocale) }}</strong></span>
                      <br>
                      {{ $t('components.AboutPod.stat.tracksCount', stats.tracks) }}
                    </span>
                  </div>
                  <div
                    v-if="stats.users"
                    class="statistics-statistic"
                  >
                    <span class="statistics-figure ui text">
                      <span class="ui big text"><strong>{{ stats.users.toLocaleString($store.state.ui.momentLocale) }}</strong></span>
                      <br>
                      {{ $t('components.AboutPod.stat.activeUsers', stats.users) }}
                    </span>
                  </div>
                  <div
                    v-if="stats.listenings"
                    class="statistics-statistic"
                  >
                    <span class="statistics-figure ui text">
                      <span class="ui big text"><strong>{{ stats.listenings.toLocaleString($store.state.ui.momentLocale) }}</strong></span>
                      <br>
                      {{ $t('components.AboutPod.stat.listeningsCount', stats.listenings) }}
                    </span>
                  </div>
                </div>
              </template>

              <template v-if="contactEmail">
                <h3
                  id="contact"
                  class="ui header"
                >
                  {{ $t('components.AboutPod.header.contact') }}
                </h3>
                <a
                  v-if="contactEmail"
                  :href="`mailto:${contactEmail}`"
                >
                  {{ $t('components.AboutPod.message.contact', { contactEmail }) }}
                </a>
              </template>

              <div class="ui hidden divider" />
              <div class="ui fluid horizontally fitted basic clearing segment container">
                <router-link
                  to="/about"
                  class="ui left floated basic secondary button"
                >
                  <i class="icon arrow left" />
                  {{ $t('components.AboutPod.link.introduction') }}
                </router-link>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </main>
</template>
