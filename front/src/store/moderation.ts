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
    fetchContentFilters ({ dispatch, commit }, url) {
      let params = {}
      let promise
      if (url) {
        promise = axios.get(url)
      } else {
        commit('empty')
        params = {
          page_size: 100,
          ordering: '-creation_date'
        }
        promise = axios.get('moderation/content-filters/', { params })
      }
      return promise.then((response) => {
        logger.info('Fetched a batch of ' + response.data.results.length + ' filters')
        if (response.data.next) {
          dispatch('fetchContentFilters', response.data.next)
        }
        response.data.results.forEach((result: ContentFilter) => {
          commit('contentFilter', result)
        })
      })
    },
    deleteContentFilter ({ commit }, uuid) {
      return axios.delete(`moderation/content-filters/${uuid}/`).then(() => {
        commit('deleteContentFilter', uuid)
      })
    }
  }
}

export default store
