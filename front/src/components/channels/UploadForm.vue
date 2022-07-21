<template>
  <form
    :class="['ui', {loading: isLoadingStep1}, 'form component-file-upload']"
    @submit.stop.prevent
  >
    <div
      v-if="errors.length > 0"
      role="alert"
      class="ui negative message"
    >
      <h4 class="header">
        <translate translate-context="Content/*/Error message.Title">
          Error while publishing
        </translate>
      </h4>
      <ul class="list">
        <li
          v-for="(error, key) in errors"
          :key="key"
        >
          {{ error }}
        </li>
      </ul>
    </div>
    <div :class="['ui', 'required', {hidden: step > 1}, 'field']">
      <label for="channel-dropdown">
        <translate translate-context="*/*/*">Channel</translate>
      </label>
      <div
        id="channel-dropdown"
        class="ui search normal selection dropdown"
      >
        <div class="text" />
        <i class="dropdown icon" />
      </div>
    </div>
    <album-select
      v-model.number="values.album"
      :channel="selectedChannel"
      :class="['ui', {hidden: step > 1}, 'field']"
    />
    <license-select
      v-model="values.license"
      :class="['ui', {hidden: step > 1}, 'field']"
    />
    <div :class="['ui', {hidden: step > 1}, 'message']">
      <div class="content">
        <p>
          <i class="copyright icon" />
          <translate translate-context="Content/Channels/Popup.Paragraph">
            Add a license to your upload to ensure some freedoms to your public.
          </translate>
        </p>
      </div>
    </div>
    <template v-if="step >= 2 && step < 4">
      <div
        v-if="remainingSpace === 0"
        role="alert"
        class="ui warning message"
      >
        <div class="content">
          <p>
            <i class="warning icon" />
            <translate translate-context="Content/Library/Paragraph">
              You don't have any space left to upload your files. Please contact the moderators.
            </translate>
          </p>
        </div>
      </div>
      <template v-else>
        <div
          v-if="step === 2 && draftUploads && draftUploads.length > 0 && includeDraftUploads === null"
          class="ui visible info message"
        >
          <p>
            <i class="redo icon" />
            <translate translate-context="Popup/Channels/Paragraph">
              You have some draft uploads pending publication.
            </translate>
          </p>
          <button
            class="ui basic button"
            @click.stop.prevent="includeDraftUploads = false"
          >
            <translate translate-context="*/*/*">
              Ignore
            </translate>
          </button>
          <button
            class="ui basic button"
            @click.stop.prevent="includeDraftUploads = true"
          >
            <translate translate-context="*/*/*">
              Resume
            </translate>
          </button>
        </div>
        <div
          v-if="uploadedFiles.length > 0"
          :class="[{hidden: step === 3}]"
        >
          <div
            v-for="file in uploadedFiles"
            :key="file.id"
            class="channel-file"
          >
            <div class="content">
              <div
                v-if="file.response.uuid"
                role="button"
                class="ui basic icon button"
                :title="labels.editTitle"
                @click.stop.prevent="selectedUploadId = file.response.uuid"
              >
                <i class="pencil icon" />
              </div>
              <div
                v-if="file.error"
                class="ui basic danger icon label"
                :title="file.error"
                @click.stop.prevent="selectedUploadId = file.response.uuid"
              >
                <i class="warning sign icon" />
              </div>
              <div
                v-else-if="file.active"
                class="ui active slow inline loader"
              />
            </div>
            <h4 class="ui header">
              <template v-if="file.metadata.title">
                {{ file.metadata.title }}
              </template>
              <template v-else>
                {{ file.name }}
              </template>
              <div class="sub header">
                <template v-if="file.response.uuid">
                  {{ humanSize(file.size) }}
                  <template v-if="file.response.duration">
                    · <human-duration :duration="file.response.duration" />
                  </template>
                </template>
                <template v-else>
                  <translate
                    v-if="file.active"
                    translate-context="Channels/*/*"
                  >
                    Uploading
                  </translate>
                  <translate
                    v-else-if="file.error"
                    translate-context="Channels/*/*"
                  >
                    Errored
                  </translate>
                  <translate
                    v-else
                    translate-context="Channels/*/*"
                  >
                    Pending
                  </translate>
                  · {{ humanSize(file.size) }}
                  · {{ parseInt(file.progress) }}%
                </template>
                · <a @click.stop.prevent="remove(file)">
                  <translate translate-context="Content/Radio/Button.Label/Verb">Remove</translate>
                </a>
                <template v-if="file.error">
                  ·
                  <a @click.stop.prevent="retry(file)">
                    <translate translate-context="*/*/*">Retry</translate>
                  </a>
                </template>
              </div>
            </h4>
          </div>
        </div>
        <upload-metadata-form
          v-if="selectedUpload"
          :upload="selectedUpload"
          :values="uploadImportData[selectedUploadId]"
          @values="setDynamic('uploadImportData', selectedUploadId, $event)"
        />
        <div
          v-if="step === 2"
          class="ui message"
        >
          <div class="content">
            <p>
              <i class="info icon" />
              <translate
                translate-context="Content/Library/Paragraph"
                :translate-params="{extensions: $store.state.ui.supportedExtensions.join(', ')}"
              >
                Supported extensions: %{ extensions }
              </translate>
            </p>
          </div>
        </div>
        <file-upload-widget
          ref="upload"
          v-model="filesModel"
          :class="['ui', 'icon', 'basic', 'button', 'channels', {hidden: step === 3}]"
          :post-action="uploadUrl"
          :multiple="true"
          :data="baseImportMetadata"
          :drop="true"
          :extensions="$store.state.ui.supportedExtensions"
          name="audio_file"
          :thread="1"
          @input-file="inputFile"
        >
          <div>
            <i class="upload icon" />&nbsp;
            <translate translate-context="Content/Channels/Paragraph">
              Drag and drop your files here or open the browser to upload your files
            </translate>
          </div>
          <div class="ui very small divider" />
          <div>
            <translate translate-context="*/*/*">
              Browse…
            </translate>
          </div>
        </file-upload-widget>
        <div class="ui hidden divider" />
      </template>
    </template>
  </form>
