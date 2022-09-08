import type { Album, Artist, Content, Track, Actor } from '~/types'

import { useI18n } from 'vue-i18n'

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

const { t } = useI18n()
const getContentValueRepr = (val: Content) => val.text

const description: ConfigField = {
  id: 'description',
  type: 'content',
  required: true,
  label: t('Description'),
  getValue: (obj) => obj.description ?? { text: '', content_type: 'text/markdown' },
  getValueRepr: getContentValueRepr
}

const cover: ConfigField = {
  id: 'cover',
  type: 'attachment',
  required: false,
  label: t('Cover'),
  getValue: (obj) => obj.cover?.uuid ?? null
}

const tags: ConfigField = {
  id: 'tags',
  type: 'tags',
  required: true,
  label: t('Tags'),
  getValue: (obj) => { return obj.tags },
  getValueRepr: (tags: string[]) => tags.slice().sort().join('\n')
}

// TODO: Get params from typescript type somehow?
export default (): Configs => ({
  artist: {
    fields: [
      {
        id: 'name',
        type: 'text',
        required: true,
        label: t('Name'),
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
        label: t('Title'),
        getValue: (album) => (album as Album).title
      },
      description,
      {
        id: 'release_date',
        type: 'text',
        required: false,
        label: t('Release date'),
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
        label: t('Title'),
        getValue: (track) => (track as Track).title
      },
      description,
      cover,
      {
        id: 'position',
        type: 'text',
        inputType: 'number',
        required: false,
        label: t('Position'),
        getValue: (track) => (track as Track).position
      },
      {
        id: 'copyright',
        type: 'text',
        required: false,
        label: t('Copyright'),
        getValue: (track) => (track as Track).copyright
      },
      {
        id: 'license',
        type: 'license',
        required: false,
        label: t('License'),
        getValue: (track) => (track as Track).license
      },
      tags
    ]
  }
})
