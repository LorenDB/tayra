<template>
  <tr>
    <td>{{ filter.label }}</td>
    <td>
      <div class="ui toggle checkbox">
        <input
          id="exclude-filter"
          v-model="exclude"
          name="public"
          type="checkbox"
          @change="$emit('update-config', index, 'not', exclude)"
        >
        <label
          for="exclude-filter"
          class="visually-hidden"
        >
          <translate translate-context="Popup/Radio/Title/Noun">Exclude</translate>
        </label>
      </div>
    </td>
    <td>
      <div
        v-for="f in filter.fields"
        :key="f.name"
        :ref="f.name"
        class="ui field"
      >
        <div :class="['ui', 'search', 'selection', 'dropdown', {'autocomplete': f.autocomplete}, {'multiple': f.type === 'list'}]">
          <i class="dropdown icon" />
          <div class="default text">
            {{ f.placeholder }}
          </div>
          <input
            v-if="f.type === 'list' && config[f.name]"
            :id="f.name"
            :value="config[f.name].join(',')"
            type="hidden"
          >
          <div
            v-if="config[f.name]"
            class="ui menu"
          >
            <div
              v-for="(v, i) in config[f.name]"
              :key="v"
              class="ui item"
              :data-value="v"
            >
              <template v-if="config.names">
                {{ config.names[i] }}
              </template>
              <template v-else>
                {{ v }}
              </template>
            </div>
          </div>
        </div>
      </div>
    </td>
    <td>
      <a
        v-if="checkResult"
        href=""
        :class="['ui', {'success': checkResult.candidates.count > 10}, 'label']"
        @click.prevent="showCandidadesModal = !showCandidadesModal"
      >
        {{ checkResult.candidates.count }} tracks matching filter
      </a>
      <modal
        v-if="checkResult"
        :show.sync="showCandidadesModal"
      >
        <h4 class="header">
          <translate translate-context="Popup/Radio/Title/Noun">
            Tracks matching filter
          </translate>
        </h4>
        <div class="content">
          <div class="description">
            <track-table
              v-if="checkResult.candidates.count > 0"
              :tracks="checkResult.candidates.sample"
            />
          </div>
        </div>
        <div class="actions">
          <button class="ui deny button">
            <translate translate-context="*/*/Button.Label/Verb">
              Cancel
            </translate>
          </button>
        </div>
      </modal>
    </td>
    <td>
      <button
        class="ui danger button"
        @click="$emit('delete', index)"
      >
        <translate translate-context="Content/Radio/Button.Label/Verb">
          Remove
        </translate>
      </button>
    </td>
  </tr>
</template>
<script>
import axios from 'axios'
import $ from 'jquery'
import { clone } from 'lodash-es'

import Modal from '@/components/semantic/Modal.vue'
import TrackTable from '@/components/audio/track/Table.vue'

export default {
  components: {
    TrackTable,
    Modal
  },
  props: {
    filter: { type: Object, required: true },
    config: { type: Object, required: true },
    index: { type: Number, required: true }
  },
  data: function () {
    return {
      checkResult: null,
      showCandidadesModal: false,
      exclude: this.config.not
    }
  },
  watch: {
    exclude: function () {
      this.fetchCandidates()
    }
  },
  mounted: function () {
    const self = this
    this.filter.fields.forEach(f => {
      const selector = ['.dropdown']
      const settings = {
        onChange: function (value, text, $choice) {
          value = $(this).dropdown('get value').split(',')
          if (f.type === 'list' && f.subtype === 'number') {
            value = value.map(e => {
              return parseInt(e)
            })
          }
          self.value = value
          self.$emit('update-config', self.index, f.name, value)
          self.fetchCandidates()
        }
      }
      if (f.type === 'list') {
        selector.push('.multiple')
      }
      if (f.autocomplete) {
        selector.push('.autocomplete')
        settings.fields = f.autocomplete_fields
        settings.minCharacters = 1
        settings.apiSettings = {
          url: self.$store.getters['instance/absoluteUrl'](f.autocomplete + '?' + f.autocomplete_qs),
          beforeXHR: function (xhrObject) {
            if (self.$store.state.auth.oauth.accessToken) {
              xhrObject.setRequestHeader('Authorization', self.$store.getters['auth/header'])
            }
            return xhrObject
          },
          onResponse: function (initialResponse) {
            if (settings.fields.remoteValues) {
              return initialResponse
            }
            return { results: initialResponse.results }
          }
        }
      }
      $(self.$el).find(selector.join('')).dropdown(settings)
    })
  },
  methods: {
    fetchCandidates: function () {
      const self = this
      const url = 'radios/radios/validate/'
      let final = clone(this.config)
      final.type = this.filter.type
      final = { filters: [final] }
      axios.post(url, final).then((response) => {
        self.checkResult = response.data.filters[0]
      })
    }
  }
}
</script>
