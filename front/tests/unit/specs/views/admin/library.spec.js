const sinon = require('sinon')
import { expect } from 'chai'
import { shallowMount, createLocalVue } from '@vue/test-utils'
import AlbumDetail from '@/views/admin/library/AlbumDetail.vue'
import GetTextPlugin from 'vue-gettext'

import HumanDate from '@/components/common/HumanDate.vue'
import DangerousButton from '@/components/common/DangerousButton.vue'

describe('views/admin/library', () => {

  let wrapper
  let sandbox
  beforeEach(() => {
    sandbox = sinon.createSandbox()
  })
  afterEach(() => {
    sandbox.restore()
  })
  describe('Album details', () => {

    it('displays default cover', async () => {
      const album = { cover: null, artist: { id: null }, title: "dummy" }
      const localVue = createLocalVue()
      localVue.directive('title', (() => null))
      localVue.directive('dropdown', (() => null))
      localVue.use(GetTextPlugin, { translations: {} })
      // overrides axios calls
      sandbox.stub(AlbumDetail.methods, "fetchData").callsFake(() => null)
      sandbox.stub(AlbumDetail.methods, "fetchStats").callsFake(() => null)
      wrapper = shallowMount(AlbumDetail, {
        localVue,
        data() {
          return {
            isLoading: false,
            isLoadingStats: false,
            object: album,
            stats: [],
          }
        },
        mocks: {
          $store: {
            state: { auth: { profile: null }, ui: { lastDate: null } }
          }
        },
        stubs: {
          'human-date': HumanDate,
          'dangerous-button': DangerousButton
        },
        computed: { labels: () => { return { statsWarning: null } } }
      })
      expect(wrapper.find('img').attributes('src')).to.include("default-cover")
    })
  })
})