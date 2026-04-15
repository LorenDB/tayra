package dev.lorendb.tayra.wear

import android.app.Application
import coil.ImageLoader
import coil.ImageLoaderFactory
import coil.disk.DiskCache
import coil.memory.MemoryCache

class WearApplication : Application(), ImageLoaderFactory {

    override fun newImageLoader(): ImageLoader {
        // Build the app-wide ImageLoader lazily on first use instead of doing this work
        // during process startup on the main thread.
        return ImageLoader.Builder(this)
            .memoryCache {
                MemoryCache.Builder(this)
                    .maxSizePercent(0.15)
                    .build()
            }
            .diskCache {
                DiskCache.Builder()
                    .directory(cacheDir.resolve("image_cache"))
                    .maxSizeBytes(20L * 1024 * 1024)
                    .build()
            }
            .build()
    }
}
