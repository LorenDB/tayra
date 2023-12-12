# Multi-artist support for MusicBrainz-tagged content

## Terminology

The following terminology is used throughout this spec:

Join phrase
: The token used to split a list of artists and represent their role in content

Release
: An **album** or **single**. In Funkwhale a release is represented by the `Album` model

Recording
: A single track as part of an **album** or **single**. In Funkwhale, a recording is represented by the `Track` model

## Proposed solution

To support multi-artist content, a new `ArtistCredit` model should be added to house contributing artist information, including links to `Artist` models and details about credited names and join phrases. The `ArtistCredit` model should link to `Album` and `Track` entries using a `ForeignKey` relationship to allow multiple `artist_credit` entries on each `Album` and `Track`. The existing `artist` field in `Album` and `Track` models is deprecated in favor of the new `artist_credit` field.

A `fetch_credit` strategy should be used to fetch artist credit directly from MusicBrainz's entry for releases and recordings.

## Feature behavior

The workflow for `ArtistCredit` population goes as follows:

```{mermaid}
flowchart TD
    upload([The user uploads content to Funkwhale])
    upload --> read(Funkwhale reads the file tags of each release/recording)
    read --> mb-tagged{Does the content have a MusicBrainz ID?}
    mb-tagged -->|yes| query(Funkwhale queries the MusicBrainz API to\nretrieve artist information for each\nunique mbid)
    query --> create(Funkwhale fetches artist information\nand creates Artist entries for any\nartists not present in the database)
    create --> model(Funkwhale stores the artist_credit information\nfor each release/recording)
    model --> display([Funkwhale displays the credit for each release/recording\nin the web app/API representation])
```

### Backend

The backend is responsible for

1. Tokenizing artist tags when a MusicBrainz ID **isn't** present in the file metadata and creating `Artist` entries for new artists
2. Querying the MusicBrainz API when a MusicBrainz ID **is** present and creating `Artist` entries for new artists
3. Creating `ArtistCredit` entries for each **unique** combination of `artist_id`, `credit`, and `joinphrase`
4. Adding the `ArtistCredit` links to `Track` and `Album` entries

The `artist_credit` entries must be linked sequentially to preserve ordering. For each entry, Funkwhale should query for an existing `ArtistCredit` entry and return it if found, or create a new one and return the new entry. This ensures that artist credit information is presented in the same order as in the tags.

#### Data model

A new `ArtistCredit` model needs to hold the contributing artist information. This model contains the following fields:

- The Funkwhale `artist_id` of the artist associated with the release or recording
- The `credit` representing the credited name of the artist as given for the release or recording
- The `joinphrase` associated with the artist (for example: `" feat. "`, `" & "`)

```{mermaid}
classDiagram
    direction LR
    class Album {
        String title
        ArtistCredit artist_credit
        Date release_date
        String release_group_id
        Attachment attachment_cover
        String type
        Actor attributed_to
        TaggedItem tagged_items
        Fetch fetches
        Content description
        List api_includes
        String api
        String federation_namespace
        MusicBrainz musicbrainz_model
        String musicbrainz_mapping
    }
    class Track {
        UUID mbid
        String title
        ArtistCredit artist_credit
        Integer disc_number
        Integer position
        Album album
        License license
        Actor attributed_to
        String copyright
        Attachment attachment_cover
        Integer downloads_count
        String federation_namespace
        String musicbrainz_model
        String api
        List api_includes
        MusicBrainz musicbrainz_mapping
        String import_hooks
        QuerySet objects
        Fetch fetches
    }
    class Artist {
        String name
        String federation_namespace
        String musicbrainz_model
        Object musicbrainz_mapping
        Actor attributed_to
        TaggedItem tagged_items
        Fetch fetches
        Content description
        Attachment attachment_cover
        String content_category
        Date modification_date
        String api
        QuerySet objects
    }
    class ArtistCredit {
        Artist artist_id
        String credit
        String joinphrase
    }
    Track "1" --> Album : album
    Track "1..*" --> ArtistCredit : artist_credit
    Album "1..*" --> ArtistCredit : artist_credit
    ArtistCredit "1" --> Artist : Artist
```

#### Workflow

