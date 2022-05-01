<template>
  <div
    v-title="labels.title"
    class="ui vertical stripe segment"
  >
    <div>
      <section>
        <h2 class="ui header">
          <translate translate-context="Content/Radio/Title">
            Builder
          </translate>
        </h2>
        <p>
          <translate translate-context="Content/Radio/Paragraph">
            You can use this interface to build your own custom radio, which will play tracks according to your criteria.
          </translate>
        </p>
        <div class="ui form">
          <div
            v-if="success"
            class="ui positive message"
          >
            <h4 class="header">
              <template v-if="radioName">
                <translate translate-context="Content/Radio/Message">
                  Radio updated
                </translate>
              </template>
              <template v-else>
                <translate translate-context="Content/Radio/Message">
                  Radio created
                </translate>
              </template>
            </h4>
          </div>
          <div class="">
            <div class="field">
              <label for="name"><translate translate-context="Content/Radio/Input.Label/Noun">Radio name</translate></label>
              <input
                id="name"
                v-model="radioName"
                name="name"
                type="text"
                :placeholder="labels.placeholder.name"
              >
            </div>
            <div class="field">
              <label for="description"><translate translate-context="*/*/*/Noun">Description</translate></label>
              <textarea
                id="description"
                v-model="radioDesc"
                rows="2"
                type="text"
                :placeholder="labels.placeholder.description"
              />
            </div>
            <div class="ui toggle checkbox">
              <input
                id="public"
                v-model="isPublic"
                type="checkbox"
              >
              <label for="public"><translate translate-context="Content/Radio/Checkbox.Label/Verb">Display publicly</translate></label>
            </div>
            <div class="ui hidden divider" />
            <button
              :disabled="!canSave || null"
              :class="['ui', 'success', {loading: isLoading}, 'button']"
              @click="save"
            >
              <translate translate-context="Content/*/Button.Label/Verb">
                Save
              </translate>
            </button>
            <radio-button
              v-if="id"
              type="custom"
              :custom-radio-id="id"
            />
          </div>
        </div>
        <div class="ui form">
          <div class="inline field">
            <label
              id="radioFilterLabel"
              for="radio-filters"
            ><translate translate-context="Content/Radio/Paragraph">Add filters to customize your radio</translate></label>
            <select
              id="radio-filters"
              v-model="currentFilterType"
              class="ui dropdown"
            >
              <option value="">
                <translate translate-context="Content/Radio/Dropdown.Placeholder/Verb">
                  Select a filter
                </translate>
              </option>
              <option
                v-for="(f, key) in availableFilters"
                :key="key"
                :value="f.type"
              >
                {{ f.label }}
              </option>
            </select>
            <button
              id="addFilter"
              :disabled="!currentFilterType || null"
              class="ui button"
              @click="add"
            >
              <translate translate-context="Content/Radio/Button.Label/Verb">
                Add filter
              </translate>
            </button>
          </div>
          <p v-if="currentFilter">
            {{ currentFilter.help_text }}
          </p>
        </div>
        <table class="ui table">
          <thead>
            <tr>
              <th class="two wide">
                <translate translate-context="Content/Radio/Table.Label/Noun">
                  Filter name
                </translate>
              </th>
              <th class="one wide">
                <translate translate-context="Content/Radio/Table.Label/Verb">
                  Exclude
                </translate>
              </th>
              <th class="six wide">
                <translate translate-context="Content/Radio/Table.Label/Verb (Value is a List of Parameters)">
                  Config
                </translate>
              </th>
              <th class="five wide">
                <translate translate-context="Content/Radio/Table.Label/Noun (Value is a number of Tracks)">
                  Candidates
                </translate>
              </th>
              <th class="two wide">
                <translate translate-context="Content/*/*/Noun">
                  Actions
                </translate>
              </th>
            </tr>
          </thead>
          <tbody>
            <builder-filter
              v-for="(f, index) in filters"
              :key="(f, index, f.hash)"
              :index="index"
              :config="f.config"
              :filter="f.filter"
              @update-config="updateConfig"
              @delete="deleteFilter"
            />
          </tbody>
        </table>
        <template v-if="checkResult && checkResult.candidates && checkResult.candidates.count">
          <h3
            v-translate="{count: checkResult.candidates.count}"
            class="ui header"
            :translate-n="checkResult.candidates.count"
            translate-plural="%{ count } tracks matching combined filters"
            translate-context="Content/Radio/Table.Paragraph/Short"
          >
            %{ count } track matching combined filters
          </h3>
          <track-table
            v-if="checkResult.candidates.sample"
            :tracks="checkResult.candidates.sample"
            :playable="true"
            :show-position="false"
            :show-duration="false"
            :display-actions="false"
          />
        </template>
      </section>
    </div>
  </div>
