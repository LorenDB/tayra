import EmbedFrame from './EmbedFrame.vue'
import VuePlyr from 'vue-plyr'
import { createApp } from 'vue'

const app = createApp(EmbedFrame)
app.use(VuePlyr)
app.mount('#app')
