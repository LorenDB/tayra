import DangerousButton from '~/components/common/DangerousButton.vue'
import AlbumDetail from '~/views/admin/library/AlbumDetail.vue'
import SanitizedHtml from '~/components/SanitizedHtml.vue'
import HumanDate from '~/components/common/HumanDate.vue'

import moxios from 'moxios'

import { shallowMount } from '@vue/test-utils'
import { gettext } from '~/init/locale'
import { sleep } from '?/utils'

import router from '~/router'
import store from '~/store'

beforeEach(() => moxios.install())
afterEach(() => moxios.uninstall())

describe('views/admin/library', () => {
  describe('Album details', () => {
    it('displays default cover', async () => {
      const album = { cover: null, artist: { id: 1 }, title: 'dummy', id: 1, creation_date: '2020-01-01' }

      moxios.stubRequest('manage/library/albums/1/', {
        status: 200,
        response: album
      })

      moxios.stubRequest('manage/library/albums/1/stats/', {
        status: 200,
        response: {}
      })

      const wrapper = shallowMount(AlbumDetail, {
        props: { id: 1 },
        directives: {
          dropdown: () => null,
          title: () => null,
          lazy: () => null
        },
        global: {
          stubs: { DangerousButton, HumanDate, SanitizedHtml },
          plugins: [gettext, router, store]
        }
      })

      await sleep()
      expect(wrapper.find('img').attributes('src')).to.include('default-cover')
    })
  })
})
