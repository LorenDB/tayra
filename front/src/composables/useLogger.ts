import Logger from 'js-logger'
Logger.useDefaults({
  defaultLevel: import.meta.env.DEV
    ? Logger.DEBUG
    : Logger.WARN
})

export default (logger?: string) => logger
  ? Logger.get(logger)
  : Logger
