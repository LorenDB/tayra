module.exports = {
  env: {
    browser: true,
    es6: true
  },
  extends: [
    'plugin:@intlify/vue-i18n/recommended',
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

    // NOTE: i18n
    '@intlify/vue-i18n/no-deprecated-i18n-component': 'error',
    '@intlify/vue-i18n/valid-message-syntax': 'error',
    '@intlify/vue-i18n/no-i18n-t-path-prop': 'error',
    '@intlify/vue-i18n/no-missing-keys': 'error',
    '@intlify/vue-i18n/no-unused-keys': ['error', {
      extensions: ['.ts', '.vue'],
      enableFix: true
    }],

    // TODO (wvffle): Remove after VUI and #1618
    'vue/multi-word-component-names': 'off',
    'import/extensions': 'off',

    // TODO (wvffle): Remove after embeded player migration
    '@typescript-eslint/no-this-alias': 'off',

    // TODO (wvffle): Remove after API Client
    '@typescript-eslint/no-explicit-any': 'off'
  },
  overrides: [
    {
      files: ['public/embed.html'],
      rules: {
        // NOTE: It is broken for some reason. It's safe to disable in a .html file as this rule only
        //       brings <!-- eslint-disable --> comments support for the <template> tag in SFCs
        'vue/comment-directive': 'off'
      }
    },
    {
      files: ['*.json'],
      parser: 'jsonc-eslint-parser'
    },
    {
      files: ['src/locales/*.json'],
      rules: {
        'no-irregular-whitespace': 'off'
      }
    }
  ],
  settings: {
    'vue-i18n': {
      localeDir: './src/locales/*.json',
      messageSyntaxVersion: '^9.0.0'
    }
  }
}
