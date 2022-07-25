import type { MaybeComputedRef } from '@vueuse/core'

import { resolveUnref } from '@vueuse/core'
import { computed } from 'vue'
import showdown from 'showdown'

showdown.extension('openExternalInNewTab', {
  type: 'output',
  regex: /<a.+?href.+">/g,
  replace (text: string) {
    const matches = text.match(/href="(.+)">/) ?? []
    const url = matches[1] ?? './'

    if ((!url.startsWith('http://') && !url.startsWith('https://')) || url.startsWith('mailto:')) {
      return text
    }

    const { hostname } = new URL(url)
    return hostname !== location.hostname
      ? text.replace(matches[0], `href="${url}" target="_blank" rel="noopener noreferrer">`)
      : text
  }
})

showdown.extension('linkifyTags', {
  type: 'language',
  regex: /#[^\W]+/g,
  replace (text: string) {
    return `<a href="/library/tags/${text.slice(1)}">${text}</a>`
  }
})

const markdown = new showdown.Converter({
  extensions: ['openExternalInNewTab', 'linkifyTags'],
  ghMentions: true,
  ghMentionsLink: '/@{u}',
  simplifiedAutoLink: true,
  openLinksInNewWindow: false,
  simpleLineBreaks: true,
  strikethrough: true,
  tables: true,
  tasklists: true,
  underline: true,
  noHeaderId: true,
  headerLevelStart: 3,
  literalMidWordUnderscores: true,
  excludeTrailingPunctuationFromURLs: true,
  encodeEmails: true,
  emoji: true
})

export const useMarkdownRaw = (md: string) => markdown.makeHtml(md)
export const useMarkdownComputed = (md: MaybeComputedRef<string>) => computed(() => useMarkdownRaw(resolveUnref(md)))

export default useMarkdownComputed
