package com.texcut.app

import android.graphics.drawable.Icon
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

/**
 * A Quick Settings tile that pauses / resumes system-wide expansion with one
 * tap, without digging into the app or accessibility settings.
 */
class TexcutTileService : TileService() {

    private val store by lazy { SnippetStore(this) }

    override fun onStartListening() {
        updateTile()
    }

    override fun onClick() {
        store.setPaused(!store.isPaused())
        updateTile()
    }

    private fun updateTile() {
        val tile = qsTile ?: return
        val paused = store.isPaused()
        tile.state = if (paused) Tile.STATE_INACTIVE else Tile.STATE_ACTIVE
        tile.label = "texcut"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            tile.subtitle = if (paused) "Paused" else "Active"
        }
        tile.icon = Icon.createWithResource(this, R.drawable.ic_tile)
        tile.updateTile()
    }
}
