# Multi-artist support

Funkwhale requires all releases and recordings to be associated to an artist. In Funkwhale's current structure, only one artist can be associated with a release or recording. However, many releases and recordings are credited to multiple artists.

Funkwhale supports adding releases with multiple contributors by assigning a generic "Various Artists" artist to collaborative releases. This approach doesn't give proper credit to the contributors, and leads to lots of content being improperly catalogued.

When a user uploads content created by multiple collaborative artists, they expect the following behavior:

1. Releases to which the artist has contributed should be present on the artist's page
2. Releases to which the artist has contributed should be present in search results for the artist
3. Releases and recordings should contain links to all contributing artists so that users can discover their other work

Currently, Funkwhale has no facility to parse multi-artist releases. The metadata fields that hold this information (`ALBUMARTIST` and `ARTIST`) are challenging to parse as they aren't formatted in a consistent way. When a release has multiple contributing artists, Funkwhale needs to be able to parse the following information about each artist to ensure the content is tagged with each artist as a user would expect:

1. Any aliases the contributing artist might use
2. The **join phrase** used to separate artists in the tag

```{toctree}
---
caption: Specifications
maxdepth: 1

---

mb-content
non-mb-content

```
