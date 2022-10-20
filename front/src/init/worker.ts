import { registerMainThread } from '#/communication'

import Worker from '~/worker/webworker?worker'

export const worker = new Worker()
registerMainThread(worker)
