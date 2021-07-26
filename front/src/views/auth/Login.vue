<template>
  <main class="main pusher" v-title="labels.title">
    <section class="ui vertical stripe segment">
      <div class="ui small text container">
        <h2><translate translate-context="Content/Login/Title/Verb">Log in to your Funkwhale account</translate></h2>
        <login-form :next="redirectTo"></login-form>
      </div>
    </section>
  </main>
</template>

<script>
import LoginForm from '@/components/auth/LoginForm'

export default {
  props: {
    next: { type: String, default: '/library' }
  },
  data () {
    return {
      redirectTo: this.next
    }
  },
  components: {
    LoginForm
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
  },
  computed: {
    labels () {
      const title = this.$pgettext('Head/Login/Title', 'Log In')
      return {
        title
      }
    }
  }
}
</script>
