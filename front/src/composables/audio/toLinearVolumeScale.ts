export const DYNAMIC_RANGE = 40 // dB

export default (volume: number) => {
  if (volume <= 0.0) {
    return 0.0
  }

  // (1.0; 0.0) -> (0; -DYNAMIC_RANGE) dB
  const dB = (volume - 1) * DYNAMIC_RANGE
  return Math.pow(10, dB / 20)
}
