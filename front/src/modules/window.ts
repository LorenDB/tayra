import { AppModule } from '@/types'
import { useWindowSize } from '@vueuse/core'
import { watchEffect } from '@vue/composition-api'

export const install: AppModule = ({ store }) => {
  // NOTE: Due to Vuex 3, when using store in watchEffect, it results in an infinite loop after committing
  const { commit } = store

  const { width, height } = useWindowSize()
  watchEffect(() => {
    commit('ui/window', {
      width: width.value,
      height: height.value
    })
  })
}
