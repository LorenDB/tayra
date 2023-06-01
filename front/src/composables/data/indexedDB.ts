import {
  setMany as idbSetMany,
  getMany as idbGetMany,
  delMany as idbDelMany
} from 'idb-keyval'

const inMemoryKeyValueStore = new Map<IDBValidKey, any>()
const canUseIndexedDB = new Promise<boolean>(resolve => {
  if (!window.indexedDB) return resolve(false)

  const request = indexedDB.open('indexed-db-available', 3)
  request.onsuccess = () => resolve(true)
  request.onerror = () => resolve(false)
})

export const setMany = async (entries: [IDBValidKey, any][]) => {
  if (await canUseIndexedDB) {
    return idbSetMany(entries)
  }

  for (const entry of entries) {
    inMemoryKeyValueStore.set(...entry)
  }
}

export const getMany = async (keys: IDBValidKey[]) => {
  if (await canUseIndexedDB) {
    return idbGetMany(keys)
  }

  return keys.map(key => inMemoryKeyValueStore.get(key))
}

export const delMany = async (keys: IDBValidKey[]) => {
  if (await canUseIndexedDB) {
    return idbDelMany(keys)
  }

  for (const key of keys) {
    inMemoryKeyValueStore.delete(key)
  }
}
