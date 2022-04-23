<template>
  <main v-title="labels.accounts">
    <section class="ui vertical stripe segment">
      <h2 class="ui header">
        <translate translate-context="*/Moderation/Title">
          Accounts
        </translate>
      </h2>
      <div class="ui hidden divider" />
      <accounts-table
        :update-url="true"
        :default-query="defaultQuery"
      />
    </section>
  </main>
</template>

<script>
import AccountsTable from '~/components/manage/moderation/AccountsTable.vue'

export default {
  components: {
    AccountsTable
  },
  props: {
    defaultQuery: { type: String, required: false, default: '' }
  },
  computed: {
    labels () {
      return {
        accounts: this.$pgettext('*/Moderation/Title', 'Accounts')
      }
    }
  }
}
</script>
