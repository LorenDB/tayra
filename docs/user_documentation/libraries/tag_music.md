# Tag your content with Picard

Funkwhale relies on [ID3 tags](https://wikipedia.org/wiki/ID3) to sort audio content. ID3 tags tell Funkwhale information about your files. Funkwhale uses this information to display your content in your {term}`pod`.

We recommend using [MusicBrainz Picard](https://picard.musicbrainz.org/) to tag your content. MusicBrainz Picard is free and open source software that connects to [MusicBrainz](https://musicbrainz.org). Funkwhale uses MusicBrainz as its primary data source.

This guide shows you how to tag your content with MusicBrainz Picard.

```{contents}
:local:
```

:::{dropdown} Supported tags
:icon: tag

```{list-table}
:header-rows: 1

* - Name
   - Description
   - Example value
* - `Title`*
   - The track title.
   - `Letting you`
* - `Artist`*
   - The artist name.
   - `Nine Inch Nails`
* - `Album`
   - The album title. If none is provided, an `[Unknown Album]` entry is created.
   - `The Slip`
* - `Album artist`
   - The album artist name (can be different than the track artist).
   - `Trent Reznor`
* - `Genre`
   - A comma separated list of tags to associate with the track.
   Other supported separators: `;` and `/`.
   - `Industrial, Metal`
* - `Track number`
   - The position of the track in the album/release.
   - `4`
* - `Disc number`
   - The disc number (in case of multi-disc albums).
   - `1`
* - `Date`
   - The release date of the track or album.
   - `2019`
* - `License`
   - The license associated with this work.
   The first URL found is checked against our list of supported licenses.
   - `CC-BY 3.0: http://creativecommons.org/licenses/cc-by/3.0/`
* - `Copyright`
   - The license associated with this work. The first URL found is checked against our list of supported licenses.
   Used if no license found in the `License` tag.
   - `CC-BY 3.0: http://creativecommons.org/licenses/cc-by/3.0/`
* - `Pictures`
   - The first embedded picture found is used as the album cover.
   -
* - `MusicBrainz Recording ID`
   - The MusicBrainz ID for the recording.
   - `99244237-850b-4a93-904d-57305bcadb4e`
* - `MusicBrainz Album ID`
   - The MusicBrainz ID for the album.
   - `bca982fd-ab73-3c9f-ad07-9104a4f53a32`
* - `MusicBrainz Artist ID`
   -  The MusicBrainz ID for the artist.
   - `b7ffd2af-418f-4be2-bdd1-22f8b48613da`
* - `MusicBrainz Album Artist ID`
   - The MusicBrainz ID for the album artist.
   - `b7ffd2af-418f-4be2-bdd1-22f8b48613da`

```

:::

## Tag content

To tag content using MusicBrainz Picard:

1. Select {guilabel}`Add Files` to add individual files or {guilabel}`Add Folder` to add a directory of files.
2. Select the files or directory you want to tag.
3. Picard shows the files in the left panel. Picard moves files to the right panel as it tags them. If Picard doesn't tag a file automatically, select {guilabel}`Scan`.
4. Check a file's tags by highlighting it and looking at the details in the bottom panel. If Picard has applied the wrong tags, look for [alternative versions](#alternative-versions).
5. Select {guilabel}`Save` or hit {kbd}`ctrl+s` ({kbd}`cmd+s` on macOS) to save the tags to the files.

That's it! You've added ID3 tags to your files. You can now [add these to a library](upload_content.md)

## Alternative versions

Picard will choose tags based on details included in your file. Sometimes it chooses a different version of a release than the one you want. You can choose an alternative version of your content to get the right tags.

### Alternative albums

If Picard has selected a different version of the album you are tagging:

1. Right-click on the album and hover your mouse over {guilabel}`Other versions`. A dropdown list of alternative versions appears.
2. Select the correct release from the list.
3. Select {guilabel}`Save` or hit {kbd}`ctrl+s` ({kbd}`cmd+s` on macOS) to save the tags to the files.

### Alternative tracks

If Picard can't find a release for a track:

1. Right-click on the track and select {guilabel}`Search for Similar Tracks…`. A search screen appears.
2. Search for your track. Use [MusicBrainz's search syntax](https://musicbrainz.org/doc/Indexed_Search_Syntax) for the best results.
3. Select the correct track and click on {guilabel}`Load into Picard`.
4. Select {guilabel}`Save` or hit {kbd}`ctrl+s` ({kbd}`cmd+s` on macOS) to save the tags to the files.

## Add items to MusicBrainz

If Picard can't find your content, you can add it to MusicBrainz yourself. To get started, check out [MusicBrainz's guide](https://musicbrainz.org/doc/How_to_Add_a_Release/).

Once you have added the content to MusicBrainz, Picard can tag your files.
