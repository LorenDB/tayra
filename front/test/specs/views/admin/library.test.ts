import DangerousButton from '~/components/common/DangerousButton.vue'
import AlbumDetail from '~/views/admin/library/AlbumDetail.vue'
import SanitizedHtml from '~/components/SanitizedHtml.vue'
import HumanDate from '~/components/common/HumanDate.vue'

import MockAdapter from 'axios-mock-adapter'
import axios from 'axios'

import { shallowMount } from '@vue/test-utils'
import { sleep } from '?/utils'

import router from '~/router'
import store from '~/store'

const axiosMock = new MockAdapter(axios)

describe('views/admin/library', () => {
  describe('Album details', () => {
    it('displays default cover', async () => {
      const album = { cover: null, artist: { id: 1 }, title: 'dummy', id: 1, creation_date: '2020-01-01' }

      axiosMock.onGet('manage/library/albums/1/').reply(200, album)
      axiosMock.onGet('manage/library/albums/1/stats/').reply(200, {})

      const wrapper = shallowMount(AlbumDetail, {
        props: { id: 1 },
        directives: {
          dropdown: () => null,
          title: () => null,
          lazy: () => null
        },
        global: {
          stubs: { DangerousButton, HumanDate, SanitizedHtml },
          plugins: [router, store]
        }
      })

      await sleep()
      expect(wrapper.find('img').attributes('src')).to.include('default-cover')
    })
  })
})
