import type { BackendError } from '~/types'

import { gettext } from '~/init/locale'
import { COOKIE } from '~/init/sentry'

import useLogger from '~/composables/useLogger'
import store from '~/store'

const { $pgettext } = gettext
const logger = useLogger()

export default async (error: Error | BackendError) => {
  const title = 'backendErrors' in error
    ? 'Unexpected API error'
    : 'Unexpected error'

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
      const eventId = Sentry.captureException(error)

      const user = store.state.auth.authenticated
        ? {
            name: store.state.auth.username,
            email: store.state.auth.profile?.email
          }
        : undefined

      actions.push({
        text: $pgettext('App/Message/Paragraph', 'Leave feedback'),
        class: 'basic red',
        click: () => Sentry.showReportDialog({ eventId, user })
      })
    }
  }

  store.commit('ui/addMessage', {
    content: $pgettext('App/Message/Paragraph', 'An unexpected error occured.'),
    date,
    class: 'error',
    key: `error-${date}`,
    classActions: 'bottom attached opaque',
    actions
  })
}
