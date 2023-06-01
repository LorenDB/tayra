export default (object?: Record<string, string | File | object | null>) => {
  const data = new FormData()

  if (object) {
    for (const [key, value] of Object.entries(object)) {
      if (typeof value === 'string') {
        data.set(key, value)
      } else if (value instanceof File) {
        data.set(key, value, value.name)
      } else {
        data.set(key, JSON.stringify(value))
      }
    }
  }

  return data
}
