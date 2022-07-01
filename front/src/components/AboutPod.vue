<script setup lang="ts">
import { useStore } from '~/store'
import { get } from 'lodash-es'
import showdown from 'showdown'
import { humanSize } from '~/utils/filters'
import { computed } from 'vue'
import { useGettext } from 'vue3-gettext'

const markdown = new showdown.Converter()

const store = useStore()
const nodeinfo = computed(() => store.state.instance.nodeinfo)

const { $pgettext } = useGettext()
const labels = computed(() => ({
  title: $pgettext('Head/About/Title', 'About')
}))

const podName = computed(() => get(nodeinfo.value, 'metadata.nodeName') || 'Funkwhale')
const banner = computed(() => get(nodeinfo.value, 'metadata.banner'))
const longDescription = computed(() => get(nodeinfo.value, 'metadata.longDescription'))
const rules = computed(() => get(nodeinfo.value, 'metadata.rules'))
const terms = computed(() => get(nodeinfo.value, 'metadata.terms'))
const contactEmail = computed(() => get(nodeinfo.value, 'metadata.contactEmail'))
const anonymousCanListen = computed(() => get(nodeinfo.value, 'metadata.library.anonymousCanListen'))
const allowListEnabled = computed(() => get(nodeinfo.value, 'metadata.allowList.enabled'))
const version = computed(() => get(nodeinfo.value, 'software.version'))
const openRegistrations = computed(() => get(nodeinfo.value, 'openRegistrations'))
const defaultUploadQuota = computed(() => get(nodeinfo.value, 'metadata.defaultUploadQuota'))
const federationEnabled = computed(() => get(nodeinfo.value, 'metadata.library.federationEnabled'))

const onDesktop = computed(() => window.innerWidth > 800)

