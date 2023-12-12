# Multi-artist support for non-MusicBrainz-tagged content

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

To account for content tagged in tagged in systems **other than MusicBrainz**, a `parse_credit` strategy should be used to parse artist credit from a file's metadata using join phrase parsing.

## Feature behavior

The workflow for `ArtistCredit` population goes as follows:

```{mermaid}
flowchart TD
    upload([The user uploads content to Funkwhale])
    upload --> read(Funkwhale reads the file tags of each release/recording)
    read --> mb-tagged{Does the content have a MusicBrainz ID?}
    mb-tagged -->|no| parse(Funkwhale parses the artists tag\nand splits the artist at any tokens\n in the join phrase list)
    parse --> artist(Funkwhale creates Artist entries for any\nartists that aren't present in the database)
    artist --> model(Funkwhale stores the <code>artist_credit</code> information\nfor each release/recording)
    model --> display([Funkwhale displays the credit for each release/recording\nin the web app/API representation])
```

### Backend

The backend is responsible for

1. Tokenizing artist tags in the file's metadata and creating `Artist` entries for new artists
2. Creating `ArtistCredit` entries for each **unique** combination of `artist_id`, `credit`, and `joinphrase`
3. Adding the `ArtistCredit` links to `Track` and `Album` entries

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
    ArtistCredit ->> parse_credit: Parse credit from tags
    parse_credit -->> ArtistCredit: Return credit information
```

Funkwhale should provide the following to enable artist parsing in non-MusicBrainz-tagged content:

1. A sensible list of default **join phrases** that are commonly found in artist tags
2. A setting to enable admins to override or add to the list of join phrases

Funkwhale should tokenize the `ALBUMARTIST` and `ARTIST` fields using a list of **join phrases**. For each token in the list, Funkwhale should do the following:

1. Store content split at the **join phrase** token as the `credit`
2. Search for any artist with the same name as the `credit` and store the id as the `artist_id`
   - If no existing artist is found, create a new artist and return the ID as `artist_id`
3. Store the join phrase token that it split at as the `joinphrase`
4. Create an `ArtistCredit` object for each **unique** combination of `artist_id`, `credit`, and `joinphrase`
5. If a matching `ArtistCredit` entry is found, Funkwhale should link to this

```{mermaid}
sequenceDiagram
    Upload ->> parse_content: Read file metadata
    loop For each artist name
        parse_content ->> Artist: Search Artist entries
        Artist -->> parse_content: Return entry (if exists)
        parse_content ->> Artist: Create Artist entry (if none found)
    end
    loop For each unique artist credit combination
        parse_content ->> ArtistCredit: Search ArtistCredit entries
        ArtistCredit -->> parse_content: Return entry (if exists)
        parse_content ->> ArtistCredit: Create ArtistCredit entry (if none found)
        parse_content ->> Track: Create Track with artist_credit entries
        parse_content ->> Album: Create Album with artist_credit entries
    end
```

Funkwhale should do the following automatically:

- Trim whitespace from the artist `credit`
- Preserve whitespace around **both sides** of the `joinphrase` for readability
- Use an **empty** string (`""`) as the `joinphrase` for the last entry in the list

For example, given a list of join phrases like this:

- `$`, `|`, `&`, `/`, `feat.`

And the following tags:

| Tag         | Values                                                  |
| ----------- | ------------------------------------------------------- |
| ALBUMARTIST | Tommy J. & Bobby Forth                                  |
| ARTIST      | Tommy J. feat. Robin Devil, Jerry Sabbath & Sammy Burns |

Funkwhale would create the following `ArtistCredit` entries for the `Album`:

| id  | artist_id | credit      | joinphrase |
| --- | --------- | ----------- | ---------- |
| 1   | 1         | Tommy J.    | &          |
| 2   | 2         | Bobby Forth |            |

And the following for the `Track`:

| id  | artist_id | credit        | joinphrase |
| --- | --------- | ------------- | ---------- |
| 3   | 1         | Tommy J.      | " feat. "  |
| 4   | 3         | Robin Devil   | ", "       |
| 5   | 4         | Jerry Sabbath | " & "      |
| 6   | 5         | Sammy Burns   | ""         |

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

To prevent issues with tagging, the user should be presented a summary of artist credits that are separated using the `parse_credit` strategy.

Once the upload has been processed by the server, the user should be shown a summary of the uploaded content with artists listed against each recording and release. The user should then be able to amend these results and send a request to update the values. Upon receiving a new value, the server should perform the same deduplication it performs during a new upload.

1. The user uploads new content to Funkwhale
2. Funkwhale parses the artist credits and saves the new credit objects in case the upload is interrupted
3. Funkwhale displays a summary of the changes
   1. If the results are **correct**, the user accepts the changes and finishes the upload
   2. If the results are **incorrect**, the user modifies the artist credits and submits the changes

```{mermaid}
flowchart TD
    upload([The user uploads content to Funkwhale])
    upload --> read(Funkwhale reads the file tags of each release/recording)
    read --> parse(Funkwhale parses the artists tag\nand splits the artist at any tokens\n in the join phrase list)
    parse --> artist(Funkwhale creates Artist entries for any\nartists that aren't present in the database)
    artist --> model(Funkwhale stores the artist_credit information\nfor each release/recording)
    model --> verify(Funkwhale displays the results to the user)
    verify --> correct{Are the artist tags correct?}
    correct -->|no| tweak(The user corrects the details and\nsubmits the new information to Funkwhale)
    tweak & correct -->|yes| finish(The user finishes the upload process)
```

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
  - Creating a workflow to enable users to verify uploaded data and fix any broken artist credits
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
3. Implement the token splitting and data fetching for new files

### Next steps

1. Create a `manage.py` script that enables admins to update entries in the database
2. Create a task that updates files imported in-place
