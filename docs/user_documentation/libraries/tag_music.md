# Tag your content with Picard

Funkwhale relies on [ID3 tags](https://id3.org/) to sort audio content. ID3 tags tell Funkwhale information about your files. Funkwhale uses this information to display your content in your {term}`pod`.

We recommend using [MusicBrainz Picard](https://picard.musicbrainz.org/) to tag your content. MusicBrainz Picard is free and open source software that connects to [MusicBrainz](https://musicbrainz.org). Funkwhale uses MusicBrainz as its primary data source.

This guide shows you how to tag your content with MusicBrainz Picard.

```{contents}
:local:
```

```{dropdown} Supported tags

| Name                          | Example value                                               | Description                                                                                                                                                          |
|-------------------------------|-------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `Title`*                      | `Letting you`                                               | The track title.                                                                                                                                                     |
| `Artist`*                     | `Nine Inch Nails`                                           | The artist name.                                                                                                                                                     |
| `Album`                       | `The Slip`                                                  | The album title. If none is provided, an `[Unknown Album]` entry is created.                                                                                         |
| `Album artist`                | `Trent Reznor`                                              | The album artist name (can be different than the track artist).                                                                                                      |
| `Genre`                       | `Industrial, Metal`                                         | A comma separated list of tags to associate with the track.<br><br>Other supported separators: `;` and `/`                                                           |
| `Track number`                | `4`                                                         | The position of the track in the album/release.                                                                                                                      |
| `Disc number`                 | `1`                                                         | The disc number (in case of multi-disc albums).                                                                                                                      |
| `Date`                        | `2019`                                                      | The release date of the track or album.                                                                                                                              |
| `License`                     | `CC-BY 3.0: http://creativecommons.org/licenses/cc-by/3.0/` | The license associated with this work. The first URL found is checked against our list of supported licenses.                                                        |
| `Copyright`                   | `CC-BY 3.0: http://creativecommons.org/licenses/cc-by/3.0/` | The license associated with this work. The first URL found is checked against our list of supported licenses. <br><br>Used if no license found in the `License` tag. |
| `Pictures`                    |                                                             | The first embeded picture found is used as the album cover.                                                                                                          |
| `MusicBrainz Recording ID`    | `99244237-850b-4a93-904d-57305bcadb4e`                      | The MusicBrainz ID for the recording.                                                                                                                                |
| `MusicBrainz Album ID`        | `bca982fd-ab73-3c9f-ad07-9104a4f53a32`                      | The MusicBrainz ID for the album                                                                                                                                     |
| `MusicBrainz Artist ID`       | `b7ffd2af-418f-4be2-bdd1-22f8b48613da`                      | The MusicBrainz ID for the artist                                                                                                                                    |
| `MusicBrainz Album Artist ID` | `b7ffd2af-418f-4be2-bdd1-22f8b48613da`                      | The MusicBrainz ID for the album artist                                                                                                                              |
```

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
