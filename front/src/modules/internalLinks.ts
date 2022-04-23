import { AppModule } from '~/types'

// slight hack to allow use to have internal links in <translate> tags
// while preserving router behaviour
export const install: AppModule = ({ router }) => {
  document.documentElement.addEventListener('click', async (event) => {
    const target = <HTMLAnchorElement> event.target
    if (!target.matches('a.internal')) return

    event.preventDefault()
    return router.push(target.href)
  }, false)
}
