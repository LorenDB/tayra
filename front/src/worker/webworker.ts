import { registerWorkerThread } from '#/communication'
registerWorkerThread()

import.meta.glob('./modules/*.ts', { eager: true })
