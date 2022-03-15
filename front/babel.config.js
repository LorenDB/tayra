module.exports = {
  presets: [
    '@babel/preset-env',
  ],
  plugins: [
    '@babel/plugin-transform-runtime',
    function () {
      return {
        visitor: {
          MetaProperty(path) {
            path.replaceWithSourceString('process')
          },
        },
      }
    },
  ],
}
