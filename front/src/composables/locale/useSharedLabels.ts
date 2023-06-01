import type { PrivacyLevel, ImportStatus } from '~/types'
import type { ScopeId } from '~/composables/auth/useScopes'

import { i18n } from '~/init/locale'

const { t } = i18n.global

export default () => ({
  fields: {
    privacy_level: {
      label: t('composables.locale.useSharedLabels.fields.privacyLevel.label'),
      help: t('composables.locale.useSharedLabels.fields.privacyLevel.help'),
      choices: {
        me: t('composables.locale.useSharedLabels.fields.privacyLevel.choices.private'),
        instance: t('composables.locale.useSharedLabels.fields.privacyLevel.choices.instance'),
        everyone: t('composables.locale.useSharedLabels.fields.privacyLevel.choices.public')
      } as Record<PrivacyLevel, string>,
      shortChoices: {
        me: t('composables.locale.useSharedLabels.fields.privacyLevel.shortChoices.private'),
        instance: t('composables.locale.useSharedLabels.fields.privacyLevel.shortChoices.instance'),
        everyone: t('composables.locale.useSharedLabels.fields.privacyLevel.shortChoices.public')
      } as Record<PrivacyLevel, string>
    },
    import_status: {
      label: t('composables.locale.useSharedLabels.fields.importStatus.label'),
      choices: {
        skipped: {
          label: t('composables.locale.useSharedLabels.fields.importStatus.choices.skipped.label'),
          help: t('composables.locale.useSharedLabels.fields.importStatus.choices.skipped.help')
        },
        draft: {
          label: t('composables.locale.useSharedLabels.fields.importStatus.choices.draft.label'),
          help: t('composables.locale.useSharedLabels.fields.importStatus.choices.draft.help')
        },
        pending: {
          label: t('composables.locale.useSharedLabels.fields.importStatus.choices.pending.label'),
          help: t('composables.locale.useSharedLabels.fields.importStatus.choices.pending.help')
        },
        errored: {
          label: t('composables.locale.useSharedLabels.fields.importStatus.choices.errored.label'),
          help: t('composables.locale.useSharedLabels.fields.importStatus.choices.errored.help')
        },
        finished: {
          label: t('composables.locale.useSharedLabels.fields.importStatus.choices.finished.label'),
          help: t('composables.locale.useSharedLabels.fields.importStatus.choices.finished.help')
        }
      } as Record<ImportStatus, { label: string, help: string }>
    },
    report_type: {
      label: t('composables.locale.useSharedLabels.fields.reportType.label'),
      choices: {
        takedown_request: t('composables.locale.useSharedLabels.fields.reportType.choices.takedownRequest'),
        invalid_metadata: t('composables.locale.useSharedLabels.fields.reportType.choices.invalidMetadata'),
        illegal_content: t('composables.locale.useSharedLabels.fields.reportType.choices.illegalContent'),
        offensive_content: t('composables.locale.useSharedLabels.fields.reportType.choices.offensiveContent'),
        other: t('composables.locale.useSharedLabels.fields.reportType.choices.other')
      }
    },
    summary: {
      label: t('composables.locale.useSharedLabels.fields.summary.label'),
      help: undefined
    },
    content_category: {
      label: t('composables.locale.useSharedLabels.fields.contentCategory.label'),
      choices: {
        podcast: t('composables.locale.useSharedLabels.fields.contentCategory.choices.podcast'),
        music: t('composables.locale.useSharedLabels.fields.contentCategory.choices.music'),
        other: t('composables.locale.useSharedLabels.fields.contentCategory.choices.other')
      }
    }
  },
  filters: {
    creation_date: t('composables.locale.useSharedLabels.filters.creationDate'),
    release_date: t('composables.locale.useSharedLabels.filters.releaseDate'),
    accessed_date: t('composables.locale.useSharedLabels.filters.accessedDate'),
    applied_date: t('composables.locale.useSharedLabels.filters.appliedDate'),
    handled_date: t('composables.locale.useSharedLabels.filters.handledDate'),
    first_seen: t('composables.locale.useSharedLabels.filters.firstSeen'),
    last_seen: t('composables.locale.useSharedLabels.filters.lastSeen'),
    modification_date: t('composables.locale.useSharedLabels.filters.modificationDate'),
    expiration_date: t('composables.locale.useSharedLabels.filters.expirationDate'),
    track_title: t('composables.locale.useSharedLabels.filters.trackTitle'),
    album_title: t('composables.locale.useSharedLabels.filters.albumTitle'),
    artist_name: t('composables.locale.useSharedLabels.filters.artistName'),
    name: t('composables.locale.useSharedLabels.filters.name'),
    length: t('composables.locale.useSharedLabels.filters.duration'),
    items_count: t('composables.locale.useSharedLabels.filters.itemsCount'),
    size: t('composables.locale.useSharedLabels.filters.size'),
    bitrate: t('composables.locale.useSharedLabels.filters.bitrate'),
    duration: t('composables.locale.useSharedLabels.filters.duration'),
    date_joined: t('composables.locale.useSharedLabels.filters.dateJoined'),
    last_activity: t('composables.locale.useSharedLabels.filters.lastActivity'),
    username: t('composables.locale.useSharedLabels.filters.username'),
    domain: t('composables.locale.useSharedLabels.filters.domain'),
    users: t('composables.locale.useSharedLabels.filters.users'),
    received_messages: t('composables.locale.useSharedLabels.filters.receivedMessages'),
    uploads: t('composables.locale.useSharedLabels.filters.uploads'),
    followers: t('composables.locale.useSharedLabels.filters.followers')
  },
  scopes: {
    profile: {
      label: t('composables.locale.useSharedLabels.scopes.profile.label'),
      description: t('composables.locale.useSharedLabels.scopes.profile.description')
    },
    libraries: {
      label: t('composables.locale.useSharedLabels.scopes.libraries.label'),
      description: t('composables.locale.useSharedLabels.scopes.libraries.description')
    },
    favorites: {
      label: t('composables.locale.useSharedLabels.scopes.favorites.label'),
      description: t('composables.locale.useSharedLabels.scopes.favorites.description')
    },
    listenings: {
      label: t('composables.locale.useSharedLabels.scopes.listenings.label'),
      description: t('composables.locale.useSharedLabels.scopes.listenings.description')
    },
    follows: {
      label: t('composables.locale.useSharedLabels.scopes.follows.label'),
      description: t('composables.locale.useSharedLabels.scopes.follows.description')
    },
    playlists: {
      label: t('composables.locale.useSharedLabels.scopes.playlists.label'),
      description: t('composables.locale.useSharedLabels.scopes.playlists.description')
    },
    radios: {
      label: t('composables.locale.useSharedLabels.scopes.radios.label'),
      description: t('composables.locale.useSharedLabels.scopes.radios.description')
    },
    filters: {
      label: t('composables.locale.useSharedLabels.scopes.filters.label'),
      description: t('composables.locale.useSharedLabels.scopes.filters.description')
    },
    notifications: {
      label: t('composables.locale.useSharedLabels.scopes.notifications.label'),
      description: t('composables.locale.useSharedLabels.scopes.notifications.description')
    },
    edits: {
      label: t('composables.locale.useSharedLabels.scopes.edits.label'),
      description: t('composables.locale.useSharedLabels.scopes.edits.description')
    },
    security: {
      label: t('composables.locale.useSharedLabels.scopes.security.label'),
      description: t('composables.locale.useSharedLabels.scopes.security.description')
    },
    reports: {
      label: t('composables.locale.useSharedLabels.scopes.reports.label'),
      description: t('composables.locale.useSharedLabels.scopes.reports.description')
    }
  } as Record<ScopeId, { label: string, description: string }>
})