const stats = computed(() => {
  const data = {
    users: get(nodeinfo.value, 'usage.users.activeMonth', null),
    hours: get(nodeinfo.value, 'metadata.library.music.hours', null),
    artists: get(nodeinfo.value, 'metadata.library.artists.total', null),
    albums: get(nodeinfo.value, 'metadata.library.albums.total', null),
    tracks: get(nodeinfo.value, 'metadata.library.tracks.total', null),
    listenings: get(nodeinfo.value, 'metadata.usage.listenings.total', null)
  }

  if (data.users === null || data.artists === null) {
    return
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
                  <translate translate-context="Content/About/Header">
                    About this pod
                  </translate>
                </router-link>
                <router-link
                  to="/about/pod#rules"
                  class="item"
                >
                  <translate translate-context="Content/About/Header">
                    Rules
                  </translate>
                </router-link>
                <router-link
                  to="/about/pod#terms"
                  class="item"
                >
                  <translate translate-context="Content/About/Header">
                    Terms and privacy policy
                  </translate>
                </router-link>
                <router-link
                  to="/about/pod#features"
                  class="item"
                >
                  <translate translate-context="Content/About/Header">
                    Features
                  </translate>
                </router-link>
                <router-link
                  v-if="stats"
                  to="/about/pod#statistics"
                  class="item"
                >
                  <translate translate-context="Content/About/Header">
                    Statistics
                  </translate>
                </router-link>
              </div>
            </div>

            <div class="about-pod-info">
              <h2
                id="description about-this-pod"
                class="ui header"
              >
                <translate translate-context="Content/About/Header">
                  About this pod
                </translate>
              </h2>
              <sanitized-html 
                v-if="longDescription"
                :html="markdown.makeHtml(longDescription)"
              />
              <p v-else>
                <translate translate-context="Content/About/Paragraph">
                  No description available.
                </translate>
              </p>

              <h3
                id="rules"
                class="ui header"
              >
                <translate translate-context="Content/About/Header">
                  Rules
                </translate>
              </h3>
              <sanitized-html
                v-if="rules"
                :html="markdown.makeHtml(rules)"
              />
              <p v-else>
                <translate translate-context="Content/About/Paragraph">
                  No rules available.
                </translate>
              </p>

              <h3
                id="terms"
                class="ui header"
              >
                <translate translate-context="Content/About/Header">
                  Terms and privacy policy
                </translate>
              </h3>
              <sanitized-html
                v-if="terms"
                :html="markdown.makeHtml(terms)"
              />
              <p v-else>
                <translate translate-context="Content/About/Paragraph">
                  No terms available.
                </translate>
              </p>

              <h3
                id="features"
                class="header"
              >
                <translate translate-context="Content/About/Header/Name">
                  Features
                </translate>
              </h3>
              <div class="features-container ui two column stackable grid">
                <div class="column">
                  <table class="ui very basic table unstackable">
                    <tbody>
                      <tr>
                        <td>
                          <translate translate-context="*/*/*">
                            Funkwhale version
                          </translate>
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
                            <translate translate-context="*/*/*">N/A</translate>
                          </span>
                        </td>
                      </tr>
                      <tr>
                        <td>
                          <translate translate-context="*/*/*">
                            Federation
                          </translate>
                        </td>
                        <td
                          v-if="federationEnabled"
                          class="right aligned"
                        >
                          <span class="features-status ui text">
                            <i class="check icon" />
                            <translate translate-context="*/*/*/State of feature">Enabled</translate>
                          </span>
                        </td>
                        <td
                          v-else
                          class="right aligned"
                        >
                          <span class="features-status ui text">
                            <i class="x icon" />
                            <translate translate-context="*/*/*/State of feature">Disabled</translate>
                          </span>
                        </td>
                      </tr>
                      <tr>
                        <td>
                          <translate translate-context="*/*/*">
                            Allow-list
                          </translate>
                        </td>
                        <td
                          v-if="allowListEnabled"
                          class="right aligned"
                        >
                          <span class="features-status ui text">
                            <i class="check icon" />
                            <translate translate-context="*/*/*/State of feature">Enabled</translate>
                          </span>
                        </td>
                        <td
                          v-else
                          class="right aligned"
                        >
                          <span class="features-status ui text">
                            <i class="x icon" />
                            <translate translate-context="*/*/*/State of feature">Disabled</translate>
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
                          <translate translate-context="*/*/*">
                            Anonymous access
                          </translate>
                        </td>
                        <td
                          v-if="anonymousCanListen"
                          class="right aligned"
                        >
                          <span class="features-status ui text">
                            <i class="check icon" />
                            <translate translate-context="*/*/*/State of feature">Enabled</translate>
                          </span>
                        </td>
                        <td
                          v-else
                          class="right aligned"
                        >
                          <span class="features-status ui text">
                            <i class="x icon" />
                            <translate translate-context="*/*/*/State of feature">Disabled</translate>
                          </span>
                        </td>
                      </tr>
                      <tr>
                        <td>
                          <translate translate-context="*/*/*">
                            Registrations
                          </translate>
                        </td>
                        <td
                          v-if="openRegistrations"
                          class="right aligned"
                        >
                          <span class="features-status ui text">
                            <i class="check icon" />
                            <translate translate-context="*/*/*/State of registrations">Open</translate>
                          </span>
                        </td>
                        <td
                          v-else
                          class="right aligned"
                        >
                          <span class="features-status ui text">
                            <i class="x icon" />
                            <translate translate-context="*/*/*/State of registrations">Closed</translate>
                          </span>
                        </td>
                      </tr>
                      <tr>
                        <td>
                          <translate translate-context="*/*/*">
                            Upload quota
                          </translate>
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
                            <translate translate-context="*/*/*">N/A</translate>
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
                  <translate translate-context="Content/About/Header">
                    Statistics
                  </translate>
                </h3>
                <div class="statistics-container">
                  <div
                    v-if="stats.hours"
                    class="statistics-statistic"
                  >
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
                  <div
                    v-if="stats.artists"
                    class="statistics-statistic"
                  >
                    <span class="statistics-figure ui text">
                      <span class="ui big text"><strong>{{ stats.artists.toLocaleString($store.state.ui.momentLocale) }}</strong></span>
                      <br>
                      <translate
                        translate-context="Content/About/*"
                        :translate-n="stats.artists"
                        translate-plural="artists"
                      >artist</translate>
                    </span>
                  </div>
                  <div
                    v-if="stats.albums"
                    class="statistics-statistic"
                  >
                    <span class="statistics-figure ui text">
                      <span class="ui big text"><strong>{{ stats.albums.toLocaleString($store.state.ui.momentLocale) }}</strong></span>
                      <br>
                      <translate
                        translate-context="Content/About/*"
                        :translate-n="stats.albums"
                        translate-plural="albums"
                      >album</translate>
                    </span>
                  </div>
                  <div
                    v-if="stats.tracks"
                    class="statistics-statistic"
                  >
                    <span class="statistics-figure ui text">
                      <span class="ui big text"><strong>{{ stats.tracks.toLocaleString($store.state.ui.momentLocale) }}</strong></span>
                      <br>
                      <translate
                        translate-context="Content/About/*"
                        :translate-n="stats.tracks"
                        translate-plural="tracks"
                      >track</translate>
                    </span>
                  </div>
                  <div
                    v-if="stats.users"
                    class="statistics-statistic"
                  >
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
                  <div
                    v-if="stats.listenings"
                    class="statistics-statistic"
                  >
                    <span class="statistics-figure ui text">
                      <span class="ui big text"><strong>{{ stats.listenings.toLocaleString($store.state.ui.momentLocale) }}</strong></span>
                      <br>
                      <translate
                        translate-context="Content/About/*"
                        :translate-n="stats.listenings"
                        translate-plural="listenings"
                      >listening</translate>
                    </span>
                  </div>
                </div>
              </template>

              <template v-if="contactEmail">
                <h3
                  id="contact"
                  class="ui header"
                >
                  <translate translate-context="Content/About/Header">
                    Contact
                  </translate>
                </h3>
                <a
                  v-if="contactEmail"
                  :href="`mailto:${contactEmail}`"
                >
                  <translate
                    translate-context="Content/About/Email"
                    :translate-params="{ email: contactEmail }"
                  >Send us an email: {{ contactEmail }}</translate>
                </a>
              </template>

              <div class="ui hidden divider" />
              <div class="ui fluid horizontally fitted basic clearing segment container">
                <router-link
                  to="/about"
                  class="ui left floated basic secondary button"
                >
                  <i class="icon arrow left" />
                  <translate translate-context="Content/About/Paragraph">
                    Introduction
                  </translate>
                </router-link>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </main>
</template>
