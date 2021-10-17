import { expect } from 'chai'
import PasswordInput from '@/components/forms/PasswordInput.vue'
import { shallowMount } from '@vue/test-utils'
const sinon = require('sinon')

describe('PasswordInput', () => {
  const password = 'password'
  let sandbox

  beforeEach(function () {
    sandbox = sinon.createSandbox()
  })

  afterEach(function () {
    sandbox.restore()
  })
  const wrapper = shallowMount(PasswordInput, {
    mocks: {
      $pgettext: () => 'dummy',
      $store: {
        commit: () => { }
      }
    }
  })
  wrapper.setProps({ value: password, copyButton: true })
  it('password input has passed value', () => {
    const inputElement = wrapper.find('input')
    expect(inputElement.element.value).to.equal(password)
  })
  it('copy password function called', () => {
    const spy = sandbox.spy()
    wrapper.setMethods({
      copyPassword: spy
    })
    sandbox.stub(PasswordInput.methods, '_copyStringToClipboard').callsFake()
    const copyButton = wrapper.findAll('button').at(1)
    copyButton.trigger('click')
    sandbox.assert.calledOnce(spy)
  })
})
