<template>
  <div class="table-wrapper component-action-table">
    <table class="ui compact very basic unstackable table">
      <thead>
        <tr>
          <th colspan="1000">
            <div
              v-if="refreshable"
              class="right floated"
            >
              <span v-if="needsRefresh">
                <translate translate-context="Content/*/Button.Help text.Paragraph">Content has been updated, click refresh to see up-to-date content</translate>
              </span>
              <button
                class="ui basic icon button"
                :title="labels.refresh"
                :aria-label="labels.refresh"
                @click="$emit('refresh')"
              >
                <i class="refresh icon" />
              </button>
            </div>

            <div
              v-if="actionUrl && actions.length > 0"
              class="ui small left floated form"
            >
              <div class="ui inline fields">
                <div class="field">
                  <label for="actions-select"><translate translate-context="Content/*/*/Noun">Actions</translate></label>
                  <select
                    id="actions-select"
                    v-model="currentActionName"
                    class="ui dropdown"
                  >
                    <option
                      v-for="(action, key) in actions"
                      :key="key"
                      :value="action.name"
                    >
                      {{ action.label }}
                    </option>
                  </select>
                </div>
                <div class="field">
                  <dangerous-button
                    v-if="selectAll || currentAction.isDangerous"
                    :class="['ui', {disabled: checked.length === 0}, {'loading': actionLoading}, 'button']"
                    :confirm-color="currentAction.confirmColor || 'success'"
                    :aria-label="labels.performAction"
                    @confirm="launchAction"
                  >
                    <translate translate-context="Content/*/Button.Label/Short, Verb">
                      Go
                    </translate>
                    <template #modal-header>
                      <p>
                        <translate
                          key="1"
                          translate-context="Modal/*/Title"
                          :translate-n="affectedObjectsCount"
                          :translate-params="{count: affectedObjectsCount, action: currentActionName}"
                          translate-plural="Do you want to launch %{ action } on %{ count } elements?"
                        >
                          Do you want to launch %{ action } on %{ count } element?
                        </translate>
                      </p>
                    </template>
                    <template #modal-content>
                      <p>
                        <template v-if="currentAction.confirmationMessage">
                          {{ currentAction.confirmationMessage }}
                        </template>
                        <translate
                          v-else
                          translate-context="Modal/*/Paragraph"
                        >
                          This may affect a lot of elements or have irreversible consequences, please double check this is really what you want.
                        </translate>
                      </p>
                    </template>
                    <template #modal-confirm>
                      <div :aria-label="labels.performAction">
                        <translate translate-context="Modal/*/Button.Label/Short, Verb">
                          Launch
                        </translate>
                      </div>
                    </template>
                  </dangerous-button>
                  <button
                    v-else
                    :disabled="checked.length === 0 || null"
                    :aria-label="labels.performAction"
                    :class="['ui', {disabled: checked.length === 0}, {'loading': actionLoading}, 'button']"
                    @click="launchAction"
                  >
                    <translate translate-context="Content/*/Button.Label/Short, Verb">
                      Go
                    </translate>
                  </button>
                </div>
                <div class="count field">
                  <translate
                    v-if="selectAll"
                    key="1"
                    translate-context="Content/*/Paragraph"
                    tag="span"
                    :translate-n="objectsData.count"
                    :translate-params="{count: objectsData.count, total: objectsData.count}"
                    translate-plural="All %{ count } elements selected"
                  >
                    All %{ count } element selected
                  </translate>
                  <translate
                    v-else
                    key="2"
                    translate-context="Content/*/Paragraph"
                    tag="span"
                    :translate-n="checked.length"
                    :translate-params="{count: checked.length, total: objectsData.count}"
                    translate-plural="%{ count } on %{ total } selected"
                  >
                    %{ count } on %{ total } selected
                  </translate>
                  <template v-if="currentAction.allowAll && checkable.length > 0 && checkable.length === checked.length">
                    <a
                      v-if="!selectAll"
                      href=""
                      @click.prevent="selectAll = true"
                    >
                      <translate
                        key="3"
                        translate-context="Content/*/Link/Verb"
                        :translate-n="objectsData.count"
                        :translate-params="{total: objectsData.count}"
                        translate-plural="Select all %{ total } elements"
                      >
                        Select one element
                      </translate>
                    </a>
                    <a
                      v-else
                      href=""
                      @click.prevent="selectAll = false"
                    >
                      <translate
                        key="4"
                        translate-context="Content/*/Link/Verb"
                      >Select only current page</translate>
                    </a>
                  </template>
                </div>
              </div>
              <div
                v-if="actionErrors.length > 0"
                role="alert"
                class="ui negative message"
              >
                <h4 class="header">
                  <translate translate-context="Content/*/Error message/Header">
                    Error while applying action
                  </translate>
                </h4>
                <ul class="list">
                  <li
                    v-for="(error, key) in actionErrors"
                    :key="key"
                  >
                    {{ error }}
                  </li>
                </ul>
              </div>
              <div
                v-if="actionResult"
                class="ui positive message"
              >
                <p>
                  <translate
                    translate-context="Content/*/Paragraph"
                    :translate-n="actionResult.updated"
                    :translate-params="{count: actionResult.updated, action: actionResult.action}"
                    translate-plural="Action %{ action } was launched successfully on %{ count } elements"
                  >
                    Action %{ action } was launched successfully on %{ count } element
                  </translate>
                </p>

                <slot
                  name="action-success-footer"
                  :result="actionResult"
                />
              </div>
            </div>
          </th>
        </tr>
        <tr>
          <th v-if="actions.length > 0">
            <div class="ui checkbox">
              <input
                type="checkbox"
                :aria-label="labels.selectAllItems"
                :disabled="checkable.length === 0 || null"
                :checked="checkable.length > 0 && checked.length === checkable.length"
                @change="toggleCheckAll"
              >
            </div>
          </th>
          <slot name="header-cells" />
        </tr>
      </thead>
      <tbody v-if="objectsData.count > 0">
        <tr
          v-for="(obj, index) in objects"
          :key="index"
        >
          <td
            v-if="actions.length > 0"
            class="collapsing"
          >
            <input
              type="checkbox"
              :aria-label="labels.selectItem"
              :disabled="checkable.indexOf(getId(obj)) === -1 || null"
              :checked="checked.indexOf(getId(obj)) > -1"
              @click="toggleCheck($event, getId(obj), index)"
            >
          </td>
          <slot
            name="row-cells"
            :obj="obj"
          />
        </tr>
      </tbody>
    </table>
  </div>
