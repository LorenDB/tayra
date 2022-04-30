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
          <span
            v-translate="{podName: podName}"
            translate-context="Content/Home/Header"
            :translate-params="{podName: podName}"
          >
            Welcome to %{ podName }!
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
            <translate translate-context="Content/Home/Header">
              About this Funkwhale pod
            </translate>
          </h2>
          <div
            id="pod"
            class="ui raised segment"
          >
            <div class="ui stackable grid">
              <div class="eight wide column">
                <p v-if="!renderedDescription">
                  <translate translate-context="Content/Home/Paragraph">
                    No description available.
                  </translate>
                </p>
                <template v-if="renderedDescription || rules">
                  <div
                    v-if="renderedDescription"
                    id="renderedDescription"
                    v-html="renderedDescription"
                  />
                  <div
                    v-if="renderedDescription"
                    class="ui hidden divider"
                  />
                  <div class="ui relaxed list">
                    <div
                      v-if="renderedDescription"
                      class="item"
                    >
                      <i class="arrow right icon" />
                      <div class="content">
                        <router-link
                          class="ui link"
                          :to="{name: 'about'}"
                        >
                          <translate translate-context="Content/Home/Link">
                            Learn more
                          </translate>
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
                          <translate translate-context="Content/Home/Link">
                            Server rules
                          </translate>
                        </router-link>
                      </div>
                    </div>
                  </div>
                </template>
              </div>
              <div class="eight wide column">
                <template v-if="stats">
                  <h3 class="sub header">
                    <translate translate-context="Content/Home/Header">
                      Statistics
                    </translate>
                  </h3>
                  <p>
                    <i class="user icon" /><translate
                      translate-context="Content/Home/Stat"
                      :translate-params="{count: stats.users.toLocaleString($store.state.ui.momentLocale) }"
                      :translate-n="stats.users"
                      translate-plural="%{ count } active users"
                    >
                      %{ count } active user
                    </translate>
                  </p>
                  <p>
                    <i class="music icon" /><translate
                      translate-context="Content/Home/Stat"
                      :translate-params="{count: parseInt(stats.hours).toLocaleString($store.state.ui.momentLocale)}"
                      :translate-n="parseInt(stats.hours)"
                      translate-plural="%{ count } hours of music"
                    >
                      %{ count } hour of music
                    </translate>
                  </p>
                </template>
                <template v-if="contactEmail">
                  <h3 class="sub header">
                    <translate translate-context="Content/Home/Header/Name">
                      Contact
                    </translate>
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
            <translate translate-context="Footer/*/Title/Short">
              About Funkwhale
            </translate>
          </h3>
          <p
            v-translate
            translate-context="Content/Home/Paragraph"
          >
            This pod runs Funkwhale, a community-driven project that lets you listen and share music and audio within a decentralized, open network.
          </p>
          <p
            v-translate
            translate-context="Content/Home/Paragraph"
          >
            Funkwhale is free and developed by a friendly community of volunteers.
          </p>
          <a
            target="_blank"
            rel="noopener"
            href="https://funkwhale.audio"
          >
            <i class="external alternate icon" />
            <translate translate-context="Content/Home/Link">Visit funkwhale.audio</translate>
          </a>
        </div>
        <div class="four wide column">
          <h3 class="header">
            <translate translate-context="Head/Login/Title">
              Log In
            </translate>
          </h3>
          <login-form
            button-classes="success"
            :show-signup="false"
          />
          <div class="ui hidden clearing divider" />
        </div>
        <div class="four wide column">
          <h3 class="header">
            <translate translate-context="*/Signup/Title">
              Sign up
            </translate>
          </h3>
          <template v-if="openRegistrations">
            <p>
              <translate translate-context="Content/Home/Paragraph">
                Sign up now to keep track of your favorites, create playlists, discover new content and much more!
              </translate>
            </p>
            <p v-if="defaultUploadQuota">
              <translate
                translate-context="Content/Home/Paragraph"
                :translate-params="{quota: humanSize(defaultUploadQuota * 1000 * 1000)}"
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
            <p translate-context="Content/Home/Paragraph">
              Registrations are closed on this pod. You can signup on another pod using the link below.
            </p>
            <a
              target="_blank"
              rel="noopener"
              href="https://funkwhale.audio/#get-started"
            >
              <i class="external alternate icon" />
              <translate translate-context="Content/Home/Link">Find another pod</translate>
            </a>
          </div>
        </div>

        <div class="four wide column">
          <h3 class="header">
            <translate translate-context="Content/Home/Header">
              Useful links
            </translate>
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
                  <translate translate-context="Content/Home/Link">
                    Browse public content
                  </translate>
                </router-link>
                <div class="description">
                  <translate translate-context="Content/Home/Link">
                    Listen to public albums and playlists shared on this pod
                  </translate>
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
                  <translate translate-context="Content/Home/Link">Mobile apps</translate>
                </a>
                <div class="description">
                  <translate translate-context="Content/Home/Link">
                    Use Funkwhale on other devices with our apps
                  </translate>
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
                  <translate translate-context="Content/Home/Link">User guides</translate>
                </a>
                <div class="description">
                  <translate translate-context="Content/Home/Link">
                    Discover everything you need to know about Funkwhale and its features
                  </translate>
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
        <template slot="title">
          <translate translate-context="Content/Home/Title">
            Recently added albums
          </translate>
        </template>
        <router-link to="/library">
          <translate translate-context="Content/Home/Link">
            View more…
          </translate>
          <div class="ui hidden divider" />
        </router-link>
      </album-widget>
      <div class="ui hidden section divider" />
      <h3 class="ui header">
        <translate translate-context="*/*/*">
          New channels
        </translate>
      </h3>
      <channels-widget
        :show-modification-date="true"
        :limit="10"
        :filters="{ordering: '-creation_date', external: 'false'}"
      />
    </section>
  </main>
