<template>
  <main
    v-title="labels.title"
    class="main pusher"
  >
    <section class="ui vertical stripe segment">
      <div class="ui small text container">
        <h2>
          <translate translate-context="Content/Login/Title/Verb">
            Log in to your Funkwhale account
          </translate>
        </h2>
        <login-form :next="redirectTo" />
      </div>
    </section>
  </main>
</template>

<script>
import LoginForm from '~/components/auth/LoginForm.vue'

export default {
  components: {
    LoginForm
  },
  props: {
    next: { type: String, default: '/library' }
  },
  data () {
    return {
      redirectTo: this.next
    }
  },
  computed: {
    labels () {
      const title = this.$pgettext('Head/Login/Title', 'Log In')
      return {
        title
      }
    }
  },
  created () {
    const resolved = this.$router.resolve(this.redirectTo)
    console.log(resolved.route.name)
    if (resolved.route.name === '404') {
      this.redirectTo = '/library'
    }
    if (this.$store.state.auth.authenticated) {
      this.$router.push(this.redirectTo)
    }
  }
}
</script>
