import { expect } from 'chai'
import { truncate } from '~/filters'

describe('filters', () => {
  describe('truncate', () => {
    it('leave strings as it if correct size', () => {
      const input = 'Hello world'
      const output = truncate(input, 100)
      expect(output).to.equal(input)
    })
    it('returns shorter string with character', () => {
      const input = 'Hello world'
      const output = truncate(input, 5)
      expect(output).to.equal('Hello…')
    })
    it('custom ellipsis', () => {
      const input = 'Hello world'
      const output = truncate(input, 5, ' pouet')
      expect(output).to.equal('Hello pouet')
    })
  })
})
