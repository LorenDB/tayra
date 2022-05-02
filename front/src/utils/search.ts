interface Token {
  field: string | null
  value: string
}

export function normalizeQuery (query: string): string[] {
  // given a string such as 'this is "my query" go', returns
  // an array of tokens like this: ['this', 'is', 'my query', 'go']
  if (!query) return []

  const match = query.match(/\\?.|^$/g)
  if (!match) return []

  const { tokens } = match.reduce((state, c) => {
    if (c === '"') {
      state.quote ^= 1
    } else if (!state.quote && c === ' ') {
      state.tokens.push('')
    } else {
      state.tokens[state.tokens.length - 1] += c.replace(/\\(.)/, '$1')
    }

    return state
  }, { tokens: [''], quote: 0 })

  return tokens
}

const unquote = (str: string) => {
  if (str[0] === '"') str = str.slice(1)
  if (str[str.length - 1] === '"') str = str.slice(0, -1)
  return str
}

export function parseTokens (normalizedQuery: string[]): Token[] {
  // given an array of tokens as returned by normalizeQuery,
  // returns a list of objects such as [
  //  {
  //    field: 'status',
  //    value: 'pending'
  //  },
  //  {
  //    field: null,
  //    value: 'hello'
  //  }
  // ]
  return normalizedQuery.map(t => {
    // we split the token on ":"
    const parts = t.split(/:(.+)/)
    if (parts.length === 1) {
      // no field specified
      return { field: null, value: t }
    }

    // first item is the field, second is the value, possibly quoted
    const [field, value] = parts

    // we remove surrounding quotes if any
    return { field, value: unquote(value) }
  })
}

export function compileTokens (tokens: Token[]) {
  // given a list of tokens as returned by parseTokens,
  // returns a string query
  const parts = tokens.map(token => {
    const { field } = token
    let { value } = token

    if (value.includes(' ')) {
      value = `"${value}"`
    }

    if (field) {
      return `${field}:${value}`
    }

    return value
  })

  return parts.join(' ')
}
