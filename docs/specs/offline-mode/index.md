# Offline mode support

## The issue

As raised in [#2039](https://dev.funkwhale.audio/funkwhale/funkwhale/-/issues/2039), Funkwhale's features don't work well if the device goes offline in the middle of an action such as playing a radio session. As we look forward to improving our PWA offering, we need to anticipate offline/low connectivity situations and handle these gracefully.

## Proposed solution

We need to provide solutions to the user experience problems that arise when a device goes offline. This will mostly be achieved by improving our service worker implementation and adding some catches that ease the process of coming back online after an outage.

## Feature behavior

### Offline detection

The first thing the app needs to be able to do is detect when it has gone offline. Browsers offer [built-in support](https://developer.mozilla.org/en-US/docs/Web/API/Navigator/onLine) for this which we can leverage. When the device goes offline, we need to meaningfully communicate this to the user and explain exactly what this means:

1. The user will not be able to play content
2. The user will not be able to search for content
3. The user will not be able to navigate to other pages

### UX/UI communication

To ensure that users don't get frustrated by non-interactive elements, the app should be **disabled** when in an offline state. This should be clearly communicated to users in the following ways:

1. All interactive elements should be visibly disabled and their aria-status updated to inform users that no actions are possible.
2. A prominent banner should inform users that their device is offline and that most actions are not possible until connectivity returns.

### Offline behavior

When the device goes offline, the app should do the following:

1. If a radio is playing, **store** the state of the radio
2. The player needs to stop attempting to load the next track and should simply stop at the end of the last fully-loaded track
3. If the player has not finished loading the currently playing track, it should halt playback and **store** the playback position
4. Cache textual information such as the instance description so that users can still see

### Reconnecting

When the device comes back online, the app should do the following:

1. If a radio session is stored, **resume** the radio session
2. If the app uses an S3-compatible storage backend, it should request a refreshed token to ensure the track data and media information can be fetched properly for existing queue items

## Open questions

- Can we cache any other content that would improve the user experience?
- What information do we need to convey to users when the device goes offline?

## Minimum viable product

The MVP should aim to address the linked issue specifically:

1. It should **detect** when the connection is lost
2. It should store the playing radio's state
3. It should **detect** when the connection is resumed
4. It should resume the radio session without disruption
