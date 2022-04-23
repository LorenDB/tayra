<template>
  <div class="ui fluid user-request card">
    <div class="content">
      <h4 class="header">
        <router-link :to="{name: 'manage.moderation.requests.detail', params: {id: obj.uuid}}">
          <translate
            translate-context="Content/Moderation/Card/Short"
            :translate-params="{id: obj.uuid.substring(0, 8)}"
          >
            Request %{ id }
          </translate>
        </router-link>
        <collapse-link
          v-model="isCollapsed"
          class="right floated"
        />
      </h4>
      <div class="content">
        <div class="ui hidden divider" />
        <div class="ui stackable two column grid">
          <div class="column">
            <table class="ui very basic unstackable table">
              <tbody>
                <tr>
                  <td>
                    <translate translate-context="Content/Moderation/*">
                      Submitted by
                    </translate>
                  </td>
                  <td>
                    <actor-link
                      :admin="true"
                      :actor="obj.submitter"
                    />
                  </td>
                </tr>
                <tr>
                  <td>
                    <translate translate-context="Content/*/*/Noun">
                      Creation date
                    </translate>
                  </td>
                  <td>
                    <human-date
                      :date="obj.creation_date"
                      :icon="true"
                    />
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <div class="column">
            <table class="ui very basic unstackable table">
              <tbody>
                <tr>
                  <td>
                    <translate translate-context="*/*/*">
                      Status
                    </translate>
                  </td>
                  <td>
                    <template v-if="obj.status === 'pending'">
                      <i class="warning hourglass icon" />
                      <translate translate-context="Content/Library/*/Short">
                        Pending
                      </translate>
                    </template>
                    <template v-else-if="obj.status === 'refused'">
                      <i class="danger x icon" />
                      <translate translate-context="Content/*/*/Short">
                        Refused
                      </translate>
                    </template>
                    <template v-else-if="obj.status === 'approved'">
                      <i class="success check icon" />
                      <translate translate-context="Content/*/*/Short">
                        Approved
                      </translate>
                    </template>
                  </td>
                </tr>
                <tr>
                  <td>
                    <translate translate-context="Content/Moderation/*">
                      Assigned to
                    </translate>
                  </td>
                  <td>
                    <div v-if="obj.assigned_to">
                      <actor-link
                        :admin="true"
                        :actor="obj.assigned_to"
                      />
                    </div>
                    <translate
                      v-else
                      translate-context="*/*/*"
                    >
                      N/A
                    </translate>
                  </td>
                </tr>
                <tr>
                  <td>
                    <translate translate-context="Content/*/*/Noun">
                      Resolution date
                    </translate>
                  </td>
                  <td>
                    <human-date
                      v-if="obj.handled_date"
                      :date="obj.handled_date"
                      :icon="true"
                    />
                    <translate
                      v-else
                      translate-context="*/*/*"
                    >
                      N/A
                    </translate>
                  </td>
                </tr>
                <tr>
                  <td>
                    <translate translate-context="Content/*/*/Noun">
                      Internal notes
                    </translate>
                  </td>
                  <td>
                    <i class="comment icon" />
                    {{ obj.notes.length }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
    <div
      v-if="!isCollapsed"
      class="main content"
    >
      <div class="ui stackable two column grid">
        <div class="column">
          <h3>
            <translate translate-context="*/*/Field.Label/Noun">
              Message
            </translate>
          </h3>
          <p>
            <translate translate-context="Content/Moderation/Paragraph">
              This user wants to sign-up on your pod.
            </translate>
          </p>
          <template v-if="obj.metadata">
            <div class="ui hidden divider" />
            <div
              v-for="k in Object.keys(obj.metadata)"
              :key="k"
            >
              <h4>{{ k }}</h4>
              <p v-if="obj.metadata[k] && obj.metadata[k].length">
                {{ obj.metadata[k] }}
              </p>
              <translate
                v-else
                translate-context="*/*/*"
              >
                N/A
              </translate>
              <div class="ui hidden divider" />
            </div>
          </template>
        </div>
        <aside class="column">
          <div v-if="obj.status != 'approved'">
            <h3>
              <translate translate-context="Content/*/*/Noun">
                Actions
              </translate>
            </h3>
            <div class="ui labelled icon basic buttons">
              <button
                v-if="obj.status === 'pending' || obj.status === 'refused'"
                :class="['ui', {loading: isLoading}, 'button']"
                @click="approve(true)"
              >
                <i class="success check icon" />&nbsp;
                <translate translate-context="Content/*/Button.Label/Verb">
                  Approve
                </translate>
              </button>
              <button
                v-if="obj.status === 'pending'"
                :class="['ui', {loading: isLoading}, 'button']"
                @click="approve(false)"
              >
                <i class="danger x icon" />&nbsp;
                <translate translate-context="Content/*/Button.Label">
                  Refuse
                </translate>
              </button>
            </div>
          </div>
          <h3>
            <translate translate-context="Content/*/*/Noun">
              Internal notes
            </translate>
          </h3>
          <notes-thread
            :notes="obj.notes"
            @deleted="handleRemovedNote($event)"
          />
          <note-form
            :target="{type: 'request', uuid: obj.uuid}"
            @created="obj.notes.push($event)"
          />
        </aside>
      </div>
    </div>
  </div>
</template>

<script>
import axios from 'axios'
import NoteForm from '~/components/manage/moderation/NoteForm.vue'
import NotesThread from '~/components/manage/moderation/NotesThread.vue'
import showdown from 'showdown'

export default {
  components: {
    NoteForm,
    NotesThread
  },
  props: {
    initObj: { type: Object, required: true }
  },
  data () {
    return {
      markdown: new showdown.Converter(),
      isLoading: false,
      isCollapsed: false,
      obj: this.initObj
    }
  },
  methods: {
    approve (v) {
      const url = `manage/moderation/requests/${this.obj.uuid}/`
      const self = this
      const newStatus = v ? 'approved' : 'refused'
      this.isLoading = true
      axios.patch(url, { status: newStatus }).then((response) => {
        self.$emit('handled', newStatus)
        self.isLoading = false
        self.obj.status = newStatus
        if (v) {
          self.isCollapsed = true
        }
        self.$store.commit('ui/incrementNotifications', { count: -1, type: 'pendingReviewRequests' })
      }, () => {
        self.isLoading = false
      })
    },
    handleRemovedNote (uuid) {
      this.obj.notes = this.obj.notes.filter((note) => {
        return note.uuid !== uuid
      })
    }
  }
}
</script>
