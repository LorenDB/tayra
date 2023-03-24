# Instance settings

You can find instance settings on your pod's web interface. These settings control high level pod configuration. You don't need to restart the pod after changing these settings.

To find your instance settings:

::::{tab-set}

:::{tab-item} Desktop
:sync: desktop

1. Log in to your {term}`pod`.
2. Select the wrench icon ({fa}`wrench`) at the top of the sidebar to open the {guilabel}`Administration` menu.
3. Select {guilabel}`Settings`. The {guilabel}`Instance settings` page opens.

:::

:::{tab-item} Mobile
:sync: mobile

1. Log in to your {term}`pod`.
2. Select the wrench icon ({fa}`wrench`) at the top of the page to open the {guilabel}`Administration` menu.
3. Select {guilabel}`Settings`. The {guilabel}`Instance settings` page opens.

:::
::::

## Available settings

### Instance information

```{glossary}

Pod name
   The public name of your Funkwhale pod. This is displayed on the "Home" and "About" pages.

Short description
   A short description of your pod. Users see this on the pod's "Home" page.

Long description
   A longer description of your pod. Users see this on the pod's "About" page. Supports markdown formatting.

Contact email
   A contact email address that users and visitors can use to contact the pod administrator.

Rules
   A free text field for you to add your pod's rules and code of conduct. This is seen on the pod's "About" page. Supports markdown formatting

Terms of service
   A free text field for you to add your pod's terms of service and privacy policy. This is seen on the pod's "About" page. Supports markdown formatting.

Banner image
   A large image seen on the pod's "Home" and "About" pages. The image should be at least 600x100px.

Support message
   A short message you can display to your pod's users to ask for support or just send a periodic message. Supports markdown.

```

---

### Sign-ups

```{glossary}

Open registration to new users
   Enable this setting to allow new users to create an account on your pod.

Enable manual sign-up validation
   Enable this setting to require all new registrations to be validated by a moderator.

Sign-up form customization
   Use this tool to create a custom sign-up form. New users see this form when creating a new account. Supports markdown

```

---

### Security

````{glossary}

API Requires authentication
   Controls whether {term}`unauthenticated users <Anonymous>` can access content on your pod. If __enabled__, users need to have an account on your pod to access content. If __disabled__, users without an account can listen to content stored in public libraries.

   ```{seealso}
   {doc}`../../moderator/content/library`.
   ```

Default permissions
   A list of {term}`permissions` that are added to users by default. If your pod is publicly accessible, you should leave this empty.

Upload quota
   The default upload quota for users in MB. You can override this on a per-user basis.

   ```{seealso}
   {doc}`../../moderator/reports/users`
   ```

````

---

### Music

```{glossary}

Transcoding enabled
   Enable this setting to let your server transcode files into a different format if the client requests it. This is useful if a device doesn't support formats like Ogg or FLAC.

Transcoding cache duration
   The number of minutes you want to store transcoded files on your server. Funkwhale removes transcoded tracks that haven't been downloaded within this duration to save space.

```

### Channels

```{glossary}

Enable channels
   Whether user channels can be created and followed on your pod.

Max channels allowed per user
   The maximum number of channels each user can create.

```

---

### Playlists

```{glossary}

Max tracks per playlist
   The maximum number of tracks a user can add to a playlist.

```

---

### Moderation

```{glossary}

Enable allow-listing
   Enable this setting to ensure your pod only communicates with pods you have added to your allow list. When this setting is disabled, your pod will communicate with all other servers not included in your deny list.

Publish your allowed-domains list
   Whether to make your list of allowed domains public. Enable this if you want users to check who you are federating with.

Accountless report categories
   A list of {term}`categories <Report categories>` that {term}`anonymous` users can submit.

```

---

### Federation

```{glossary}

Federation enabled
   Whether to enable federation features on your pod.

Enable public index
   Whether to allow other pods and bots to index public content on your pod.

Federation collection page size
   The number of items to display in ActivityPub collections.

Music cache duration
   The number of minutes you want to store local copies of federated tracks on your server. Funkwhale removes federated tracks that haven't been downloaded within this duration to save space.

Federation actor fetch delay
   The number of minutes the server waits before refetching actors on request authentication.

```

---

### Subsonic

```{glossary}

Enabled Subsonic API
   Whether to enable the Subsonic API. This controls whether users are able to connect to your pod using Subsonic apps.

```

---

### User Interface

```{glossary}

Custom CSS code
   Add CSS rules to control the look and feel of your pod. These rules are added to a `<style>` tag on each page.

Funkwhale Support message
   Whether to show a notification to your pod's users to support the Funkwhale project.

```

---

### Statistics

```{glossary}

Enable usage and library stats in nodeinfo endpoint
   Whether to share anonymized usage and library statistics in your pod's nodeinfo endpoint.

Private mode in nodeinfo

   Enable this setting to indicate you don't want your instance to be tracked by third-party services.

```
