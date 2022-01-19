# Follow a channel

Get access to a channel's content by following it. Following a channel makes its content visible to all users on your {term}`pod`.

You can follow channels in a few different ways:

```{contents}
:local:
````

## Follow a channel on your pod

If a user on your pod follows a channel or has published a channel, you can follow it from your pod. To do this:

1. Select the channel you want to follow. The channel details page opens.
2. Select the {guilabel}`Subscribe` button. The label changes to {guilabel}`Subscribed`.

That's it! You've subscribed to the channel. You can see the channel in the {guilabel}`Channels` page.

## Follow a remote channel

To follow a channel located on another pod, you need its __Federation handle__. A __Federation handle__ uses the following format: ``@{username}@{domain}``. Once you have the channel's __Federation handle__, you can follow it from the {guilabel}`Channels` page. To do this:

```{tabbed} Desktop

1. Select {guilabel}`Channels` in the sidebar. The {guilabel}`Channels` page opens.
2. Select {guilabel}`+ Add new` at the top of the page. The {guilabel}`Subscriptions` screen appears.
3. Select {guilabel}`Fediverse`.
4. Enter the channel's __Federation handle__ in the {guilabel}`Fediverse object` input.
5. Select {guilabel}`Subscribe`. The channel details page appears.
6. Select the {guilabel}`Subscribe}` button. The label changes to {guilabel}`Subscribed`.

```

```{tabbed} Mobile

1. Select the hamburger menu ({fa}`bars`) to open the menu bar.
2. Select {guilabel}`Channels`. The {guilabel}`Channels` page opens.
3. Select {guilabel}`+ Add new` at the top of the page. The {guilabel}`Subscriptions` screen appears.
4. Select {guilabel}`Fediverse`.
5. Enter the channel's __Federation handle__ in the {guilabel}`Fediverse object` input.
6. Select {guilabel}`Subscribe`. The channel details page appears.
7. Select the {guilabel}`Subscribe}` button. The label changes to {guilabel}`Subscribed`.

```

That's it! You can now see the channel's content on your pod. Other users of your pod can also see this channel.

## Follow a Funkwhale podcast with a podcatcher

You can follow podcasts published in channels using a standard podcatcher. To do this:

1. Select the channel you want to follow. The channel details page opens.
2. Select the feed button ({fa}`feed`). The {guilabel}`Subscribe to this channel` window appears.
3. Select {guilabel}`Copy` under the {guilabel}`Subscribe via RSS` to copy the channel's {abbr}`RSS (Really Simple Syndication)` feed URL.
4. Paste the URL in your podcatcher.

That's it! Your podcatcher fetches the podcast details from Funkwhale.
