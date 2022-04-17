module.exports = {
  env: {
    browser: true,
    es6: true
  },
  extends: [
    'plugin:vue/recommended',
    '@vue/typescript/recommended',
    '@vue/standard'

  ],
  globals: {
    Atomics: 'readonly',
    SharedArrayBuffer: 'readonly'
  },
  parserOptions: {
    ecmaVersion: 2020,
    sourceType: 'module'
  },
  plugins: [
    'vue'
  ],
  rules: {
    'vue/no-v-html': 'off', // TODO: tackle this properly
    'vue/no-use-v-if-with-v-for': 'off',

    '@typescript-eslint/ban-ts-comment': 'off',
    'no-undef': 'off',
    // TODO: Enable typescript rules later
    '@typescript-eslint/no-this-alias': 'off',
    '@typescript-eslint/no-empty-function': 'off'
  }
}
