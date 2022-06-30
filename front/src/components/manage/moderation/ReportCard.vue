<template>
  <div class="ui fluid report card">
    <div class="content">
      <h4 class="header">
        <router-link :to="{name: 'manage.moderation.reports.detail', params: {id: obj.uuid}}">
          <translate
            translate-context="Content/Moderation/Card/Short"
            :translate-params="{id: obj.uuid.substring(0, 8)}"
          >
            Report %{ id }
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
                    <div v-if="obj.submitter">
                      <actor-link
                        :admin="true"
                        :actor="obj.submitter"
                      />
                    </div>
                    <div v-else-if="obj.submitter_email">
                      {{ obj.submitter_email }}
                    </div>
                  </td>
                </tr>
                <tr>
                  <td>
                    <translate translate-context="*/*/*">
                      Category
                    </translate>
                  </td>
                  <td>
                    <report-category-dropdown
                      v-model="obj.type"
                      @update:model-value="update({ type: $event })"
                    >
                      &#32;
                      <action-feedback :is-loading="updating.type" />
                    </report-category-dropdown>
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
                  <td v-if="obj.is_handled">
                    <span v-if="obj.is_handled">
                      <i class="success check icon" />
                      <translate translate-context="Content/*/*/Short">Resolved</translate>
                    </span>
                  </td>
                  <td v-else>
                    <i class="danger x icon" />
                    <translate translate-context="Content/*/*/Short">
                      Unresolved
                    </translate>
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
          <expandable-div
            v-if="obj.summary"
            class="summary"
            :content="obj.summary"
          >
            <div v-html="markdown.makeHtml(obj.summary)" />
          </expandable-div>
        </div>
        <aside class="column">
          <h3>
            <translate translate-context="Content/*/*/Short">
              Reported object
            </translate>
          </h3>
          <div
            v-if="!obj.target"
            role="alert"
            class="ui warning message"
          >
            <translate translate-context="Content/Moderation/Message">
              The object associated with this report was deleted.
            </translate>
          </div>
          <router-link
            v-if="target && configs[target.type].urls.getDetail"
            class="ui basic button"
            :to="configs[target.type].urls.getDetail(obj.target_state)"
          >
            <i class="eye icon" />
            <translate translate-context="Content/Moderation/Link">
              View public page
            </translate>
          </router-link>
          <router-link
            v-if="target && configs[target.type].urls.getAdminDetail"
            class="ui basic button"
            :to="configs[target.type].urls.getAdminDetail(obj.target_state)"
          >
            <i class="wrench icon" />
            <translate translate-context="Content/Moderation/Link">
              Open in moderation interface
            </translate>
          </router-link>
          <table class="ui very basic unstackable table">
            <tbody>
              <tr v-if="target">
                <td>
                  <translate translate-context="Content/Track/Table.Label/Noun">
                    Type
                  </translate>
                </td>
                <td colspan="2">
                  <i :class="[configs[target.type].icon, 'icon']" />
                  {{ configs[target.type].label }}
                </td>
              </tr>
              <tr v-if="obj.target_owner && (!target || target.type !== 'account')">
                <td>
                  <translate translate-context="*/*/*">
                    Owner
                  </translate>
                </td>
                <td>
                  <actor-link
                    :admin="true"
                    :actor="obj.target_owner"
                  />
                </td>
                <td>
                  <instance-policy-modal
                    v-if="!obj.target_owner.is_local"
                    class="right floated mini basic"
                    type="actor"
                    :target="obj.target_owner.full_username"
                  />
                </td>
              </tr>
              <tr v-if="target && target.type === 'account'">
                <td>
                  <translate translate-context="*/*/*/Noun">
                    Account
                  </translate>
                </td>
                <td>
                  <actor-link
                    :admin="true"
                    :actor="obj.target_owner"
                  />
                </td>
                <td>
                  <instance-policy-modal
                    v-if="!obj.target_owner.is_local"
                    class="right floated mini basic"
                    type="actor"
                    :target="obj.target_owner.full_username"
                  />
                </td>
              </tr>
              <tr v-if="obj.target_state.is_local">
                <td>
                  <translate translate-context="Content/Moderation/*/Noun">
                    Domain
                  </translate>
                </td>
                <td colspan="2">
                  <i class="home icon" />
                  <translate translate-context="Content/Moderation/*/Short, Noun">
                    Local
                  </translate>
                </td>
              </tr>
              <tr v-else-if="obj.target_state.domain">
                <td>
                  <router-link :to="{name: 'manage.moderation.domains.detail', params: {id: obj.target_state.domain }}">
                    <translate translate-context="Content/Moderation/*/Noun">
                      Domain
                    </translate>
                  </router-link>
                </td>
                <td>
                  {{ obj.target_state.domain }}
                </td>
                <td>
                  <instance-policy-modal
                    class="right floated mini basic"
                    type="domain"
                    :target="obj.target_state.domain"
                  />
                </td>
              </tr>
              <tr
                v-for="field in targetFields"
                :key="field.id"
              >
                <td>{{ field.label }}</td>
                <td
                  v-if="field.repr"
                  colspan="2"
                >
                  {{ field.repr }}
                </td>
                <td
                  v-else
                  colspan="2"
                >
                  <translate translate-context="*/*/*">
                    N/A
                  </translate>
                </td>
              </tr>
            </tbody>
          </table>
        </aside>
      </div>
      <div class="ui stackable two column grid">
        <div class="column">
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
            :target="{type: 'report', uuid: obj.uuid}"
            @created="obj.notes.push($event)"
          />
        </div>
        <div class="column">
          <h3>
            <translate translate-context="Content/*/*/Noun">
              Actions
            </translate>
          </h3>
          <div class="ui labelled icon basic buttons">
            <button
              v-if="obj.is_handled === false"
              :class="['ui', {loading: isLoading}, 'button']"
              @click="resolve(true)"
            >
              <i class="success check icon" />&nbsp;
              <translate translate-context="Content/*/Button.Label/Verb">
                Resolve
              </translate>
            </button>
            <button
              v-if="obj.is_handled === true"
              :class="['ui', {loading: isLoading}, 'button']"
              @click="resolve(false)"
            >
              <i class="warning redo icon" />&nbsp;
              <translate translate-context="Content/*/Button.Label">
                Unresolve
              </translate>
            </button>
            <template
              v-for="action in actions"
              :key="action.label"
            >
              <dangerous-button
                v-if="action.dangerous && action.show(obj)"
                :class="['ui', {loading: isLoading}, 'button']"
                :action="action.handler"
              >
                <i :class="[action.iconColor, action.icon, 'icon']" />&nbsp;
                {{ action.label }}
                <template #modal-header>
                  <p>{{ action.modalHeader }}</p>
                </template>
                <template #modal-content>
                  <div>
                    <p>{{ action.modalContent }}</p>
                  </div>
                </template>
                <template #modal-confirm>
                  <p>{{ action.modalConfirmLabel }}</p>
                </template>
              </dangerous-button>
            </template>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import axios from 'axios'
