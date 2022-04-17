import { AppModule } from '~/types'

import Vue from 'vue'
import time from '~/utils/time'
import moment from 'moment'

export function truncate (str: string, max = 100, ellipsis = '…', middle = false) {
  if (max === 0) {
    return ''
  }

  if (str.length <= max) {
    return str
  }

  if (middle) {
    const sepLen = 1
    const charsToShow = max - sepLen
    const frontChars = Math.ceil(charsToShow / 2)
    const backChars = Math.floor(charsToShow / 2)

    return str.substr(0, frontChars) +
           ellipsis +
           str.substr(str.length - backChars)
  } else {
    return str.slice(0, max) + ellipsis
  }
}

export function ago (date: Date, locale: string) {
  locale = locale || 'en'
  const m = moment(date)
  m.locale(locale)
  return m.calendar(null, {
    sameDay: 'LT',
    nextDay: 'L',
    nextWeek: 'L',
    lastDay: 'L',
    lastWeek: 'L',
    sameElse: 'L'
  })
}

export function fromNow (date: Date, locale: string) {
  locale = 'en'
  moment.locale('en', {
    relativeTime: {
      future: 'in %s',
      past: '%s ago',
      s: 'seconds',
      ss: '%ss',
      m: 'a minute',
      mm: '%dm',
      h: 'an hour',
      hh: '%dh',
      d: 'a day',
      dd: '%dd',
      M: 'a month',
      MM: '%dM',
      y: 'a year',
      yy: '%dY'
    }
  })
  const m = moment(date)
  m.locale(locale)
  return m.fromNow(true)
}

export function secondsToObject (seconds: number) {
  const m = moment.duration(seconds, 'seconds')
  return {
    seconds: m.seconds(),
    minutes: m.minutes(),
    hours: m.hours()
  }
}

export function padDuration (duration: string) {
  let s = String(duration)
  while (s.length < 2) { s = '0' + s }
  return s
}

export function duration (seconds: string) {
  return time.parse(+seconds)
}

export function momentFormat (date: Date, format: string) {
  format = format || 'lll'
  return moment(date).format(format)
}

export function year (date: Date) {
  return moment(date).year()
}

export function capitalize (str: string) {
  return str.charAt(0).toUpperCase() + str.slice(1)
}

export function humanSize (bytes: number) {
  const si = true
  const thresh = si ? 1000 : 1024
  if (Math.abs(bytes) < thresh) {
    return bytes + ' B'
  }
  const units = si
    ? ['kB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB']
    : ['KiB', 'MiB', 'GiB', 'TiB', 'PiB', 'EiB', 'ZiB', 'YiB']
  let u = -1
  do {
    bytes /= thresh
    ++u
  } while (Math.abs(bytes) >= thresh && u < units.length - 1)
  return bytes.toFixed(1) + ' ' + units[u]
}

// Removes duplicates from a list
export function unique (list: { [key: string]: unknown }[], property: string) {
  property = property || 'id'
  const unique: { [key: string]: unknown }[] = []
  list.map(x => unique.filter(a => a[property] === x[property]).length > 0 ? null : unique.push(x))
  return unique
}

export const install: AppModule = () => {
  Vue.filter('humanSize', humanSize)
  Vue.filter('unique', unique)
  Vue.filter('capitalize', capitalize)
  Vue.filter('moment', momentFormat)
  Vue.filter('year', year)
  Vue.filter('duration', duration)
  Vue.filter('padDuration', padDuration)
  Vue.filter('secondsToObject', secondsToObject)
  Vue.filter('fromNow', fromNow)
  Vue.filter('ago', ago)
  Vue.filter('truncate', truncate)
}
