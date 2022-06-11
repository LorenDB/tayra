import { gettext } from '~/init/locale'

const { $pgettext } = gettext

export default () => ({
  fields: {
    privacy_level: {
      label: $pgettext('Content/Settings/Dropdown.Label/Noun', 'Activity visibility'),
      help: $pgettext('Content/Settings/Dropdown.Help text', 'Determine the visibility level of your activity'),
      choices: {
        me: $pgettext('Content/Settings/Dropdown', 'Nobody except me'),
        instance: $pgettext('Content/Settings/Dropdown', 'Everyone on this instance'),
        everyone: $pgettext('Content/Settings/Dropdown', 'Everyone, across all instances')
      },
      shortChoices: {
        me: $pgettext('Content/Settings/Dropdown/Short', 'Private'),
        instance: $pgettext('Content/Settings/Dropdown/Short', 'Instance'),
        everyone: $pgettext('Content/Settings/Dropdown/Short', 'Everyone')
      }
    },
    import_status: {
      detailTitle: $pgettext('Content/Library/Link.Title', 'Click to display more information about the import process for this upload'),
      choices: {
        skipped: {
          label: $pgettext('Content/Library/*', 'Skipped'),
          help: $pgettext('Content/Library/Help text', 'This track is already present in one of your libraries')
        },
        draft: {
          label: $pgettext('Content/Library/*/Short', 'Draft'),
          help: $pgettext('Content/Library/Help text', 'This track has been uploaded, but hasn\'t been scheduled for processing yet')
        },
        pending: {
          label: $pgettext('Content/Library/*/Short', 'Pending'),
          help: $pgettext('Content/Library/Help text', 'This track has been uploaded, but hasn\'t been processed by the server yet')
        },
        errored: {
          label: $pgettext('Content/Library/Table/Short', 'Errored'),
          help: $pgettext('Content/Library/Help text', 'This track could not be processed, please make sure it is tagged correctly')
        },
        finished: {
          label: $pgettext('Content/Library/*', 'Finished'),
          help: $pgettext('Content/Library/Help text', 'Imported')
        }
      }
    },
    report_type: {
      label: $pgettext('*/*/*', 'Category'),
      choices: {
        takedown_request: $pgettext('Content/Moderation/Dropdown', 'Takedown request'),
        invalid_metadata: $pgettext('Popup/Import/Error.Label', 'Invalid metadata'),
        illegal_content: $pgettext('Content/Moderation/Dropdown', 'Illegal content'),
        offensive_content: $pgettext('Content/Moderation/Dropdown', 'Offensive content'),
        other: $pgettext('Content/Moderation/Dropdown', 'Other')
      }
    },
    summary: {
      label: $pgettext('Content/Account/*', 'Bio')
    },
    content_category: {
      label: $pgettext('Content/*/Dropdown.Label/Noun', 'Content category'),
      choices: {
        podcast: $pgettext('Content/*/Dropdown', 'Podcast'),
        music: $pgettext('*/*/*', 'Music'),
        other: $pgettext('*/*/*', 'Other')
      }
    }
  },
  filters: {
    creation_date: $pgettext('Content/*/*/Noun', 'Creation date'),
    release_date: $pgettext('Content/*/*/Noun', 'Release date'),
    accessed_date: $pgettext('Content/*/*/Noun', 'Accessed date'),
    applied_date: $pgettext('Content/*/*/Noun', 'Applied date'),
    first_seen: $pgettext('Content/Moderation/Dropdown/Noun', 'First seen date'),
    last_seen: $pgettext('Content/Moderation/Dropdown/Noun', 'Last seen date'),
    modification_date: $pgettext('Content/Playlist/Dropdown/Noun', 'Modification date'),
    expiration_date: $pgettext('Content/Admin/Table.Label/Noun', 'Expiration date'),
    track_title: $pgettext('Content/*/Dropdown/Noun', 'Track name'),
    album_title: $pgettext('Content/*/Dropdown/Noun', 'Album name'),
    artist_name: $pgettext('Content/*/Dropdown/Noun', 'Artist name'),
    name: $pgettext('*/*/*/Noun', 'Name'),
    length: $pgettext('*/*/*/Noun', 'Duration'),
    items_count: $pgettext('*/*/*/Noun', 'Items'),
    size: $pgettext('Content/*/*/Noun', 'Size'),
    bitrate: $pgettext('Content/Track/*/Noun', 'Bitrate'),
    duration: $pgettext('Content/*/*', 'Duration'),
    date_joined: $pgettext('Content/Admin/Table.Label/Noun', 'Sign-up date'),
    last_activity: $pgettext('Content/Profile/Table.Label/Short, Noun (Value is a date)', 'Last activity'),
    username: $pgettext('Content/*/*', 'Username'),
    domain: $pgettext('Content/Moderation/*/Noun', 'Domain'),
    users: $pgettext('*/*/*/Noun', 'Users'),
    received_messages: $pgettext('Content/Moderation/*/Noun', 'Received messages'),
    uploads: $pgettext('*/*/*', 'Uploads'),
    followers: $pgettext('Content/Federation/*/Noun', 'Followers')
  },
  scopes: {
    profile: {
      label: $pgettext('Content/OAuth Scopes/Label', 'Profile'),
      description: $pgettext('Content/OAuth Scopes/Paragraph', 'Access to e-mail, username, and profile information')
    },
    libraries: {
      label: $pgettext('Content/OAuth Scopes/Label', 'Libraries and uploads'),
      description: $pgettext('Content/OAuth Scopes/Paragraph', 'Access to audio files, libraries, artists, albums and tracks')
    },
    favorites: {
      label: $pgettext('Sidebar/Favorites/List item.Link/Noun', 'Favorites'),
      description: $pgettext('Content/OAuth Scopes/Paragraph', 'Access to favorites')
    },
    listenings: {
      label: $pgettext('*/*/*/Noun', 'Listenings'),
      description: $pgettext('Content/OAuth Scopes/Paragraph', 'Access to listening history')
    },
    follows: {
      label: $pgettext('Content/OAuth Scopes/Label', 'Follows'),
      description: $pgettext('Content/OAuth Scopes/Paragraph', 'Access to follows')
    },
    playlists: {
      label: $pgettext('*/*/*', 'Playlists'),
      description: $pgettext('Content/OAuth Scopes/Paragraph', 'Access to playlists')
    },
    radios: {
      label: $pgettext('*/*/*', 'Radios'),
      description: $pgettext('Content/OAuth Scopes/Paragraph', 'Access to radios')
    },
    filters: {
      label: $pgettext('Content/Settings/Title/Noun', 'Content filters'),
      description: $pgettext('Content/OAuth Scopes/Paragraph', 'Access to content filters')
    },
    notifications: {
      label: $pgettext('*/Notifications/*', 'Notifications'),
      description: $pgettext('Content/OAuth Scopes/Paragraph', 'Access to notifications')
    },
    edits: {
      label: $pgettext('*/Admin/*/Noun', 'Edits'),
      description: $pgettext('Content/OAuth Scopes/Paragraph', 'Access to edits')
    },
    security: {
      label: $pgettext('*/Admin/*/Noun', 'Security'),
      description: $pgettext('Content/OAuth Scopes/Paragraph', 'Access to security settings such as password and authorization')
    },
    reports: {
      label: $pgettext('*/Moderation/*/Noun', 'Reports'),
      description: $pgettext('Content/OAuth Scopes/Paragraph', 'Access to moderation reports')
    }
  }
})
