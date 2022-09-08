import type { PrivacyLevel, ImportStatus } from '~/types'
import type { ScopeId } from '~/composables/auth/useScopes'

import { i18n } from '~/init/locale'

const { t } = i18n.global

export default () => ({
  fields: {
    privacy_level: {
      label: t('Activity visibility'),
      help: t('Determine the visibility level of your activity'),
      choices: {
        me: t('Nobody except me'),
        instance: t('Everyone on this instance'),
        everyone: t('Everyone, across all instances')
      } as Record<PrivacyLevel, string>,
      shortChoices: {
        me: t('Private'),
        instance: t('Instance'),
        everyone: t('Everyone')
      } as Record<PrivacyLevel, string>
    },
    import_status: {
      label: t('Click to display more information about the import process for this upload'),
      choices: {
        skipped: {
          label: t('Skipped'),
          help: t('This track is already present in one of your libraries')
        },
        draft: {
          label: t('Draft'),
          help: t('This track has been uploaded, but hasn\'t been scheduled for processing yet')
        },
        pending: {
          label: t('Pending'),
          help: t('This track has been uploaded, but hasn\'t been processed by the server yet')
        },
        errored: {
          label: t('Errored'),
          help: t('This track could not be processed, please make sure it is tagged correctly')
        },
        finished: {
          label: t('Finished'),
          help: t('Imported')
        }
      } as Record<ImportStatus, { label: string, help: string }>
    },
    report_type: {
      label: t('Category'),
      choices: {
        takedown_request: t('Takedown request'),
        invalid_metadata: t('Invalid metadata'),
        illegal_content: t('Illegal content'),
        offensive_content: t('Offensive content'),
        other: t('Other')
      }
    },
    summary: {
      label: t('Bio'),
      help: undefined
    },
    content_category: {
      label: t('Content category'),
      choices: {
        podcast: t('Podcast'),
        music: t('Music'),
        other: t('Other')
      }
    }
  },
  filters: {
    creation_date: t('Creation date'),
    release_date: t('Release date'),
    accessed_date: t('Accessed date'),
    applied_date: t('Applied date'),
    handled_date: t('Handled date'),
    first_seen: t('First seen date'),
    last_seen: t('Last seen date'),
    modification_date: t('Modification date'),
    expiration_date: t('Expiration date'),
    track_title: t('Track name'),
    album_title: t('Album name'),
    artist_name: t('Artist name'),
    name: t('Name'),
    length: t('Duration'),
    items_count: t('Items'),
    size: t('Size'),
    bitrate: t('Bitrate'),
    duration: t('Duration'),
    date_joined: t('Sign-up date'),
    last_activity: t('Last activity'),
    username: t('Username'),
    domain: t('Domain'),
    users: t('Users'),
    received_messages: t('Received messages'),
    uploads: t('Uploads'),
    followers: t('Followers')
  },
  scopes: {
    profile: {
      label: t('Profile'),
      description: t('Access to e-mail, username, and profile information')
    },
    libraries: {
      label: t('Libraries and uploads'),
      description: t('Access to audio files, libraries, artists, albums and tracks')
    },
    favorites: {
      label: t('Favorites'),
      description: t('Access to favorites')
    },
    listenings: {
      label: t('Listenings'),
      description: t('Access to listening history')
    },
    follows: {
      label: t('Follows'),
      description: t('Access to follows')
    },
    playlists: {
      label: t('Playlists'),
      description: t('Access to playlists')
    },
    radios: {
      label: t('Radios'),
      description: t('Access to radios')
    },
    filters: {
      label: t('Content filters'),
      description: t('Access to content filters')
    },
    notifications: {
      label: t('Notifications'),
      description: t('Access to notifications')
    },
    edits: {
      label: t('Edits'),
      description: t('Access to edits')
    },
    security: {
      label: t('Security'),
      description: t('Access to security settings such as password and authorization')
    },
    reports: {
      label: t('Reports'),
      description: t('Access to moderation reports')
    }
  } as Record<ScopeId, { label: string, description: string }>
})
