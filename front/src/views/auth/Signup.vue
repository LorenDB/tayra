<template>
  <main
    v-title="labels.title"
    class="main pusher"
  >
    <section class="ui vertical stripe segment">
      <div class="ui small text container">
        <h2>
          <translate translate-context="Content/Signup/Title">
            Create a Funkwhale account
          </translate>
        </h2>
        <signup-form
          :default-invitation="defaultInvitation"
          :next="next"
        />
      </div>
    </section>
  </main>
</template>

<script>

import SignupForm from '~/components/auth/SignupForm.vue'

export default {
  components: {
    SignupForm
  },
  props: {
    defaultInvitation: { type: String, required: false, default: null },
    next: { type: String, default: '/' }
  },
  data () {
    return {
      username: '',
      email: '',
      password: '',
      isLoadingInstanceSetting: true,
      errors: [],
      isLoading: false,
      invitation: this.defaultInvitation
    }
  },
  computed: {
    labels () {
      const title = this.$pgettext('*/Signup/Title', 'Sign Up')
      return {
        title
      }
    }
  }
}
</script>
