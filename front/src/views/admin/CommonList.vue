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
import { useGettext } from 'vue3-gettext'

type ViewType = 'accounts' | 'albums' | 'artists' | 'channels' | 'invitations' | 'libraries' | 'tags' | 'tracks' | 'uploads' | 'users'

interface Props {
  defaultQuery?: string,
  type: ViewType
}

const props = withDefaults(defineProps<Props>(), {
  defaultQuery: ''
})

const { $pgettext } = useGettext()
const labels = computed(() => ({
  accounts: $pgettext('*/Moderation/Title', 'Accounts'),
  albums: $pgettext('*/*/*', 'Albums'),
  artists: $pgettext('*/*/*/Noun', 'Artists'),
  channels: $pgettext('*/*/*', 'Channels'),
  invitations: $pgettext('*/Admin/*/Noun', 'Invitations'),
  libraries: $pgettext('*/*/*/Noun', 'Libraries'),
  tags: $pgettext('*/*/*/Noun', 'Tags'),
  tracks: $pgettext('*/*/*', 'Tracks'),
  uploads: $pgettext('*/*/*', 'Uploads'),
  users: $pgettext('*/*/*/Noun', 'Users')
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
        :ordering-config-name="null"
      />
      <albums-table
        v-else-if="type === 'albums'"
        :update-url="true"
        :default-query="defaultQuery"
        :ordering-config-name="null"
      />
      <artists-table
        v-else-if="type === 'artists'"
        :update-url="true"
        :default-query="defaultQuery"
        :ordering-config-name="null"
      />
      <channels-table
        v-else-if="type === 'channels'"
        :update-url="true"
        :default-query="defaultQuery"
        :ordering-config-name="null"
      />
      <invitations-table
        v-else-if="type === 'invitations'"
        :ordering-config-name="null"
      />
      <libraries-table
        v-else-if="type === 'libraries'"
        :update-url="true"
        :default-query="defaultQuery"
        :ordering-config-name="null"
      />
      <tags-table
        v-else-if="type === 'tags'"
        :update-url="true"
        :default-query="defaultQuery"
        :ordering-config-name="null"
      />
      <tracks-table
        v-else-if="type === 'tracks'"
        :update-url="true"
        :default-query="defaultQuery"
        :ordering-config-name="null"
      />
      <uploads-table
        v-else-if="type === 'uploads'"
        :update-url="true"
        :default-query="defaultQuery"
        :ordering-config-name="null"
      />
      <users-table
        v-else-if="type === 'users'"
        :ordering-config-name="null"
      />
    </section>
  </main>
</template>
