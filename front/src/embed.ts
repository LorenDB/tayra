import Vue from 'vue'
import EmbedFrame from './EmbedFrame.vue'
import VuePlyr from 'vue-plyr'

Vue.use(VuePlyr)

Vue.config.productionTip = false
/* eslint-disable no-new */
new Vue({
  el: '#app',
  components: { EmbedFrame },
  render (h) {
    return h('EmbedFrame')
  }
})
