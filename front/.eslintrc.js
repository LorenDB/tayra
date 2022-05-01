module.exports = {
  env: {
    browser: true,
    es6: true
  },
  extends: [
    'plugin:vue/vue3-recommended',
    '@vue/typescript/recommended',
    '@vue/standard'

  ],
  globals: {
    Atomics: 'readonly',
    SharedArrayBuffer: 'readonly'
  },
  parser: 'vue-eslint-parser',
  parserOptions: {
    parser: '@typescript-eslint/parser',
    ecmaVersion: 2020,
    sourceType: 'module'
  },
  plugins: [
    'vue'
  ],
  rules: {
    'vue/no-v-html': 'off', // TODO: tackle this properly

    // NOTE: Handled by typescript
    'no-undef': 'off',
    'no-unused-vars': 'off',

    // TODO (wvffle): Migrate to VUI
    //                We're using `// @ts-ignore` in jQuery extensions
    //                and gettext for vue 2
    '@typescript-eslint/ban-ts-comment': 'off',

    // TODO (wvffle): Enable typescript rules later
    '@typescript-eslint/no-this-alias': 'off',
    '@typescript-eslint/no-empty-function': 'off',
    '@typescript-eslint/no-unused-vars': 'off',

    // TODO (wvffle): Migration to pinia
    //                Vuex 3 store does not have types defined, hence we use `any`
    '@typescript-eslint/no-explicit-any': 'off',

    // TODO (wvffle): Migrate to <script setup>
    'vue/require-explicit-emits': 'off'
  }
}
