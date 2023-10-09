# Collections

## The issue

One of Funkwhale's primary use-cases is content management. Users expect to be able to upload, manage, and share their content easily using the Funkwhale web app or other apps that use the Funkwhale API.

We have identified the following key focus areas:

1. Users need to be able to share content easily
2. Users need to be able to follow collections of content easily
3. Users should have the option to upload content **without** needing to organize it explicitly
4. Users need to be able to easily move content between different collections
5. Users need to be able to assign content to multiple collections
6. Users need to be able to see all of their content and how it is organized within apps

## Proposed solution

To address the issues above we propose a new management solution called **Collections**. The rationale behind this solution can be found in our conversations [in the forum](https://forum.funkwhale.audio/d/214-whats-wrong-with-libraries-and-a-path-to-fix-them) and [online meeting notes](https://pad.funkwhale.audio/zs-SKbVgROapjv56lsWWtw?view).

A collection is conceptually a container of content. Users can associate content with multiple collections and share collections with other users. When a user follows a collection, they have access to its content.

Collections resolve the following issues:

1. Users can organize their content exactly how they want to
2. Users can associate content to multiple collections or no collections at all
3. Users can share individual objects (tracks, albums, artists, playlists) using **sharing links**
4. Users can easily view all collections they have created and followed

This specification outlines the behaviors and workflows used in collections.

## Terminology

**Collections** enable users to group content **they have uploaded**. Users can create as many collections as they want and can share collections with other users. Users cannot add remote content to their own collections as this content may be revoked by other users and this would break the user experience.

The **library** is the container that holds all content a user has access to. This includes all content the user uploads and follows. The library can contain as many **collections** as the user wants to create.

## Information architecture

This [diagram](https://design.funkwhale.audio/#/view/e3a187f0-0f5e-11ed-adb9-fff9e854a67c?page-id=f4f2aac0-0f5e-11ed-adb9-fff9e854a67c&section=interactions&index=0&share-id=4a268010-5164-11ed-b91a-c19cdb5a453b) demonstrates how the user's content library is organized on a conceptual level.

## Feature behavior

When a user uploads new content to Funkwhale, the uploaded file is associated to track, album, and artist metadata. The upload is associated to an automatically created upload collection that is invisible to the user. The user can select individual items or a list of items and assign them to one or more collections.

In addition to user collections, we propose the following **automatic** collections:

Uploaded content
: A collection containing all content the user uploads

Followed content
: A collection containing all content the user has followed in external collections

Private content
: A collection containing all content the user has not shared with anyone

Public content
: A collection containing all content the user has shared publicly

Favorites
: A collection containing all content the user has favorited

These collections are managed by Funkwhale and can't be modified directly by the user. The user can use these collections get an overview of what content is local and what is being shared.

### Backend

A collection is stored as a model in the database. This model contains the relevant identifying information for the collection, including:

- The name
- The UUID
- The owning actor
- The visibility level

Uploaded items can be linked to collections using a `ManytoMany` relationship.

```{mermaid}
classDiagram
  class Upload {
    -file : URI
    -ManytoMany : Collections
  }
  class Collection 1{
    -id : UUID
    -name : String
    -visibility : Enum<String>
    -owner : Actor
  }
  class Collection 2{
    -id : UUID
    -name : String
    -visibility : Enum<String>
    -owner : Actor
  }
  class Collection 3{
    -id : UUID
    -name : String
    -visibility : Enum<String>
    -owner : Actor
  }
  class Actor 1{
    -fid : URI
    -id : UUID
    -name: String
  }
  class Actor 2{
    -fid : URI
    -id : UUID
    -name: String
  }
  Upload -- Collection 1 : Optional
  Upload -- Collection 2 : Optional
  Upload -- Collection 3 : Optional
  Collection 1 -- Actor 1 : Required
  Collection 2 -- Actor 1 : Required
  Collection 3 -- Actor 2 : Required
```

#### API Endpoints

Funkwhale-compatible apps can communicate with the Funkwhale API to retrieve and modify collection data. The following actions must be facilitated by API endpoints:

- Create a new collection
- Delete a collection
- Modify a collection's details (description, name, visibility level)
- Add uploads to a collection
- Remove uploads from a collection
- List collections
- List content contained in collections

#### Sharing mechanism

Users must be able to share collections with other users using sharing links. Access to content contained within the collection must be restricted to users who have the link.

Users must be able to share any objects they want to (tracks, albums, artists, playlists). On the backend, this mechanism should do the following:

1. Create a new collection
2. Associate the selected content to the collection
3. Return the sharing link for the collection

This collection should not be visible to the end user.

### Frontend

In the frontend, the user has the ability to create, modify, and delete collections stored in their library. The user can assign content to collections during the upload process or by using the object's **context menu** after upload.

When the user adds a containing object such as an artist discography, album, or playlist, all tracks **currently associated** with the object are added. The collection does not update if new content is associated to the object.

#### Viewing collections

The content of each collection can be viewed in a **Collection page**. This page offers an overview of content in the collection, organized by content type (track, album, artist, playlist). This page can be used to highlight content such as recently favorited tracks or a variable random selection.

Users can see all of their collections in the **User library page**. This page clearly shows users all of their collections as well as information such whether the collections are shared or private.

## Workflows

In this section we detail the workflows behind some of the actions users are able to take using collections.

### Uploading content

The user should be able to choose exactly where their content should go **during the upload process**. They should be able to choose to associate the upload with multiple collections or no collections. This process is outlined in the flowchart below:

```{mermaid}
flowchart TD
   user[Authenticated user] --> upload[Select upload button]
   upload --> destination{Is the destination \nalready selected?} --> |no| select[User chooses collections\nor library]
   destination --> |yes| choose[User chooses the\nfiles to upload]
   select --> choose
   choose --> verify[Funkwhale verifies\nmetada] --> correct{Is the metadata\nvalid?} --> |no| edit[User edits metadata\nin Picard] --> verify
   correct --> |yes| finish([Upload completes])
```

### Deleting content

Users must be able to delete content from their own library easily at any time. Deleting the uploaded content must remove it from any associated collections.

### Creating a collection

The user should be able to create a collection in one of two ways:

1. By selecting a page that contains collections and selecting the "Add collection" option
2. By selecting the "Create new collection" from an object's context menu

In each case, the user should be given a form to fill out with information including:

- The collection name
- The collection description
- The collection's visibility level

### Deleting a collection

If a user decides to delete a collection it **must not** delete the content contained in the collection. When the user selects delete a warning must communicate the following:

- The collection will no longer be available in the user library page or search results
- Users with whom the collection is currently shared will lose access to the collection's content

### Adding content to a collection

Users should be able to select collections during the upload process to add the content immediately.

Users should also be able to select an object's context menu and choose collections from the "Organize and share" submenu. Upon ticking the checkbox, an API call should fire to associate the upload(s) with the collection(s).

### Removing content from a collection

Users should be able to remove content from collections by visiting the collection's page, selecting the items, and selecting "Remove from collection".

Users should also be able to select an object's context menu and choose collections from the "Organize and share" submenu. Upon deselecting the checkbox, an API call should fire to break the association between the upload(s) and the collection(s).

### Sharing a collection

Users must be able to assign a visibility level to their collections. This brokers access to the content for other users and is split up as follows:

- "Private": only the owner and direct followers can access the content. Followers require explicit approval from the owner to access content
- "Local": only the owner and authenticated users on the same domain can access the content
- "Public": any user can access the content

When a user follows a collection, the collection and its content are accessible in all parts of the library interface.

Following a **Private** collection uses the following flow:

1. The **owner** selects the **recipient** they want to share with
2. Funkwhale sends the **recipient** a follow URL for the collection
3. The **recipient** pastes the URL into the search bar and selects **Request to follow collection**
4. The **owner** can then **approve** or **deny** the follow request
5. The **recipient** can only access the collection's content if the **owner** approves the follow

### Unsharing a collection

Users must be able to revoke sharing for collections. Once a collection is unshared, the content must not be accessible to past recipients.

The process for this changes based on the visibility level of the collection:

- If the user wants to unshare a **Public** collection, they can change the visibility level to **Private** or **Local**
- If the user wants to unshare a **Local** collection, they can change the visibility level to **Private**
- If the user wants to unshare a **Private** collection, they must be able to select the recipient with whom they shared the collection and **invalidate** their sharing URL. When the user's server receives this invalidation request, the content must be made unavailable to the user

When a user revokes collection access, the metadata entry for the content remains in the recipient's library but is **disabled**. The UI should display a message informing the recipient that they no longer have access to the containing collection. The recipient can hide or remove the metadata entry by selecting "Forget" from the entry's content menu.

### Following collections

Users must be able to follow remote content and collections so that the content appears in their library. This content must be clearly marked as external and should not contain the option to add to user collections.

### Unfollowing collections

Users must be able to unfollow collections by visiting the collection's page and selecting "Unfollow". The content in the collection should not be accessible to the user after they unfollow the collection.

## Availability

- [ ] Admin panel
- [x] App frontend
- [x] CLI

## Responsible parties

- Backend group:
    - Create new models and API endpoints to support collections
    - Formulate a migration path for existing libraries
    - Create a compatibility layer for calls between pods with **collections** and pods with **libraries**
- Design group: Create designs for the different ares of the app in which collections are to be shown:
    - Search results
    - The collection page
    - The user library page
    - Sharing menus for content
- Documentation group:
    - Create UX copy for all designs (in collaboration with design group)
    - Document the behavior of collections for end users
    - Document the behavior of collections for admins
    - Document the structure of the data/API for developers
- Frontend group:
    - Create new collection page in line with designs
    - Create new user library page in line with designs
    - Update search results page to show collections
    - Add new context menus for collection management

## Open questions

- Terminology: Does “following” a collection make sense? Would “add to library” be better?

## Minimum viable product

On the backend, we must:

1. Create the new models for collections
2. Create endpoints to satisfy the requirements laid out in the feature behavior section
3. Create a migration path and demonstrate successful migration of libraries to collections
4. Create a translation layer between APIv1 library APIs and APIv2 collection APIs

On the frontend, we must:

1. Update the user profile page to show the user's collections
2. Update the user's library page to show the user's collections
3. Create the new collection page with separate tabs for artists, albums, playlists, and tracks
4. Add collection management options to the upload form
5. Add collection management options to the object context menus

Mockups for these pages [are available here](https://dev.funkwhale.audio/funkwhale/funkwhale-design/-/raw/master/specs/collections%20-%20user%20profile.pdf)

The MVP must allow users to perform the following actions:

- Add or delete content from their library
- Create and delete collections
- Add content to and remove content from collections
- Share and unshare collections

### Next steps

After the core mechanics are implemented, we can add the following to the frontend:

- User library page: Automatic collections
- Collection page: overview tab
- Replace user favorites page with a browsable collection
