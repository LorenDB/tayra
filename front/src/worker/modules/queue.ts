import type { Track } from '~/types'

import { createMessageChannel } from '#/communication'

const { onMessageReceived, post } = createMessageChannel('queue')

const queue: Track[] = []

onMessageReceived((data) => {
  switch (data.type) {
    case 'queue':
      queue.length = 0
      queue.push(...data.tracks)
      break

    case 'enqueue':
      queue.push(...data.tracks)
      post({ type: 'queue', tracks: queue })
      break

    case 'shuffle':
      // TODO: Shuffle queue
      post({ type: 'queue', tracks: [] })
      break

    case 'unshuffle':
      post({ type: 'queue', tracks: queue })
      break
  }
})
