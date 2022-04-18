import { InitModule } from '~/types'
import VueLazyload from 'vue3-lazyload'

export const install: InitModule = ({ app }) => {
  app.use(VueLazyload)
}
