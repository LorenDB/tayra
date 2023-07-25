type LogLevel = 'info' | 'warn' | 'error' | 'debug' | 'time'

const LOG_LEVEL_LABELS: Record<LogLevel, string> = {
  info: ' INFO',
  warn: ' WARN',
  error: 'ERROR',
  debug: 'DEBUG',
  time: ' TIME'
}

const LOG_LEVEL_BACKGROUND: Record<LogLevel, string> = {
  info: '#a6e22e',
  warn: '#FF9800',
  error: '#F44336',
  debug: '#00BCD4',
  time: '#00BCD4'
}

const LOG_LEVEL_COLOR: Record<LogLevel, string> = {
  info: '#000',
  warn: '#000',
  error: '#fff',
  debug: '#000',
  time: '#000'
}

const TIMESTAMP_COLOR = '#9E9E9E'

const FILETYPE_BACKGROUND: Record<string, string> = {
  js: '#f1e05a',
  ts: '#2b7489',
  vue: '#41b883',
  html: '#e34c26',
  default: '#ccc'
}

const FILETYPE_COLOR: Record<string, string> = {
  js: '#000',
  ts: '#fff',
  vue: '#fff',
  html: '#fff',
  default: '#000'
}

const getFile = () => {
  const { stack } = new Error()
  const line = stack?.split('\n')[2] ?? ''
  const [, method, url, lineNo] = line.match(/^(\w+)?(?:\/<)*@(.+?)(?:\?.*)?:(\d+):\d+$/) ?? []
  const file = url.startsWith(location.origin) ? url.slice(location.origin.length) : url
  return { method, file, lineNo }
}

// NOTE: We're pushing all logs to the end of the event loop
const createLoggerFn = (level: LogLevel) => {
  return (...args: any[]) => {
    const timestamp = new Date().toUTCString()
    const { method, file, lineNo } = getFile()

    const ext = file?.split('.').pop() ?? 'default'

    // NOTE: Don't log time and debug in production
    if (level === 'time' || level === 'debug') {
      if (import.meta.env.PROD) return
    }

    // eslint-disable-next-line no-console
    console[level === 'time' ? 'debug' : level](
      '%c %c [%s] %c %s %c%s',
      `background: ${LOG_LEVEL_BACKGROUND[level]};border-radius:1em`,
      `color: ${TIMESTAMP_COLOR}`,
      timestamp,
      `background: ${LOG_LEVEL_BACKGROUND[level]}; color: ${LOG_LEVEL_COLOR[level]}; border-radius: 1em 0 0 1em`,
      LOG_LEVEL_LABELS[level],
      `background: ${FILETYPE_BACKGROUND[ext]}; color: ${FILETYPE_COLOR[ext]}; border-radius: 0 1em 1em 0`,
      method !== undefined
        ? ` ${file}:${lineNo} ${method}() `
        : ` ${file}:${lineNo} `,
      ...args
    )
  }
}

const infoLogger = createLoggerFn('info')
const warnLogger = createLoggerFn('warn')
const timeLogger = createLoggerFn('time')

const errorLogger = createLoggerFn('error')
const debugLogger = createLoggerFn('debug')

export const logger = {
  log: infoLogger,
  info: infoLogger,
  warn: warnLogger,
  error: errorLogger,
  debug: debugLogger,
  time: (label: string) => {
    const now = performance.now()

    timeLogger(`${label}: start`)

    return () => {
      const duration = performance.now() - now
      timeLogger(`${label}: ${duration.toFixed(2)}ms`)
    }
  }
}

export default () => logger
