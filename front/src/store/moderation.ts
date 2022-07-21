import type { Module } from 'vuex'
import type { RootState } from '~/store/index'

import axios from 'axios'
import { sortBy } from 'lodash-es'
import useLogger from '~/composables/useLogger'

export interface State {
  filters: ContentFilter[]
  showFilterModal: boolean
  showReportModal: boolean
  lastUpdate: Date,
  filterModalTarget: {
    type: null
    target: null | { id: string, name: string }
  }
  reportModalTarget: {
    type: null | 'channel'
    target: null
    typeLabel: string
    label: string
    _obj?: {
      fid?: string
      actor?: { fid: string }
    }
  }
}

export interface ContentFilter {
  uuid: string
  creation_date: Date
  target: {
    type: 'artist'
    id: string
  }
}

const logger = useLogger()

const store: Module<State, RootState> = {
  namespaced: true,
  state: {
    filters: [],
    showFilterModal: false,
    showReportModal: false,
    lastUpdate: new Date(),
    filterModalTarget: {
      type: null,
      target: null
    },
    reportModalTarget: {
      type: null,
      target: null,
      typeLabel: '',
      label: ''
    }
  },
  mutations: {
    filterModalTarget (state, value) {
      state.filterModalTarget = value
    },
    reportModalTarget (state, value) {
      state.reportModalTarget = value
    },
    empty (state) {
      state.filters = []
    },
    contentFilter (state, value) {
      state.filters.push(value)
    },
    showFilterModal (state, value) {
      state.showFilterModal = value
      if (!value) {
        state.filterModalTarget = {
          type: null,
          target: null
        }
      }
    },
    showReportModal (state, value) {
      state.showReportModal = value
      if (!value) {
        state.reportModalTarget = {
          type: null,
          target: null,
          typeLabel: '',
          label: ''
        }
      }
    },
    reset (state) {
      state.filters = []
      state.filterModalTarget = {
        type: null,
        target: null
      }
      state.showFilterModal = false
      state.showReportModal = false
      state.reportModalTarget = {
        type: null,
        target: null,
        typeLabel: '',
        label: ''
      }
    },
    deleteContentFilter (state, uuid) {
      state.filters = state.filters.filter((e) => {
        return e.uuid !== uuid
      })
    }
  },
  getters: {
    artistFilters: (state) => () => {
      const f = state.filters.filter((f) => {
        return f.target.type === 'artist'
      })
      const p = sortBy(f, [(e) => { return e.creation_date }])
      p.reverse()
      return p
    }
  },
  actions: {
    hide ({ commit }, payload) {
      commit('filterModalTarget', payload)
      commit('showFilterModal', true)
    },
    report ({ commit }, payload) {
      commit('reportModalTarget', payload)
      commit('showReportModal', true)
    },
    async fetchContentFilters ({ dispatch, commit }, url) {
      const params = url
        ? {}
        : {
            page_size: 100,
            ordering: '-creation_date'
          }

      if (!url) commit('empty')
      const response = await axios.get(url ?? 'moderation/content-filters/', { params })

      logger.info(`Fetched a batch of ${response.data.results.length} filters`)

      for (const result of response.data.results) {
        commit('contentFilter', result)
      }

      if (response.data.next) {
        await dispatch('fetchContentFilters', response.data.next)
      }
    },
    async deleteContentFilter ({ commit }, uuid) {
      return axios.delete(`moderation/content-filters/${uuid}/`).then(() => {
        commit('deleteContentFilter', uuid)
      })
    }
  }
}

export default store
