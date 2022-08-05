import type { APIErrorResponse } from '~/types'

import { startCase } from 'lodash-es'

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

export function getDomain (url: string) {
  return new URL(url).hostname
}

export function arrayMove (arr: unknown[], oldIndex: number, newIndex: number) {
  if (newIndex >= arr.length) {
    arr.push(...Array(newIndex - arr.length + 1))
  }

  arr.splice(newIndex, 0, arr.splice(oldIndex, 1)[0])
  return arr
}
