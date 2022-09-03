import type { BackendError } from '~/types'

import { gettext } from '~/init/locale'
import { COOKIE } from '~/init/sentry'

import useLogger from '~/composables/useLogger'
import store from '~/store'

const { $pgettext } = gettext
const logger = useLogger()

async function useErrorHandler (error: Error | BackendError): Promise<void>
async function useErrorHandler (error: Error | BackendError, eventId?: string): Promise<void>
async function useErrorHandler (error: Error | BackendError, eventId?: string): Promise<void> {
  const title = 'backendErrors' in error
    ? 'Unexpected API error'
    : 'Unexpected error'

  let content = $pgettext('App/Message/Paragraph', 'An unexpected error occured.')

  if ('backendErrors' in error) {
    logger.error(title, error, error.backendErrors)
  } else {
    logger.error(title, error)
  }

  const date = new Date()
  const actions = []

  if (import.meta.env.FUNKWHALE_SENTRY_DSN) {
    const [Sentry, { useCookies }] = await Promise.all([
      import('@sentry/vue'),
      import('@vueuse/integrations/useCookies')
    ])

    const { get } = useCookies()
    if (get(COOKIE) === 'yes') {
      content = $pgettext('App/Message/Paragraph', 'An unexpected error occured. <br><sub>To help us understand why it happened, please attach a detailed description of what you did that has triggered the error.</sub>')
      const user = store.state.auth.authenticated
        ? {
            name: store.state.auth.username,
            email: store.state.auth.profile?.email
          }
        : undefined

      actions.push({
        text: $pgettext('App/Message/Paragraph', 'Leave feedback'),
        class: 'basic red',
        click: () => Sentry.showReportDialog({
          eventId: eventId ?? Sentry.captureException(error),
          user
        })
      })
    }
  }

  if ('isHandled' in error && error.isHandled) {
    return
  }

  store.commit('ui/addMessage', {
    content,
    date,
    class: 'error',
    key: `error-${date}`,
    classActions: 'bottom attached opaque',
    actions
  })
}

export default useErrorHandler
