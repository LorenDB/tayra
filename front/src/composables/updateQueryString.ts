export default (uri: string, key: string, value: string) => {
  const url = new URL(uri)
  url.searchParams.set(key, value)
  return url.href
}
