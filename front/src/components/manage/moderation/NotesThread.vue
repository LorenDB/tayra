<template>
  <div class="ui feed">
    <div
      v-for="note in notes"
      :key="note.uuid"
      class="event"
    >
      <div class="label">
        <i class="comment outline icon" />
      </div>
      <div class="content">
        <div class="summary">
          <actor-link
            :admin="true"
            :actor="note.author"
          />
          <div class="date">
            <human-date :date="note.creation_date" />
          </div>
        </div>
        <div class="extra text">
          <expandable-div :content="note.summary">
            <div v-html="markdown.makeHtml(note.summary)" />
          </expandable-div>
        </div>
        <div class="meta">
          <dangerous-button
            :class="['ui', {loading: isLoading}, 'basic borderless mini button']"
            @confirm="remove(note)"
          >
            <i class="trash icon" />
            <translate translate-context="*/*/*/Verb">
              Delete
            </translate>
            <p slot="modal-header">
              <translate translate-context="Popup/Moderation/Title">
                Delete this note?
              </translate>
            </p>
            <div slot="modal-content">
              <p>
                <translate translate-context="Content/Moderation/Paragraph">
                  The note will be removed. This action is irreversible.
                </translate>
              </p>
            </div>
            <p slot="modal-confirm">
              <translate translate-context="*/*/*/Verb">
                Delete
              </translate>
            </p>
          </dangerous-button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import axios from 'axios'
import showdown from 'showdown'

export default {
  props: {
    notes: { type: Array, required: true }
  },
  data () {
    return {
      markdown: new showdown.Converter(),
      isLoading: false
    }
  },
  methods: {
    remove (obj) {
      const self = this
      this.isLoading = true
      axios.delete(`manage/moderation/notes/${obj.uuid}/`).then((response) => {
        self.$emit('deleted', obj.uuid)
        self.isLoading = false
      }, () => {
        self.isLoading = false
      })
    }
  }
}
</script>
