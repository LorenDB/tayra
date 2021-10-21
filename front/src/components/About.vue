<template>
  <main class="main pusher page-about" v-title="labels.title">
    <div class="ui container">
      <div class="ui horizontally fitted basic stripe segment">
        <div class="ui horizontally fitted basic very padded segment">
          <div class="ui center aligned text container">
            <div class="ui text container">
              <div class="ui equal width compact stackable grid">
                <div class="column"></div>
                <div class="ten wide column">
                  <div class="ui vertically fitted basic segment">
                    <router-link to="/">
                      <logo-text />
                    </router-link>
                  </div>
                </div>
                <div class="column"></div>
              </div>
              <h2 class="header">
                <translate translate-context="Content/About/Heading">A social platform to enjoy and share music</translate>
              </h2>
              <p>
                <translate translate-context="Content/About/Paragraph">Funkwhale is a community-driven project that lets you listen and share music and audio within a decentralized, open network.</translate>
              </p>
            </div>
          </div>
        </div>
        <div class="ui hidden divider"></div>
        <div class="ui vertically fitted basic stripe segment">
          <div class="ui two stackable cards">
            <div class="ui card">
              <div class="signup-form content">
                <h3 class="header">
                  <translate translate-context="*/Signup/Title">Sign up</translate>
                </h3>
                <template v-if="openRegistrations">
                  <p>
                    <translate translate-context="Content/About/Paragraph">Sign up now to keep a track of your favorites, create playlists, discover new content and much more!</translate>
                  </p>
                  <p v-if="defaultUploadQuota">
                    <translate translate-context="Content/About/Paragraph" :translate-params="{quota: defaultUploadQuota}">Users on this pod also get %{ quota } of free storage to upload their own content!</translate>
                  </p>
                  <signup-form button-classes="success" :show-login="false"></signup-form>
                </template>
                <div v-else>
                  <p translate-context="Content/About/Paragraph">Registrations are closed on this pod. You can signup on another pod using the link below.</p>

                  <a target="_blank" rel="noopener" href="https://funkwhale.audio/#get-started">
                    <translate translate-context="Content/About/Link">Find another pod</translate>
                    <i class="external alternate icon margin-left"></i>
                  </a>
                </div>
              </div>
            </div>
            <div class="ui card">
              <section :class="['ui', 'head', {'with-background': banner}, 'vertical', 'center', 'aligned', 'stripe', 'segment']" :style="headerStyle">
              </section>
              <div class="content padding-top padding-bottom">
                <h3 class="ui header" id="description">
                  <translate translate-context="Content/About/Header">About this pod</translate>
                </h3>
                <div v-if="shortDescription" class="sub header">
                  {{ shortDescription }}
                </div>
                <p v-else>
                  <translate translate-context="Content/About/Paragraph">No description available.</translate>
                </p>

                <template v-if="stats">
                  <div class="statistics-container ui doubling grid">
                    <div class="ui six wide column">
                      <span class="statistics-figure ui text">
                        <span class="ui big text"><strong>{{ stats.users.toLocaleString($store.state.ui.momentLocale) }}</strong></span>
                        <br />
                        <translate translate-context="Content/About/*" :translate-n="stats.users" translate-plural="active users">active user</translate>
                      </span>
                    </div>
                    <div class="ui six wide column">
                      <span class="statistics-figure ui text">
                        <span class="ui big text"><strong>{{ parseInt(stats.hours).toLocaleString($store.state.ui.momentLocale) }}</strong></span>
                        <br />
                        <translate translate-context="Content/About/*" :translate-n="parseInt(stats.hours)" translate-plural="hours of music">hour of music</translate>
                      </span>
                    </div>
                  </div>
                </template>

                <router-link to="/about/pod" class="ui fluid basic secondary button">
                  <translate translate-context="Content/About/Paragraph">Learn More</translate>
                </router-link>
              </div>
            </div>
          </div>
          <div class="ui three stackable cards">
            <router-link to="/" class="ui card">
              <div class="content">
                <h3 class="ui header" id="description">
                  <translate translate-context="Content/About/Header">Browse public content</translate>
                </h3>
                <p>
                  <translate translate-context="Content/About/Paragraph">Listen to public albums and playlists shared on this pod.</translate>
                </p>
              </div>
            </router-link>
            <a href="https://funkwhale.audio/#get-started" class="ui card">
              <div class="content">
                <h3 class="ui header" id="description">
                  <translate translate-context="Content/About/Header">Find another pod</translate>
                  <i class="external alternate icon margin-left"></i>
                </h3>
                <p>
                  <translate translate-context="Content/About/Paragraph">Listen to public albums and playlists shared on this pod.</translate>
                </p>
              </div>
            </a>
            <a href="https://funkwhale.audio/apps" class="ui card">
              <div class="content">
                <h3 class="ui header" id="description">
                  <translate translate-context="Content/About/Header">Find an app</translate>
                  <i class="external alternate icon margin-left"></i>
                </h3>
                <p>
                  <translate translate-context="Content/About/Paragraph">Use Funkwhale on other devices with our apps.</translate>
                </p>
              </div>
            </a>
          </div>
          <div class="ui fluid horizontally fitted basic clearing segment container">
            <router-link to="/about/pod" class="ui right floated basic secondary button">
              <translate translate-context="Content/About/Paragraph">About this pod</translate>
              <i class="icon arrow right"></i>
            </router-link>
          </div>
        </div>
      </div>
    </div>
  </main>
