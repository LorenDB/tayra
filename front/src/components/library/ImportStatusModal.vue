<template>
  <modal :show.sync="showModal">
    <h4 class="header">
      <translate translate-context="Popup/Import/Title">
        Import detail
      </translate>
    </h4>
    <div
      v-if="Object.keys(upload).length > 0"
      class="content"
    >
      <div class="description">
        <div
          v-if="upload.import_status === 'pending'"
          class="ui message"
        >
          <translate translate-context="Popup/Import/Message">
            Upload is still pending and will soon be processed by the server.
          </translate>
        </div>
        <div
          v-if="upload.import_status === 'finished'"
          class="ui success message"
        >
          <translate translate-context="Popup/Import/Message">
            Upload was successfully processed by the server.
          </translate>
        </div>
        <div
          v-if="upload.import_status === 'skipped'"
          role="alert"
          class="ui warning message"
        >
          <translate translate-context="Popup/Import/Message">
            Upload was skipped because a similar one is already available in one of your libraries.
          </translate>
        </div>
        <div
          v-if="upload.import_status === 'errored'"
          class="ui error message"
        >
          <translate translate-context="Popup/Import/Message">
            An error occurred during upload processing. You will find more information below.
          </translate>
        </div>
        <template v-if="upload.import_status === 'errored'">
          <table class="ui very basic collapsing celled table">
            <tbody>
              <tr>
                <td>
                  <translate translate-context="Popup/Import/Table.Label/Noun">
                    Error type
                  </translate>
                </td>
                <td>
                  {{ getErrorData(upload).label }}
                </td>
              </tr>
              <tr>
                <td>
                  <translate translate-context="Popup/Import/Table.Label/Noun">
                    Error detail
                  </translate>
                </td>
                <td>
                  {{ getErrorData(upload).detail }}
                  <ul v-if="getErrorData(upload).errorRows.length > 0">
                    <li
                      v-for="row in getErrorData(upload).errorRows"
                      :key="row.key"
                    >
                      {{ row.key }}: {{ row.value }}
                    </li>
                  </ul>
                </td>
              </tr>
              <tr>
                <td>
                  <translate translate-context="Footer/*/Link">
                    Getting help
                  </translate>
                </td>
                <td>
                  <ul>
                    <li>
                      <a
                        :href="getErrorData(upload).documentationUrl"
                        target="_blank"
                      >
                        <translate translate-context="Popup/Import/Table.Label/Value">Read our documentation for this error</translate>
                      </a>
                    </li>
                    <li>
                      <a
                        :href="getErrorData(upload).supportUrl"
                        target="_blank"
                      >
                        <translate translate-context="Popup/Import/Table.Label/Value">Open a support thread (include the debug information below in your message)</translate>
                      </a>
                    </li>
                  </ul>
                </td>
              </tr>
              <tr>
                <td>
                  <translate translate-context="Popup/Import/Table.Label/Noun">
                    Debug information
                  </translate>
                </td>
                <td>
                  <div class="ui form">
                    <textarea
                      class="ui textarea"
                      rows="10"
                      :value="getErrorData(upload).debugInfo"
                    />
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </template>
      </div>
    </div>
    <div class="actions">
      <button class="ui deny button">
        <translate translate-context="*/*/Button.Label/Verb">
          Close
        </translate>
      </button>
    </div>
  </modal>
</template>
<script>
import Modal from '~/components/semantic/Modal.vue'

function getErrors (payload) {
  const errors = []
  for (const k in payload) {
    if (Object.prototype.hasOwnProperty.call(payload, k)) {
      const value = payload[k]
      if (Array.isArray(value)) {
        errors.push({
          key: k,
          value: value.join(', ')
        })
      } else {
        // possibly artists, so nested errors
        if (typeof value === 'object') {
          getErrors(value).forEach((e) => {
            errors.push({
              key: `${k} / ${e.key}`,
              value: e.value
            })
          })
        }
      }
    }
  }
  return errors
}

export default {
  components: {
    Modal
  },
  props: {
    upload: { type: Object, required: true },
    show: { type: Boolean }
  },
  data () {
    return {
      showModal: this.show
    }
  },
  watch: {
    showModal (v) {
      this.$emit('update:show', v)
    },
    show (v) {
      this.showModal = v
    }
  },
  methods: {
    getErrorData (upload) {
      const payload = upload.import_details || {}
      const d = {
        supportUrl: 'https://forum.funkwhale.audio/t/support',
        errorRows: []
      }
      if (!payload.error_code) {
        d.errorCode = 'unknown_error'
      } else {
        d.errorCode = payload.error_code
      }
      d.documentationUrl = `https://docs.funkwhale.audio/users/upload.html#${d.errorCode}`
      if (d.errorCode === 'invalid_metadata') {
        d.label = this.$pgettext('Popup/Import/Error.Label', 'Invalid metadata')
        d.detail = this.$pgettext('Popup/Import/Error.Label', 'The metadata included in the file is invalid or some mandatory fields are missing.')
        const detail = payload.detail || {}
        d.errorRows = getErrors(detail)
      } else {
        d.label = this.$pgettext('*/*/Error', 'Unknown error')
        d.detail = this.$pgettext('Popup/Import/Error.Label', 'An unknown error occurred')
      }
      const debugInfo = {
        source: upload.source,
        ...payload
      }
      d.debugInfo = JSON.stringify(debugInfo, null, 4)
      return d
    }
  }
}
</script>
