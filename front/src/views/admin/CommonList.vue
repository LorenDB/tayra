<script setup lang="ts">
import AccountsTable from '~/components/manage/moderation/AccountsTable.vue'
import ArtistsTable from '~/components/manage/library/ArtistsTable.vue'
import AlbumsTable from '~/components/manage/library/AlbumsTable.vue'
import ChannelsTable from '~/components/manage/ChannelsTable.vue'
import InvitationForm from '~/components/manage/users/InvitationForm.vue'
import InvitationsTable from '~/components/manage/users/InvitationsTable.vue'
import LibrariesTable from '~/components/manage/library/LibrariesTable.vue'
import TagsTable from '~/components/manage/library/TagsTable.vue'
import TracksTable from '~/components/manage/library/TracksTable.vue'
import UploadsTable from '~/components/manage/library/UploadsTable.vue'
import UsersTable from '~/components/manage/users/UsersTable.vue'

import { computed } from 'vue'
import { useI18n } from 'vue-i18n'

type ViewType = 'accounts' | 'albums' | 'artists' | 'channels' | 'invitations' | 'libraries' | 'tags' | 'tracks' | 'uploads' | 'users'

interface Props {
  defaultQuery?: string,
  type: ViewType
}

const props = withDefaults(defineProps<Props>(), {
  defaultQuery: ''
})

const { t } = useI18n()
const labels = computed(() => ({
  accounts: t('Accounts'),
  albums: t('Albums'),
  artists: t('Artists'),
  channels: t('Channels'),
  invitations: t('Invitations'),
  libraries: t('Libraries'),
  tags: t('Tags'),
  tracks: t('Tracks'),
  uploads: t('Uploads'),
  users: t('Users')
}))

const title = computed(() => labels.value[props.type])
</script>

<template>
  <main v-title="title">
    <section class="ui vertical stripe segment">
      <h2 class="ui header">
        {{ title }}
      </h2>
      <invitation-form v-if="type === 'invitations'" />
      <div class="ui hidden divider" />
      <accounts-table
        v-if="type === 'accounts'"
        :update-url="true"
        :default-query="defaultQuery"
      />
      <albums-table
        v-else-if="type === 'albums'"
        :update-url="true"
        :default-query="defaultQuery"
      />
      <artists-table
        v-else-if="type === 'artists'"
        :update-url="true"
        :default-query="defaultQuery"
      />
      <channels-table
        v-else-if="type === 'channels'"
        :update-url="true"
        :default-query="defaultQuery"
      />
      <invitations-table v-else-if="type === 'invitations'" />
      <libraries-table
        v-else-if="type === 'libraries'"
        :update-url="true"
        :default-query="defaultQuery"
      />
      <tags-table
        v-else-if="type === 'tags'"
        :update-url="true"
        :default-query="defaultQuery"
      />
      <tracks-table
        v-else-if="type === 'tracks'"
        :update-url="true"
        :default-query="defaultQuery"
      />
      <uploads-table
        v-else-if="type === 'uploads'"
        :update-url="true"
        :default-query="defaultQuery"
      />
      <users-table v-else-if="type === 'users'" />
    </section>
  </main>
</template>