import NoteForm from '~/components/manage/moderation/NoteForm.vue'
import NotesThread from '~/components/manage/moderation/NotesThread.vue'
import ReportCategoryDropdown from '~/components/moderation/ReportCategoryDropdown.vue'
import InstancePolicyModal from '~/components/manage/moderation/InstancePolicyModal.vue'
import useReportConfigs from '~/composables/moderation/useReportConfigs.ts'
import { setUpdate } from '~/utils'
import showdown from 'showdown'

function castValue (value) {
  if (value === null || value === undefined) {
    return ''
  }
  return String(value)
}

export default {
  components: {
    NoteForm,
    NotesThread,
    ReportCategoryDropdown,
    InstancePolicyModal
  },
  props: {
    initObj: { type: Object, required: true },
    currentState: { type: String, required: false, default: '' }
  },
  setup () {
    return { configs: useReportConfigs() }
  },
  data () {
    return {
      obj: this.initObj,
      markdown: new showdown.Converter(),
      isLoading: false,
      isCollapsed: false,
      updating: {
        type: false
      }
    }
  },
  computed: {
    previousState () {
      if (this.obj.is_applied) {
        // mutation was applied, we use the previous state that is stored
        // on the mutation itself
        return this.obj.previous_state
      }
      // mutation is not applied yet, so we use the current state that was
      // passed to the component, if any
      return this.currentState
    },
    detailUrl () {
      if (!this.target) {
        return ''
      }
      let namespace
      const id = this.target.id
      if (this.target.type === 'track') {
        namespace = 'library.tracks.edit.detail'
      }
      if (this.target.type === 'album') {
        namespace = 'library.albums.edit.detail'
      }
      if (this.target.type === 'artist') {
        namespace = 'library.artists.edit.detail'
      }
      return this.$router.resolve({ name: namespace, params: { id, editId: this.obj.uuid } }).href
    },

    targetFields () {
      if (!this.target) {
        return []
      }
      const payload = this.obj.target_state
      const fields = this.configs[this.target.type].moderatedFields
      return fields.map((fieldConfig) => {
        const getValueRepr = fieldConfig.getValueRepr ?? (i => i)
        return {
          id: fieldConfig.id,
          label: fieldConfig.label,
          value: payload[fieldConfig.id],
          repr: castValue(getValueRepr(payload[fieldConfig.id]))
        }
      })
    },
    target () {
      if (this.obj.target) {
        return this.obj.target
      } else {
        return this.obj.target_state._target
      }
    },
    actions () {
      if (!this.target) {
        return []
      }
      const self = this
      const actions = []
      const typeConfig = this.configs[this.target.type]
      if (typeConfig.getDeleteUrl) {
        const deleteUrl = typeConfig.getDeleteUrl(this.target)
        actions.push({
          label: this.$pgettext('Content/Moderation/Button/Verb', 'Delete reported object'),
          modalHeader: this.$pgettext('Content/Moderation/Popup/Header', 'Delete reported object?'),
          modalContent: this.$pgettext('Content/Moderation/Popup,Paragraph', 'This will delete the object associated with this report and mark the report as resolved. The deletion is irreversible.'),
          modalConfirmLabel: this.$pgettext('*/*/*/Verb', 'Delete'),
          icon: 'x',
          iconColor: 'danger',
          show: (obj) => { return !!obj.target },
          dangerous: true,
          handler: () => {
            axios.delete(deleteUrl).then((response) => {
              console.log('Target deleted')
              self.obj.target = null
              self.resolve(true)
            }, () => {
              console.log('Error while deleting target')
            })
          }
        })
      }
      return actions
    }
  },
  methods: {
    update (payload) {
      const url = `manage/moderation/reports/${this.obj.uuid}/`
      const self = this
      this.isLoading = true
      setUpdate(payload, this.updating, true)
      axios.patch(url, payload).then((response) => {
        self.$emit('updated', payload)
        Object.assign(self.obj, payload)
        self.isLoading = false
        setUpdate(payload, self.updating, false)
      }, () => {
        self.isLoading = false
        setUpdate(payload, self.updating, false)
      })
    },
    resolve (v) {
      const url = `manage/moderation/reports/${this.obj.uuid}/`
      const self = this
      this.isLoading = true
      axios.patch(url, { is_handled: v }).then((response) => {
        self.$emit('handled', v)
        self.isLoading = false
        self.obj.is_handled = v
        let increment
        if (v) {
          self.isCollapsed = true
          increment = -1
        } else {
          increment = 1
        }
        self.$store.commit('ui/incrementNotifications', { count: increment, type: 'pendingReviewReports' })
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
