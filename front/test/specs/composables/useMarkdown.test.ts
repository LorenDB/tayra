import { useMarkdownRaw } from '~/composables/useMarkdown'

describe('useMarkdownRaw', () => {
  describe('anchors', () => {
    it('should add target="_blank" to external links', () => {
      const html = useMarkdownRaw('https://open.audio')
      expect(html).toBe('<p><a href="https://open.audio" target="_blank" rel="noopener noreferrer">https://open.audio</a></p>')
    })

    it('should not link raw path', () => {
      const html = useMarkdownRaw('/library/tags')
      expect(html).toBe('<p>/library/tags</p>')
    })

    it('should not add target="_blank" to internal links', () => {
      const html = useMarkdownRaw('[/library/tags](/library/tags)')
      expect(html).toBe('<p><a href="/library/tags">/library/tags</a></p>')
    })

    it('should handle multiple links', () => {
      const html = useMarkdownRaw('https://open.audio https://funkwhale.audio')
      expect(html).toBe('<p><a href="https://open.audio" target="_blank" rel="noopener noreferrer">https://open.audio</a> <a href="https://funkwhale.audio" target="_blank" rel="noopener noreferrer">https://funkwhale.audio</a></p>')
    })
  })
})