</template>

<script>
import { get } from 'lodash-es'
import { mapState } from 'vuex'
import showdown from 'showdown'
import AlbumWidget from '~/components/audio/album/Widget.vue'
import ChannelsWidget from '~/components/audio/ChannelsWidget.vue'
import LoginForm from '~/components/auth/LoginForm.vue'
import SignupForm from '~/components/auth/SignupForm.vue'
import { humanSize } from '~/utils/filters'

export default {
  components: {
    AlbumWidget,
    ChannelsWidget,
    LoginForm,
    SignupForm
  },
  data () {
    return {
      markdown: new showdown.Converter(),
      excerptLength: 2, // html nodes,
      humanSize
    }
  },
  computed: {
    ...mapState({
      nodeinfo: state => state.instance.nodeinfo
    }),
    labels () {
      return {
        title: this.$pgettext('Head/Home/Title', 'Home')
      }
    },
    podName () {
      return get(this.nodeinfo, 'metadata.nodeName') || 'Funkwhale'
    },
    banner () {
      return get(this.nodeinfo, 'metadata.banner')
    },
    shortDescription () {
      return get(this.nodeinfo, 'metadata.shortDescription')
    },
    longDescription () {
      return get(this.nodeinfo, 'metadata.longDescription')
    },
    rules () {
      return get(this.nodeinfo, 'metadata.rules')
    },
    renderedDescription () {
      if (!this.longDescription) {
        return
      }
      const doc = this.markdown.makeHtml(this.longDescription)
      return doc
    },
    stats () {
      const data = {
        users: get(this.nodeinfo, 'usage.users.activeMonth', null),
        hours: get(this.nodeinfo, 'metadata.library.music.hours', null)
      }
      if (data.users === null || data.artists === null) {
        return
      }
      return data
    },
    contactEmail () {
      return get(this.nodeinfo, 'metadata.contactEmail')
    },
    defaultUploadQuota () {
      return get(this.nodeinfo, 'metadata.defaultUploadQuota')
    },
    anonymousCanListen () {
      return get(this.nodeinfo, 'metadata.library.anonymousCanListen')
    },
    openRegistrations () {
      return get(this.nodeinfo, 'openRegistrations')
    },
    headerStyle () {
      if (!this.banner) {
        return ''
      }
      return (
        'background-image: url(' +
        this.$store.getters['instance/absoluteUrl'](this.banner) +
        ')'
      )
    }
  },
  watch: {
    '$store.state.auth.authenticated': {
      handler (v) {
        if (v) {
          console.log('Authenticated, redirecting to /library…')
          this.$router.push('/library')
        }
      },
      immediate: true
    }
  }

}
</script>
