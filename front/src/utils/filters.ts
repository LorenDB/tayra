import moment from 'moment'

export function truncate (str: string, max = 100, ellipsis = '…', middle = false) {
  if (max === 0) return ''
  if (str.length <= max) return str
  if (!middle) return str.slice(0, max) + ellipsis

  const charsToShow = max - ellipsis.length
  return str.slice(0, Math.ceil(charsToShow / 2))
    + ellipsis
    + str.slice(-Math.floor(charsToShow / 2))
}

export function momentFormat (date: Date, format = 'lll') {
  return moment(date).format(format)
}

const HUMAN_UNITS = {
  SI: ['kB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'],
  powerOf2: ['KiB', 'MiB', 'GiB', 'TiB', 'PiB', 'EiB', 'ZiB', 'YiB']
}

export function humanSize (bytes: number, isSI = true) {
  const threshold = isSI ? 1000 : 1024

  if (Math.abs(bytes) < threshold) {
    return `${bytes} B`
  }

  const units = HUMAN_UNITS[isSI ? 'SI' : 'powerOf2']
  let u = -1
  do {
    bytes /= threshold
    ++u
  } while (Math.abs(bytes) >= threshold && u < units.length - 1)

  return `${bytes.toFixed(1)} ${units[u]}`
}