On the backend, the workflow for fetching `ArtistCredit` information is as follows:

```{mermaid}
sequenceDiagram
    ArtistCredit ->> fetch_credit: Fetch credit from MusicBrainz
    fetch_credit -->> ArtistCredit: Return credit information from MusicBrainz
```

If MusicBrainz tags are present in the file metadata, the `fetch_credit` strategy should always be preferred to ensure that content aligns with MusicBrainz's tagging.

To maintain compatibility with MusicBrainz and ensure that Funkwhale can parse multi-artist releases, the MusicBrainz API should be used to fetch contributor information relating to the release.

The [`/release` and `/recording` endpoints](https://musicbrainz.org/doc/MusicBrainz_API#Lookups) return `artist-credit` information when called with a `inc=artists` parameter. This information can be parsed to fetch relevant information:

- The `joinphrase`
- The MusicBrainz `id` of the `artist`
- The artist's `name`

```text
https://musicbrainz.org/ws/2/release/ef140c88-8bf1-4e50-9555-5c1d1ed5865c?fmt=json&inc=artists
```

```json
{
  "asin": null,
  "cover-art-archive": {
    "darkened": false,
    "artwork": true,
    "front": true,
    "back": false,
    "count": 1
  },
  "release-events": [
    {
      "area": {
        "id": "525d4e18-3d00-31b9-a58b-a146a916de8f",
        "type": null,
        "name": "[Worldwide]",
        "disambiguation": "",
        "sort-name": "[Worldwide]",
        "iso-3166-1-codes": ["XW"],
        "type-id": null
      },
      "date": "2012-11-15"
    }
  ],
  "quality": "normal",
  "barcode": "",
  "date": "2012-11-15",
  "status-id": "4e304316-386d-3409-af2e-78857eec5cfe",
  "status": "Official",
  "title": "One Christmas at a Time",
  "disambiguation": "",
  "text-representation": {
    "script": "Latn",
    "language": "eng"
  },
  "packaging-id": "119eba76-b343-3e02-a292-f0f00644bb9b",
  "packaging": "None",
  "country": "XW",
  "id": "ef140c88-8bf1-4e50-9555-5c1d1ed5865c",
  "artist-credit": [
    {
      "joinphrase": " & ",
      "name": "Jonathan Coulton",
      "artist": {
        "type-id": "b6e035f4-3ce9-331c-97df-83397230b0df",
        "name": "Jonathan Coulton",
        "id": "d8df7087-06d5-4545-9024-831bb8558ad1",
        "sort-name": "Coulton, Jonathan",
        "disambiguation": "",
        "type": "Person"
      }
    },
    {
      "artist": {
        "type": "Person",
        "disambiguation": "",
        "id": "7b5b87d3-f3ee-4b5d-b111-1f2e87f87124",
        "sort-name": "Roderick, John",
        "name": "John Roderick",
        "type-id": "b6e035f4-3ce9-331c-97df-83397230b0df"
      },
      "name": "John Roderick",
      "joinphrase": ""
    }
  ]
}
```

To catalogue multi-artist content, Funkwhale needs to:

1. Fetch information for **each** contributing artist and create `Artist` objects for any that don't exist
2. Create `ArtistCredit` objects associated with each release and recording for each **unique** combination of `artist_id`, `credit`, and `joinphrase`
3. If a matching `ArtistCredit` entry is found, Funkwhale should link to this

```{mermaid}
sequenceDiagram
    Funkwhale ->> MusicBrainz: /release/{mbid}?fmt=json&inc=artists
    MusicBrainz -->> Funkwhale: Album and ArtistCredit information
    Funkwhale ->> MusicBrainz: /recording/{mbid}?fmt=json&inc=artists
    MusicBrainz -->> Funkwhale: Track and ArtistCredit information
    loop For each unique artist mbid
        Funkwhale ->> MusicBrainz: /artist/{mbid}?fmt=json&inc=aliases
        MusicBrainz -->> Funkwhale: Artist information
    end
```

Given the above example, Funkwhale would create the following `ArtistCredit` object:

| id  | artist_id | credit           | joinphrase |
| --- | --------- | ---------------- | ---------- |
| 1   | 1         | Jonathan Coulton | &          |
| 2   | 2         | John Roderick    |            |

#### API behavior

The Funkwhale API needs to return artist credit information in a way that is easily consumed by a client.

Endpoints should include a `credited_artist` filter that allows a client to return results for which artists are credited. This filter should take a list of IDs.

To return any albums where the artist is listed in the `artist_credit` field, you can filter by the `artist_id` field using the `credited_artist` filter:

```text
https://open.audio/api/v2/albums?credited_artist=6451,6452
```

The `credit` field of the `artist_credit` object must also be searchable using a standard query:

```text
https://tanukitunes.com/api/v2/albums?q=jonathan+coulton
```

#### Migration

To ensure all content has `artist_credit` information, an initial migration should copy the current artist information into an `ArtistCredit` object for each Album and Track with the following mapping:

- `artist_id` = Artist `id`
- `credit` = Artist `name`
- `joinphrase` = `""`

Each album/track must have at least one `artist_credit` entry listed against it.

### Frontend

Data needs to be clearly presented in the web app to ensure that users can easily see which artists collaborated on a work and discover more of their work.

#### Representation in releases and tracks

The frontend should use the `artist_credit` field to populate artist links on releases and tracks. Credited names and join phrases must be preserved to line up with the artists' intent.

The frontend should format the results as follows for **each** artist:

```html
<span>
  <a href="{funkwhale_url}/library/artists/{artist_id}">{credit}</a>{joinphrase}
</span>
```

For example, given the following `artist_credit` response:

```json
[
  {
    "artist_id": 25,
    "credit": "Jonathan Coulton",
    "joinphrase": " & "
  },
  {
    "artist_id": 395,
    "credit": "John Roderick",
    "joinphrase": ""
  }
]
```

The frontend would render the following:

```html
<span>
  <a href="https://open.audio/library/artists/25">Jonathan Coulton</a> &
  <a href="https://open.audio/library/artists/395">John Roderick</a>
</span>
```

#### "Also appears in" section

To keep artist discographies properly catalogued, only albums attributed to the artist, not albums with tracks featuring the artist, should appear in the "Albums by" section of the artist page.

Releases to which the artist has contributed should be separated into a new section labeled "Also appears in". This ensures that it is easy to discover content to which an artist has contributed while also prioritizing their own content on the artist page.

#### "Compilations" page

The "Various Artists" artist is a special artist used in MusicBrainz to catalogue compilation content not attributed primarily to a specific artist or artists. This artist is widely used in Funkwhale as the Album Artist tag for compilation content. To preserve this content and make compilation content easier to find, we should create a special "Compilations" page to house compilation content.

### Documentation

The following needs to be documented:

- The artist splitting mechanism. Meaningful examples should be provided to help users tag their content
- The environment setting to override the join phrase list
- Any tasks or script functions which are created to automate the update of historical content

## Availability

- [ ] Admin panel
- [x] App frontend
- [ ] CLI

## Responsible parties

- The backend developers in the **Development** group are responsible for:
  - Creating the new `ArtistCredit` model
  - Updating the `Album` and `Track` models to link to `ArtistCredit` entries
  - Creating the strategies for populating `ArtistCredit` during the upload process
  - Updating the API/creating new endpoints
  - Creating the database migration to add the new field and that artist information is copied over
- The frontend developers in the **Development** group are responsible for:
  - Updating the artist representations in the Album and Track pages to use the new `artist_credit` field in the API response
  - Creating the new "Also appears in" section for the artist discography pages
- The **Design** group is responsible for:
  - Providing designs for how multi-artist content should be rendered responsively
  - Providing designs for the new "Compilations" page
  - Providing designs for the updated Artist page
- The **Documentation** group is responsible for:
  - Documenting the new feature behavior
  - Documenting the new environment settings
  - Providing docstrings for API development

## Open questions

- What should be used as the default join words list?
- To maintain compatibility with API v1, should we continue to populate the `artist` tag on `Track` and `Album` entries with the first credited artist?

## Minimum viable product

The MVP for this product is an implementation of the backend behavior. It should:

1. Set up the new models
2. Create the database migration

### Next steps

1. Create a `manage.py` script that enables admins to update entries in the database
2. Create a task that updates files imported in-place
