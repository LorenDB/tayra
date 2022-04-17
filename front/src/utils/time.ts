function pad (val: number) {
  val = Math.floor(val)
  if (val < 10) {
    return '0' + val
  }

  return val + ''
}

export default {
  parse: function (sec: number) {
    const hours = Math.floor(sec / 3600)
    if (hours >= 1) {
      sec = sec % 3600
    }

    const min = Math.floor(sec / 60)
    sec -= min * 60

    return hours >= 1
      ? `${hours}:${pad(min)}:${pad(sec)}`
      : `${pad(min)}:${pad(sec)}`
  },
  durationFormatted (v: string) {
    const duration = parseInt(v)
    return this.parse(duration % 1 !== 0 ? 0 : Math.round(duration))
  }
}