</template>
<script>
import axios from 'axios'
import $ from 'jquery'
import { clone } from 'lodash-es'
import BuilderFilter from './Filter.vue'
import TrackTable from '~/components/audio/track/Table.vue'
import RadioButton from '~/components/radios/Button.vue'

export default {
  components: {
    BuilderFilter,
    TrackTable,
    RadioButton
  },
  props: {
    id: { type: Number, required: false, default: 0 }
  },
  data: function () {
    return {
      isLoading: false,
      success: false,
      availableFilters: [],
      currentFilterType: null,
      filters: [],
      checkResult: null,
      radioName: '',
      radioDesc: '',
      isPublic: true
    }
  },
  computed: {
    labels () {
      const title = this.$pgettext('Head/Radio/Title', 'Radio Builder')
      const placeholder = {
        name: this.$pgettext('Content/Radio/Input.Placeholder', 'My awesome radio'),
        description: this.$pgettext('Content/Radio/Input.Placeholder', 'My awesome description')
      }
      return {
        title,
        placeholder
      }
    },
    canSave: function () {
      return this.radioName.length > 0 && this.checkErrors.length === 0
    },
    checkErrors: function () {
      if (!this.checkResult) {
        return []
      }
      const errors = this.checkResult.errors
      return errors
    },
    currentFilter: function () {
      const self = this
      return this.availableFilters.filter(e => {
        return e.type === self.currentFilterType
      })[0]
    }
  },
  watch: {
    filters: {
      handler: function () {
        this.fetchCandidates()
      },
      deep: true
    }
  },
  created: function () {
    const self = this
    this.fetchFilters().then(() => {
      if (self.id) {
        self.fetch()
      }
    })
  },
  mounted () {
    $('.ui.dropdown').dropdown()
  },
  methods: {
    fetchFilters: function () {
      const self = this
      const url = 'radios/radios/filters/'
      return axios.get(url).then(response => {
        self.availableFilters = response.data
      })
    },
    add () {
      this.filters.push({
        config: {},
        filter: this.currentFilter,
        hash: +new Date()
      })
      this.fetchCandidates()
    },
    updateConfig (index, field, value) {
      this.filters[index].config[field] = value
      this.fetchCandidates()
    },
    deleteFilter (index) {
      this.filters.splice(index, 1)
      this.fetchCandidates()
    },
    fetch: function () {
      const self = this
      self.isLoading = true
      const url = 'radios/radios/' + this.id + '/'
      axios.get(url).then(response => {
        self.filters = response.data.config.map(f => {
          return {
            config: f,
            filter: this.availableFilters.filter(e => {
              return e.type === f.type
            })[0],
            hash: +new Date()
          }
        })
        self.radioName = response.data.name
        self.radioDesc = response.data.description
        self.isPublic = response.data.is_public
        self.isLoading = false
      })
    },
    fetchCandidates: function () {
      const self = this
      const url = 'radios/radios/validate/'
      let final = this.filters.map(f => {
        const c = clone(f.config)
        c.type = f.filter.type
        return c
      })
      final = {
        filters: [{ type: 'group', filters: final }]
      }
      axios.post(url, final).then(response => {
        self.checkResult = response.data.filters[0]
      })
    },
    save: function () {
      const self = this
      self.success = false
      self.isLoading = true

      let final = this.filters.map(f => {
        const c = clone(f.config)
        c.type = f.filter.type
        return c
      })
      final = {
        name: this.radioName,
        description: this.radioDesc,
        is_public: this.isPublic,
        config: final
      }
      if (this.id) {
        const url = 'radios/radios/' + this.id + '/'
        axios.put(url, final).then(response => {
          self.isLoading = false
          self.success = true
        })
      } else {
        const url = 'radios/radios/'
        axios.post(url, final).then(response => {
          self.success = true
          self.isLoading = false
          self.$router.push({
            name: 'library.radios.detail',
            params: {
              id: response.data.id
            }
          })
        })
      }
    }
  }
}
</script>
