import { useColorMode } from '@vueuse/core'
import { watch } from '@vue/composition-api'

const theme = useColorMode()

document.body.classList.add(`theme-${theme.value}`)
watch(theme, (newValue, oldValue) => {
  document.body.classList.remove(`theme-${oldValue}`)
  document.body.classList.add(`theme-${newValue}`)
})

export default () => theme