</template>

<script>
import { mapState } from "vuex"
import _ from '@/lodash'
import showdown from 'showdown'
import {humanSize} from '@/filters'

import SignupForm from "@/components/auth/SignupForm"
import LogoText from "@/components/LogoText"

export default {
  components: {
    SignupForm,
    LogoText,
  },
  data () {
    return {
      markdown: new showdown.Converter(),
      showAllowedDomains: false,
    }
  },
  computed: {

  ...mapState({
      nodeinfo: state => state.instance.nodeinfo,
    }),
    labels() {
      return {
        title: this.$pgettext('Head/About/Title', "About")
      }
    },
    podName() {
      return _.get(this.nodeinfo, 'metadata.nodeName') || "Funkwhale"
    },
    banner () {
      return _.get(this.nodeinfo, 'metadata.banner')
    },
    shortDescription () {
      return _.get(this.nodeinfo, 'metadata.shortDescription')
    },
    longDescription () {
      return _.get(this.nodeinfo, 'metadata.longDescription')
    },
    rules () {
      return _.get(this.nodeinfo, 'metadata.rules')
    },
    terms () {
      return _.get(this.nodeinfo, 'metadata.terms')
    },
    stats () {
      let data = {
        users: _.get(this.nodeinfo, 'usage.users.activeMonth', null),
        hours: _.get(this.nodeinfo, 'metadata.library.music.hours', null),
        artists: _.get(this.nodeinfo, 'metadata.library.artists.total', null),
        albums: _.get(this.nodeinfo, 'metadata.library.albums.total', null),
        tracks: _.get(this.nodeinfo, 'metadata.library.tracks.total', null),
        listenings: _.get(this.nodeinfo, 'metadata.usage.listenings.total', null),
      }
      if (data.users === null || data.artists === null) {
        return
      }
      return data
    },
    contactEmail () {
      return _.get(this.nodeinfo, 'metadata.contactEmail')
    },
    anonymousCanListen () {
      return _.get(this.nodeinfo, 'metadata.library.anonymousCanListen')
    },
    allowListEnabled () {
      return _.get(this.nodeinfo, 'metadata.allowList.enabled')
    },
    allowListDomains () {
      return _.get(this.nodeinfo, 'metadata.allowList.domains')
    },
    version () {
      return _.get(this.nodeinfo, 'software.version')
    },
    openRegistrations () {
      return _.get(this.nodeinfo, 'openRegistrations')
    },
    defaultUploadQuota () {
      return humanSize(_.get(this.nodeinfo, 'metadata.defaultUploadQuota') * 1000 * 1000)
    },
    federationEnabled () {
      return _.get(this.nodeinfo, 'metadata.library.federationEnabled')
    },
    headerStyle() {
      if (!this.banner) {
        return ""
      }
      return (
        "background-image: url(" +
        this.$store.getters["instance/absoluteUrl"](this.banner) +
        ")"
      )
    },
  }
}
</script>

<style scoped>
.margin-left {
    margin-left: 5px;
}

.padding-top {
    padding-top: 20px !important;
}

.padding-bottom {
    padding-bottom: 20px !important;
}
h3 i {
    display: inline !important;
    font-size: 14px !important;
}
</style>
