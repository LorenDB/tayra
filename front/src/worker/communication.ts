import type { EventHook, EventHookOn } from '@vueuse/core'

import { createEventHook } from '@vueuse/core'

interface MessageChannel {
  hook: EventHook
  post: (data: unknown) => void
  onMessageReceived: EventHookOn
}

let postMessageFn: typeof postMessage | typeof Worker.prototype.postMessage = () => {
  throw new Error('Thread is unregistered')
}

const onMessageFn = (event: MessageEvent) => {
  const { channel, data } = JSON.parse(event.data)
  messageChannels.get(channel)?.hook.trigger(data)
}

export const registerMainThread = (worker: Worker) => {
  worker.onmessage = onMessageFn
  postMessageFn = (message: string) => {
    worker.postMessage(message)
  }
}

export const registerWorkerThread = () => {
  onmessage = onMessageFn
  postMessageFn = (message: string) => {
    postMessage(message)
  }
}

const messageChannels = new Map<string, MessageChannel>()
export const createMessageChannel = (channel: string): MessageChannel => {
  if (messageChannels.has(channel)) {
    const messageChannel = messageChannels.get(channel)
    if (messageChannel) return messageChannel
  }

  const hook = createEventHook()
  const messageChannel: MessageChannel = {
    hook,
    onMessageReceived: hook.on,
    post: (data: unknown) => postMessageFn(JSON.stringify({
      channel,
      data
    }))
  }

  messageChannels.set(channel, messageChannel)
  return messageChannel
}
