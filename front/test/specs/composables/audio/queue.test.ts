import { useQueue } from '~/composables/audio/queue'
import type { Track } from '~/types'

const { tracks, enqueue, dequeue, clear, reorder, currentIndex, shuffle } = useQueue()

describe('currentIndex', () => {
  beforeEach(async () => {
    await clear()
    await enqueue(
      { id: 1, uploads: [] } as any as Track,
      { id: 2, uploads: [] } as any as Track,
      { id: 3, uploads: [] } as any as Track,
    )
  })

  describe('clamp', () => {
    it('should be clamped to queue size', () => {
      currentIndex.value = 100
      expect(currentIndex.value).toBe(2)

      currentIndex.value = -100
      expect(currentIndex.value).toBe(0)
    })

    it('should be clamped to queue size after enqueue', async () => {
      await enqueue({ id: 4, uploads: [] } as any as Track)

      currentIndex.value = 100
      expect(currentIndex.value).toBe(3)

      currentIndex.value = -100
      expect(currentIndex.value).toBe(0)
    })

    it('should be clamped to queue size after clear', async () => {
      await clear()
      expect(currentIndex.value).toBe(0)

      currentIndex.value = 100
      expect(currentIndex.value).toBe(0)

      currentIndex.value = -100
      expect(currentIndex.value).toBe(0)
    })

    it('should update currentIndex after removal of last track', async () => {
      await dequeue(2)

      currentIndex.value = 100
      expect(currentIndex.value).toBe(1)

      currentIndex.value = -100
      expect(currentIndex.value).toBe(0)
    })

    it('should update currentIndex after removal of last track', async () => {
      currentIndex.value = 2
      tracks.value.splice(2, 1)
      expect(currentIndex.value).toBe(1)

      currentIndex.value = 100
      expect(currentIndex.value).toBe(1)

      currentIndex.value = -100
      expect(currentIndex.value).toBe(0)
    })

    it('should update currentIndex after removal of middle track', async () => {
      currentIndex.value = 2
      tracks.value.splice(1, 1)
      expect(currentIndex.value).toBe(1)

      currentIndex.value = 100
      expect(currentIndex.value).toBe(1)

      currentIndex.value = -100
      expect(currentIndex.value).toBe(0)
    })
  })
})

describe('Ordered queue', () => {
  beforeEach(async () => {
    await clear()
    await enqueue(
      { id: 1, uploads: [] } as any as Track,
      { id: 2, uploads: [] } as any as Track,
      { id: 3, uploads: [] } as any as Track,
    )
  })

  describe('first track is playing', () => {
    beforeEach(() => {
      currentIndex.value = 0
    })

    it('reorder current track to the middle', () => {
      reorder(0, 1)
      expect(tracks.value).toEqual([2, 1, 3])
      expect(currentIndex.value).toBe(1)
    })

    it('reorder current track to the end', () => {
      reorder(0, 2)
      expect(tracks.value).toEqual([2, 3, 1])
      expect(currentIndex.value).toBe(2)
    })

    it('reorder middle track to the beginning', () => {
      reorder(1, 0)
      expect(tracks.value).toEqual([2, 1, 3])
      expect(currentIndex.value).toBe(1)
    })

    it('reorder middle track to the end', () => {
      reorder(1, 2)
      expect(tracks.value).toEqual([1, 3, 2])
      expect(currentIndex.value).toBe(0)
    })

    it('reorder last track to the beginning', () => {
      reorder(2, 0)
      expect(tracks.value).toEqual([3, 1, 2])
      expect(currentIndex.value).toBe(1)
    })

    it('reorder last track to the middle', () => {
      reorder(2, 1)
      expect(tracks.value).toEqual([1, 3, 2])
      expect(currentIndex.value).toBe(0)
    })
  })

  describe('middle track is playing', () => {
    beforeEach(() => {
      currentIndex.value = 1
    })

    it('reorder current track to the beginning', () => {
      reorder(1, 0)
      expect(tracks.value).toEqual([2, 1, 3])
      expect(currentIndex.value).toBe(0)
    })

    it('reorder current track to the end', () => {
      reorder(1, 2)
      expect(tracks.value).toEqual([1, 3, 2])
      expect(currentIndex.value).toBe(2)
    })

    it('reorder first track to the middle', () => {
      reorder(0, 1)
      expect(tracks.value).toEqual([2, 1, 3])
      expect(currentIndex.value).toBe(0)
    })

    it('reorder first track to the end', () => {
      reorder(0, 2)
      expect(tracks.value).toEqual([2, 3, 1])
      expect(currentIndex.value).toBe(0)
    })

    it('reorder last track to the beginning', () => {
      reorder(2, 0)
      expect(tracks.value).toEqual([3, 1, 2])
      expect(currentIndex.value).toBe(2)
    })

    it('reorder last track to the middle', () => {
      reorder(2, 1)
      expect(tracks.value).toEqual([1, 3, 2])
      expect(currentIndex.value).toBe(2)
    })
  })

  describe('last track is playing', () => {
    beforeEach(() => {
      currentIndex.value = 2
    })

    it('reorder current track to the beginning', () => {
      reorder(2, 0)
      expect(tracks.value).toEqual([3, 1, 2])
      expect(currentIndex.value).toBe(0)
    })

    it('reorder current track to the middle', () => {
      reorder(2, 1)
      expect(tracks.value).toEqual([1, 3, 2])
      expect(currentIndex.value).toBe(1)
    })

    it('reorder first track to the middle', () => {
      reorder(0, 1)
      expect(tracks.value).toEqual([2, 1, 3])
      expect(currentIndex.value).toBe(2)
    })

    it('reorder first track to the end', () => {
      reorder(0, 2)
      expect(tracks.value).toEqual([2, 3, 1])
      expect(currentIndex.value).toBe(1)
    })

    it('reorder middle track to the beginning', () => {
      reorder(1, 0)
      expect(tracks.value).toEqual([2, 1, 3])
      expect(currentIndex.value).toBe(2)
    })

    it('reorder middle track to the end', () => {
      reorder(1, 2)
      expect(tracks.value).toEqual([1, 3, 2])
      expect(currentIndex.value).toBe(1)
    })
  })
})

// TODO: Add tests for the shuffled queue
// describe('Shuffled queue', () => {
//   beforeEach(async () => {
//     await clear()
//     await enqueue(
//       { id: 1, uploads: [] } as any as Track,
//       { id: 2, uploads: [] } as any as Track,
//       { id: 3, uploads: [] } as any as Track,
//     )
//
//     shuffle()
//   })
// })