</template>
<script>
import axios from 'axios'
import $ from 'jquery'

import LicenseSelect from '~/components/channels/LicenseSelect.vue'
import AlbumSelect from '~/components/channels/AlbumSelect.vue'
import FileUploadWidget from '~/components/library/FileUploadWidget.vue'
import UploadMetadataForm from '~/components/channels/UploadMetadataForm.vue'
import { humanSize } from '~/utils/filters'

function setIfEmpty (obj, k, v) {
  if (obj[k] !== undefined) {
    return
  }
  obj[k] = v
}

export default {
  components: {
    AlbumSelect,
    LicenseSelect,
    FileUploadWidget,
    UploadMetadataForm
  },
  props: {
    channel: { type: Object, default: null, required: false }
  },
  setup () {
    return { humanSize }
  },
  data () {
    return {
      availableChannels: {
        results: [],
        count: 0
      },
      audioMetadata: {},
      uploadData: {},
      uploadImportData: {},
      draftUploads: null,
      files: [],
      errors: [],
      removed: [],
      includeDraftUploads: null,
      uploadUrl: this.$store.getters['instance/absoluteUrl']('/api/v1/uploads/'),
      quotaStatus: null,
      isLoadingStep1: true,
      step: 1,
      values: {
        channel: (this.channel || {}).uuid,
        license: null,
        album: null
      },
      selectedUploadId: null
    }
  },
  computed: {
    filesModel: {
      get () {
        return this.files
      },

      set (value) {
        this.updateFiles(value)
      }
    },
    labels () {
      return {
        editTitle: this.$pgettext('Content/*/Button.Label/Verb', 'Edit')

      }
    },
    baseImportMetadata () {
      return {
        channel: this.values.channel,
        import_status: 'draft',
        import_metadata: { license: this.values.license, album: this.values.album || null }
      }
    },
    remainingSpace () {
      if (!this.quotaStatus) {
        return 0
      }
      return Math.max(0, this.quotaStatus.remaining - (this.uploadedSize / (1000 * 1000)))
    },
    selectedChannel () {
      const self = this
      return this.availableChannels.results.filter((c) => {
        return c.uuid === self.values.channel
      })[0] ?? null
    },
    selectedUpload () {
      const self = this
      if (!this.selectedUploadId) {
        return null
      }
      const selected = this.uploadedFiles.filter((f) => {
        return f.response && f.response.uuid === self.selectedUploadId
      })[0]
      return {
        ...selected.response,
        _fileObj: selected._fileObj
      }
    },
    uploadedFilesById () {
      const data = {}
      this.uploadedFiles.forEach((u) => {
        data[u.response.uuid] = u
      })
      return data
    },
    uploadedFiles () {
      const self = this
      const files = this.files.map((f) => {
        const data = {
          ...f,
          _fileObj: f,
          metadata: {}
        }
        if (f.response && f.response.uuid) {
          const uploadImportMetadata = self.uploadImportData[f.response.uuid] || self.uploadData[f.response.uuid].import_metadata
          data.metadata = {
            ...uploadImportMetadata
          }
          data.removed = self.removed.indexOf(f.response.uuid) >= 0
        }
        return data
      })
      let final = []
      if (this.includeDraftUploads) {
        // we have two different objects: draft uploads (so already uploaded in a previous)
        // session, and files uploaded in the current session
        // so we ensure we have a similar structure for both.

        final = [
          ...this.draftUploads.map((u) => {
            return {
              response: u,
              _fileObj: null,
              size: u.size,
              progress: 100,
              name: u.source.replace('upload://', ''),
              active: false,
              removed: self.removed.indexOf(u.uuid) >= 0,
              metadata: self.uploadImportData[u.uuid] || self.audioMetadata[u.uuid] || u.import_metadata
            }
          }),
          ...files
        ]
      } else {
        final = files
      }
      return final.filter((f) => {
        return !f.removed
      })
    },
    summaryData () {
      let speed = null
      let remaining = null
      if (this.activeFile) {
        speed = this.activeFile.speed
        remaining = parseInt(this.totalSize / speed)
      }
      return {
        totalFiles: this.uploadedFiles.length,
        totalSize: this.totalSize,
        uploadedSize: this.uploadedSize,
        progress: parseInt(this.uploadedSize * 100 / this.totalSize),
        canSubmit: !this.activeFile && this.uploadedFiles.length > 0,
        speed,
        remaining,
        quotaStatus: this.quotaStatus
      }
    },
    totalSize () {
      let total = 0
      this.uploadedFiles.forEach((f) => {
        if (!f.error) {
          total += f.size
        }
      })
      return total
    },
    uploadedSize () {
      let uploaded = 0
      this.uploadedFiles.forEach((f) => {
        if (f._fileObj && !f.error) {
          uploaded += f.size * (f.progress / 100)
        }
      })
      return uploaded
    },
    activeFile () {
      return this.files.find((file) => file.active)
    }
  },
  watch: {
    'availableChannels.results' () {
      this.setupChannelsDropdown()
    },
    'values.channel': {
      async handler (v) {
        this.files = []
        if (v) {
          await this.fetchDraftUploads(v)
        }
      },
      immediate: true
    },
    step: {
      handler (value) {
        this.$emit('step', value)
        if (value === 2) {
          this.selectedUploadId = null
        }
      },
      immediate: true
    },
    async selectedUploadId (v, o) {
      if (v) {
        this.step = 3
      } else {
        this.step = 2
      }
      if (o) {
        await this.patchUpload(o, { import_metadata: this.uploadImportData[o] })
      }
    },
    summaryData: {
      handler (v) {
        this.$emit('status', v)
      },
      immediate: true

    }
  },
  async created () {
    this.isLoadingStep1 = true
    const p1 = this.fetchChannels()
    await p1
    this.isLoadingStep1 = false
    this.fetchQuota()
  },
  methods: {
    async fetchChannels () {
      const response = await axios.get('channels/', { params: { scope: 'me' } })
      this.availableChannels = response.data
    },
    async patchUpload (id, data) {
      const response = await axios.patch(`uploads/${id}/`, data)
      this.uploadData[id] = response.data
      this.uploadImportData[id] = response.data.import_metadata
    },
    fetchQuota () {
      const self = this
      axios.get('users/me/').then((response) => {
        self.quotaStatus = response.data.quota_status
      })
    },
    publish () {
      const self = this
      self.isLoading = true
      self.errors = []
      const ids = this.uploadedFiles.map((f) => {
        return f.response.uuid
      })
      const payload = {
        action: 'publish',
        objects: ids
      }
      return axios.post('uploads/action/', payload).then(
        response => {
          self.isLoading = false
          self.$emit('published', {
            uploads: self.uploadedFiles.map((u) => {
              return {
                ...u.response,
                import_status: 'pending'
              }
            }),
            channel: self.selectedChannel
          })
        },
        error => {
          self.errors = error.backendErrors
        }
      )
    },
    setupChannelsDropdown () {
      const self = this
      $(this.$el).find('#channel-dropdown').dropdown({
        onChange (value, text, $choice) {
          self.values.channel = value
        },
        values: this.availableChannels.results.map((c) => {
          const d = {
            name: c.artist.name,
            value: c.uuid,
            selected: self.channel && self.channel.uuid === c.uuid
          }
          if (c.artist.cover && c.artist.cover.urls.medium_square_crop) {
            const coverUrl = self.$store.getters['instance/absoluteUrl'](c.artist.cover.urls.medium_square_crop)
            d.image = coverUrl
            if (c.artist.content_category === 'podcast') {
              d.imageClass = 'ui image'
            } else {
              d.imageClass = 'ui avatar image'
            }
          } else {
            d.icon = 'user'
            if (c.artist.content_category === 'podcast') {
              d.iconClass = 'bordered icon'
            } else {
              d.iconClass = 'circular icon'
            }
          }
          return d
        })
      })
      $(this.$el).find('#channel-dropdown').dropdown('hide')
    },
    inputFile (newFile, oldFile) {
      if (!newFile) {
        return
      }
      if (this.remainingSpace < newFile.size / (1000 * 1000)) {
        newFile.error = 'denied'
      } else {
        this.$refs.upload.active = true
      }
    },
    fetchAudioMetadata (uuid) {
      const self = this
      self.audioMetadata[uuid] = null
      axios.get(`uploads/${uuid}/audio-file-metadata/`).then((response) => {
        self.setDynamic('audioMetadata', uuid, response.data)
        const uploadedFile = self.uploadedFilesById[uuid]
        if (uploadedFile._fileObj && uploadedFile.response.import_metadata.title === uploadedFile._fileObj.name.replace(/\.[^/.]+$/, '') && response.data.title) {
          // replace existing title deduced from file by the one in audio file metadat, if any
          self.uploadImportData[uuid].title = response.data.title
        } else {
          setIfEmpty(self.uploadImportData[uuid], 'title', response.data.title)
        }
        setIfEmpty(self.uploadImportData[uuid], 'title', response.data.title)
        setIfEmpty(self.uploadImportData[uuid], 'position', response.data.position)
        setIfEmpty(self.uploadImportData[uuid], 'tags', response.data.tags)
        setIfEmpty(self.uploadImportData[uuid], 'description', (response.data.description || {}).text)
        self.patchUpload(uuid, { import_metadata: self.uploadImportData[uuid] })
      })
    },
    setDynamic (objName, key, data) {
      // cf https://vuejs.org/v2/guide/reactivity.html#Change-Detection-Caveats
      const newData = {}
      newData[key] = data
      this[objName] = Object.assign({}, this[objName], newData)
    },
    updateFiles (value) {
      this.files = value
      this.files.forEach((f) => {
        if (f.response?.uuid && this.audioMetadata[f.response.uuid] === undefined) {
          this.uploadData[f.response.uuid] = f.response
          this.setDynamic('uploadImportData', f.response.uuid, {
            ...f.response.import_metadata
          })
          this.fetchAudioMetadata(f.response.uuid)
        }
      })
    },
    async fetchDraftUploads (channel) {
      const self = this
      this.draftUploads = null
      const response = await axios.get('uploads', { params: { import_status: 'draft', channel } })
      this.draftUploads = response.data.results
      this.draftUploads.forEach((u) => {
        self.uploadImportData[u.uuid] = u.import_metadata
      })
    },
    remove (file) {
      if (file.response && file.response.uuid) {
        axios.delete(`uploads/${file.response.uuid}/`)
        this.removed.push(file.response.uuid)
      } else {
        this.$refs.upload.remove(file)
      }
    },
    retry (file) {
      this.$refs.upload.update(file, { error: '', progress: '0.00' })
      this.$refs.upload.active = true
    }
  }
}
</script>
