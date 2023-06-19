import { defineConfig } from 'cypress'

export default defineConfig({
  chromeWebSecurity: false,
  e2e: {
    // NOTE: Set up plugins
    // setupNodeEvents (on, config) {
    //
    // },
    baseUrl: 'https://demo.funkwhale.audio'
  }
})
