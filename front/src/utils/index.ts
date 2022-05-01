import { startCase } from 'lodash-es'
import { Store } from 'vuex'
import { Router } from 'vue-router'
import { APIErrorResponse } from '~/types'

export function setUpdate (obj: object, statuses: Record<string, unknown>, value: unknown) {
  for (const key of Object.keys(obj)) {
    statuses[key] = value
  }
}

export function parseAPIErrors (responseData: APIErrorResponse, parentField?: string): string[] {
  const errors = []
  for (const field in responseData) {
    if (Object.prototype.hasOwnProperty.call(responseData, field)) {
      let fieldName = startCase(field.replace('_', ' '))
      if (parentField) {
        fieldName = `${parentField} - ${fieldName}`
      }

      const value = responseData[field]
      if (Array.isArray(value)) {
        const values = value
        errors.push(...values.map(err => {
          return err.toLocaleLowerCase().includes('this field ')
            ? `${fieldName}: ${err}`
            : err
        }))
      } else if (value) {
        // nested errors
        const nestedErrors = parseAPIErrors(value, fieldName)
        errors.push(...nestedErrors)
      }
    }
  }

  return errors
}

export function getCookie (name: string) {
  return document.cookie
    .split('; ')
    .find(row => row.startsWith(name))
    ?.split('=')[1]
}

export function setCsrf (xhr: XMLHttpRequest) {
  const token = getCookie('csrftoken')
  if (token) {
    xhr.setRequestHeader('X-CSRFToken', token)
  }
}

// TODO (wvffle): Use navigation guards
export async function checkRedirectToLogin (store: Store<any>, router: Router) {
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
