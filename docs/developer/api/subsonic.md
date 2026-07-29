# Subsonic API

Funkwhale supports a subset of the [Subsonic API's](http://www.subsonic.org/pages/api.jsp) endpoints. This enables users to listen to music stored on their Funkwhale pod through a Subsonic-compatible app.

We aim to support as many endpoints as we can to give Subsonic users the best possible experience. However, some endpoints require a folder-based endpoint. This doesn't match Funkwhale's internal structure, which means emulating them is difficult.

## Supported endpoints

```{note}
We aim to keep this list up-to-date. If you think something is missing, you can see all supported endpoints in the [API views](https://dev.funkwhale.audio/funkwhale/funkwhale/blob/develop/api/funkwhale_api/subsonic/views.py).
```

Funkwhale supports both XML and JSON formats for the following Subsonic endpoints:

- [`createPlaylist`](http://www.subsonic.org/pages/api.jsp#createPlaylist)
- [`deletePlaylist`](http://www.subsonic.org/pages/api.jsp#deletePlaylist)
- [`getAlbum`](http://www.subsonic.org/pages/api.jsp#getAlbum)
- [`getAlbumList2`](http://www.subsonic.org/pages/api.jsp#getAlbumList2)
- [`getArtist`](http://www.subsonic.org/pages/api.jsp#getArtist)
- [`getArtistInfo2`](http://www.subsonic.org/pages/api.jsp#getArtistInfo2)
- [`getArtists`](http://www.subsonic.org/pages/api.jsp#getArtists)
- [`getAvatar`](http://www.subsonic.org/pages/api.jsp#getAvatar)
- [`getCoverArt`](http://www.subsonic.org/pages/api.jsp#getCoverArt)
- [`getIndexes`](http://www.subsonic.org/pages/api.jsp#getIndexes)
- [`getLicense`](http://www.subsonic.org/pages/api.jsp#getLicense)
- [`getMusicFolders`](http://www.subsonic.org/pages/api.jsp#getMusicFolders)
- [`getPlaylist`](http://www.subsonic.org/pages/api.jsp#getPlaylist)
- [`getPlaylists`](http://www.subsonic.org/pages/api.jsp#getPlaylists)
- [`getRandomSongs`](http://www.subsonic.org/pages/api.jsp#getRandomSongs)
- [`getSong`](http://www.subsonic.org/pages/api.jsp#getSong)
- [`getStarred`](http://www.subsonic.org/pages/api.jsp#getStarred)
- [`getStarred2`](http://www.subsonic.org/pages/api.jsp#getStarred2)
- [`getUser`](http://www.subsonic.org/pages/api.jsp#getUser)
- [`ping`](http://www.subsonic.org/pages/api.jsp#ping)
- [`scrobble`](http://www.subsonic.org/pages/api.jsp#scrobble)
- [`search3`](http://www.subsonic.org/pages/api.jsp#search3)
- [`star`](http://www.subsonic.org/pages/api.jsp#star)
- [`stream`](http://www.subsonic.org/pages/api.jsp#stream)
- [`unstar`](http://www.subsonic.org/pages/api.jsp#unstar)
- [`updatePlaylist`](http://www.subsonic.org/pages/api.jsp#updatePlaylist)

### Additional properties

Funkwhale returns some additional properties to Subsonic payloads. You can use these properties to adapt your client behavior if needed:

```{list-table}
   * - Property
      - Data type
      - Description
   * - `type`
      - String
      - The name of the app (`funkwhale`)
   * - `funkwhaleVersion`
      - String
      - The Funkwhale version the pod is running
```

```{code-block} json
{
   "subsonic-response": {
      "type": "funkwhale",
      "funkwhaleVersion": "1.3.0"
   }
}
```

## Test a Subsonic app

We host a demo server at <https://demo.funkwhale.audio> which you can use to test your Subsonic app.

You can test the Subsonic API by logging in with a Subsonic client or by directly by calling an endpoint. For example, call this URL to test the `ping` endpoint: <https://demo.funkwhale.audio/rest/ping.view?f=json>
