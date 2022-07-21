import EmbedFrame from './EmbedFrame.vue'
import { createApp } from 'vue'

// @ts-expect-error vue-plyr has no types defined
import VuePlyr from 'vue-plyr'

const app = createApp(EmbedFrame)
app.use(VuePlyr)
app.mount('#app')
