<script setup lang="ts">
import { useRouter } from 'vue-router'
import { useStore } from '~/store'
import { onMounted } from 'vue'

interface Props {
  state: string
  code: string
}

const props = defineProps<Props>()

const router = useRouter()
const store = useStore()

onMounted(async () => {
  await store.dispatch('auth/handleOauthCallback', props.code)
  router.push(props.state ?? '/library')
})
</script>

<template>
  <main class="main pusher">
    <section class="ui vertical stripe segment">
      <div class="ui small text container">
        <div class="ui hidden divider" />
        <div class="ui active inverted dimmer">
          <div class="ui text loader">
            <h2>
              <translate translate-context="*/Login/*">
                Logging in…
              </translate>
            </h2>
          </div>
        </div>
      </div>
    </section>
  </main>
</template>
