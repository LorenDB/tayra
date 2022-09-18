<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { computed, ref } from 'vue'
import { get } from 'lodash-es'

import axios from 'axios'

const { t } = useI18n()

const allowListEnabled = ref(false)
const labels = computed(() => ({
  moderation: t('views.admin.moderation.Base.moderation'),
  secondaryMenu: t('views.admin.moderation.Base.secondaryMenu')
}))

const fetchNodeInfo = async () => {
  const response = await axios.get('instance/nodeinfo/2.0/')
  allowListEnabled.value = get(response.data, 'metadata.allowList.enabled', false)
}

fetchNodeInfo()
</script>

<template>
  <div
    v-title="labels.moderation"
    class="main pusher"
  >
    <nav
      class="ui secondary pointing menu"
      role="navigation"
      :aria-label="labels.secondaryMenu"
    >
      <router-link
        class="ui item"
        :to="{name: 'manage.moderation.reports.list', query: {q: 'resolved:no'}}"
      >
        {{ $t('views.admin.moderation.Base.reportsLink') }}
        <div
          v-if="$store.state.ui.notifications.pendingReviewReports > 0"
          :class="['ui', 'circular', 'mini', 'right floated', 'accent', 'label']"
        >
          {{ $store.state.ui.notifications.pendingReviewReports }}
        </div>
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.moderation.requests.list', query: {q: 'status:pending'}}"
      >
        {{ $t('views.admin.moderation.Base.userRequestsLink') }}
        <div
          v-if="$store.state.ui.notifications.pendingReviewRequests > 0"
          :class="['ui', 'circular', 'mini', 'right floated', 'accent', 'label']"
        >
          {{ $store.state.ui.notifications.pendingReviewRequests }}
        </div>
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.moderation.domains.list'}"
      >
        {{ $t('views.admin.moderation.Base.domainsLink') }}
      </router-link>
      <router-link
        class="ui item"
        :to="{name: 'manage.moderation.accounts.list'}"
      >
        {{ $t('views.admin.moderation.Base.accountsLink') }}
      </router-link>
    </nav>
    <router-view
      :key="$route.fullPath"
      :allow-list-enabled="allowListEnabled"
    />
  </div>
</template>
