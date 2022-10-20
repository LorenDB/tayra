import { createMessageChannel } from '#/communication'

export default (channel: string) => {
  return createMessageChannel(channel)
}