</template>
<script>
import axios from 'axios'

export default {
  components: {},
  props: {
    actionUrl: { type: String, required: false, default: null },
    idField: { type: String, required: false, default: 'id' },
    refreshable: { type: Boolean, required: false, default: false },
    needsRefresh: { type: Boolean, required: false, default: false },
    objectsData: { type: Object, required: true },
    actions: { type: Array, required: true, default: () => { return [] } },
    filters: { type: Object, required: false, default: () => { return {} } },
    customObjects: { type: Array, required: false, default: () => { return [] } }
  },
  data () {
    const d = {
      checked: [],
      actionLoading: false,
      actionResult: null,
      actionErrors: [],
      currentActionName: null,
      selectAll: false,
      lastCheckedIndex: -1
    }
    if (this.actions.length > 0) {
      d.currentActionName = this.actions[0].name
    }
    return d
  },
  computed: {
    currentAction () {
      const self = this
      return this.actions.filter((a) => {
        return a.name === self.currentActionName
      })[0]
    },
    checkable () {
      const self = this
      if (!this.currentAction) {
        return []
      }
      let objs = this.objectsData.results
      const filter = this.currentAction.filterCheckable
      if (filter) {
        objs = objs.filter((o) => {
          return filter(o)
        })
      }
      return objs.map((o) => { return self.getId(o) })
    },
    objects () {
      const self = this
      return this.objectsData.results.map((o) => {
        const custom = self.customObjects.filter((co) => {
          return self.getId(co) === self.getId(o)
        })[0]
        if (custom) {
          return custom
        }
        return o
      })
    },
    labels () {
      return {
        refresh: this.$pgettext('Content/*/Button.Tooltip/Verb', 'Refresh table content'),
        selectAllItems: this.$pgettext('Content/*/Select/Verb', 'Select all items'),
        performAction: this.$pgettext('Content/*/Button.Label', 'Perform actions'),
        selectItem: this.$pgettext('Content/*/Select/Verb', 'Select')
      }
    },
    affectedObjectsCount () {
      if (this.selectAll) {
        return this.objectsData.count
      }
      return this.checked.length
    }
  },
  watch: {
    objectsData: {
      handler () {
        this.checked = []
        this.selectAll = false
      },
      deep: true
    },
    currentActionName () {
      // we update checked status as some actions have specific filters
      // on what is checkable or not
      const self = this
      this.checked = this.checked.filter(r => {
        return self.checkable.indexOf(r) > -1
      })
    }
  },
  methods: {
    toggleCheckAll () {
      this.lastCheckedIndex = -1
      if (this.checked.length === this.checkable.length) {
        // we uncheck
        this.checked = []
      } else {
        this.checked = this.checkable.map(i => { return i })
      }
    },
    toggleCheck (event, id, index) {
      const self = this
      let affectedIds = [id]
      let newValue = null
      if (this.checked.indexOf(id) > -1) {
        // we uncheck
        this.selectAll = false
        newValue = false
      } else {
        newValue = true
      }
      if (event.shiftKey && this.lastCheckedIndex > -1) {
        // we also add inbetween ids to the list of affected ids
        const idxs = [index, this.lastCheckedIndex]
        idxs.sort((a, b) => a - b)
        const objs = this.objectsData.results.slice(idxs[0], idxs[1] + 1)
        affectedIds = affectedIds.concat(objs.map((o) => { return o.id }))
      }
      affectedIds.forEach((i) => {
        const checked = self.checked.indexOf(i) > -1
        if (newValue && !checked && self.checkable.indexOf(i) > -1) {
          return self.checked.push(i)
        }
        if (!newValue && checked) {
          self.checked.splice(self.checked.indexOf(i), 1)
        }
      })
      this.lastCheckedIndex = index
    },
    launchAction () {
      const self = this
      self.actionLoading = true
      self.result = null
      self.actionErrors = []
      const payload = {
        action: this.currentActionName,
        filters: this.filters
      }
      if (this.selectAll) {
        payload.objects = 'all'
      } else {
        payload.objects = this.checked
      }
      axios.post(this.actionUrl, payload).then((response) => {
        self.actionResult = response.data
        self.actionLoading = false
        self.$emit('action-launched', response.data)
      }, error => {
        self.actionLoading = false
        self.actionErrors = error.backendErrors
      })
    },
    getId (obj) {
      return obj[this.idField]
    }
  }
}
</script>
