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
    SharedArrayBuffer: 'readonly',
    Atomics: 'readonly'
  },
  parser: 'vue-eslint-parser',
  parserOptions: {
    parser: '@typescript-eslint/parser',
    sourceType: 'module',
    ecmaVersion: 2020
  },
  plugins: [
    'vue'
  ],
  rules: {
    // NOTE: Nicer for the eye
    'operator-linebreak': ['error', 'before'],

    // NOTE: Handled by typescript
    '@typescript-eslint/no-unused-vars': 'off',
    'no-use-before-define': 'off',
    'no-unused-vars': 'off',
    'no-redeclare': 'off',
    'no-undef': 'off',

    // TODO (wvffle): Remove after VUI and #1618
    'vue/multi-word-component-names': 'off',
    'import/extensions': 'off',

    // TODO (wvffle): Remove after embeded player migration
    '@typescript-eslint/no-this-alias': 'off',

    // TODO (wvffle): Remove after API Client
    '@typescript-eslint/no-explicit-any': 'off'
  }
}
