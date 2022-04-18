import { useColorMode } from '@vueuse/core'

const theme = useColorMode({
  selector: 'body',
  modes: {
    auto: '',
    light: 'theme-light',
    dark: 'theme-dark'
  }
})

export default () => theme
