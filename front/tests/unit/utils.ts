export const sleep = (seconds = 0) => new Promise<void>(resolve => setTimeout(resolve, seconds))
