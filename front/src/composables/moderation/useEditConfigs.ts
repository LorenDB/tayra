import type { Album, Artist, Content, Track, Actor } from '~/types'

import { i18n } from '~/init/locale'

export interface ConfigField {
  id: string
  label: string
  type: 'content' | 'attachment' | 'tags' | 'text' | 'license'
  inputType?: 'text' | 'number'
  required: boolean
  getValue: (obj: EditObject) => unknown
  getValueRepr?: (obj: any) => string
}

export interface EditableConfigField extends ConfigField {
  id: EditObjectType
}

export type EditObject = (Partial<Artist> | Partial<Album> | Partial<Track>) & { attributed_to: Actor }
export type EditObjectType = 'artist' | 'album' | 'track'
type Configs = Record<EditObjectType, { fields: (EditableConfigField|ConfigField)[] }>

const getContentValueRepr = (val: Content) => val.text

// TODO: Get params from typescript type somehow?
export default (): Configs => {
  const { t } = i18n.global

  const description: ConfigField = {
    id: 'description',
    type: 'content',
    required: true,
    label: t('composables.moderation.useEditConfigs.description.label'),
    getValue: (obj) => obj.description ?? { text: '', content_type: 'text/markdown' },
    getValueRepr: getContentValueRepr
  }

  const cover: ConfigField = {
    id: 'cover',
    type: 'attachment',
    required: false,
    label: t('composables.moderation.useEditConfigs.cover.label'),
    getValue: (obj) => obj.cover?.uuid ?? null
  }

  const tags: ConfigField = {
    id: 'tags',
    type: 'tags',
    required: true,
    label: t('composables.moderation.useEditConfigs.tags.label'),
    getValue: (obj) => { return obj.tags },
    getValueRepr: (tags: string[]) => tags.slice().sort().join('\n')
  }

  return {
    artist: {
      fields: [
        {
          id: 'name',
          type: 'text',
          required: true,
          label: t('composables.moderation.useEditConfigs.artist.name'),
          getValue: (artist) => (artist as Artist).name
        },
        description,
        cover,
        tags
      ]
    },
    album: {
      fields: [
        {
          id: 'title',
          type: 'text',
          required: true,
          label: t('composables.moderation.useEditConfigs.album.title'),
          getValue: (album) => (album as Album).title
        },
        description,
        {
          id: 'release_date',
          type: 'text',
          required: false,
          label: t('composables.moderation.useEditConfigs.album.releaseDate'),
          getValue: (album) => (album as Album).release_date
        },
        cover,
        tags
      ]
    },
    track: {
      fields: [
        {
          id: 'title',
          type: 'text',
          required: true,
          label: t('composables.moderation.useEditConfigs.track.title'),
          getValue: (track) => (track as Track).title
        },
        description,
        cover,
        {
          id: 'position',
          type: 'text',
          inputType: 'number',
          required: false,
          label: t('composables.moderation.useEditConfigs.track.position'),
          getValue: (track) => (track as Track).position
        },
        {
          id: 'copyright',
          type: 'text',
          required: false,
          label: t('composables.moderation.useEditConfigs.track.copyright'),
          getValue: (track) => (track as Track).copyright
        },
        {
          id: 'license',
          type: 'license',
          required: false,
          label: t('composables.moderation.useEditConfigs.track.license'),
          getValue: (track) => (track as Track).license
        },
        tags
      ]
    }
  }
}
