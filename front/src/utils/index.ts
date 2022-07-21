import { startCase } from 'lodash-es'
import type { Store } from 'vuex'
import type { Router } from 'vue-router'
import type { APIErrorResponse } from '~/types'
import type { RootState } from '~/store'

export function setUpdate (obj: object, statuses: Record<string, unknown>, value: unknown) {
  for (const key of Object.keys(obj)) {
    statuses[key] = value
  }
}

export function parseAPIErrors (responseData: APIErrorResponse, parentField?: string): string[] {
  const errors = []
  for (const [field, value] of Object.entries(responseData)) {
    let fieldName = startCase(field.replace(/_/g, ' '))
    if (parentField) {
      fieldName = `${parentField} - ${fieldName}`
    }

    if (Array.isArray(value)) {
      errors.push(...value.map(err => {
        if (typeof err === 'string') {
          return err.toLocaleLowerCase().includes('this field ')
            ? `${fieldName}: ${err}`
            : err
        }

        return startCase(err.code.replace(/_/g, ' '))
      }))

      continue
    }

    // Handle nested errors
    errors.push(...parseAPIErrors(value, fieldName))
  }

  return errors
}

export function getCookie (name: string) {
  return document.cookie
    .split('; ')
    .find(row => row.startsWith(name))
    ?.split('=')[1]
}

// TODO (wvffle): Use navigation guards
export async function checkRedirectToLogin (store: Store<RootState>, router: Router) {
  if (!store.state.auth.authenticated) {
    return router.push({ name: 'login', query: { next: router.currentRoute.value.fullPath } })
  }
}

export function getDomain (url: string) {
  const parser = document.createElement('a')
  parser.href = url
  return parser.hostname
}

export function arrayMove (arr: unknown[], oldIndex: number, newIndex: number) {
  if (newIndex >= arr.length) {
    arr.push(...Array(newIndex - arr.length + 1))
  }

  arr.splice(newIndex, 0, arr.splice(oldIndex, 1)[0])
  return arr
}
