export default (uri: string, key: string, value: string) => {
  const re = new RegExp(`([?&])${key}=.*?(&|$)`, 'i')
  if (uri.match(re)) {
    return uri.replace(re, `$1${key}=${value}$2`)
  } else {
    const separator = uri.indexOf('?') !== -1 ? '&' : '?'
    return `${uri}${separator}${key}=${value}`
  }
}
