// helper for testing action with expected mutations
import Vue from 'vue'
import { expect } from 'chai'

export const render = (Component, props) => {
  const Constructor = Vue.extend(Component)
  return new Constructor({ props }).$mount()
}

export const testAction = ({ action, payload, params, expectedMutations, expectedActions }, done) => {
  let mutationsCount = 0
  let actionsCount = 0

  if (!expectedMutations) {
    expectedMutations = []
  }
  if (!expectedActions) {
    expectedActions = []
  }

  // mock commit
  const commit = (type, payload) => {
    const mutation = expectedMutations[mutationsCount]

    expect(mutation.type).to.equal(type)
    if (payload) {
      expect(mutation.payload).to.deep.equal(payload)
    }

    mutationsCount++
  }

  // mock dispatch
  const dispatch = (type, payload, options) => {
    const a = expectedActions[actionsCount]
    if (!a) {
      throw Error(`Unexecpted action ${type}`)
    }
    expect(a.type).to.equal(type)
    if (payload) {
      expect(a.payload).to.deep.equal(payload)
    }
    if (a.options) {
      expect(options).to.deep.equal(a.options)
    }
    actionsCount++
  }

  const end = function () {
    // check if no mutations should have been dispatched
    if (expectedMutations.length === 0) {
      expect(mutationsCount).to.equal(0)
    }
    if (expectedActions.length === 0) {
      expect(actionsCount).to.equal(0)
    }
  }

  // call the action with mocked store and arguments
  const promise = action({ commit, dispatch, ...params }, payload)
  if (promise) {
    promise.then(end)
    return promise
  } else {
    return end()
  }
}

export const sleep = (n = 0) => new Promise(resolve => setTimeout(resolve, n))
