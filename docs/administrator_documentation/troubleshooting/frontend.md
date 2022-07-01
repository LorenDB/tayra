# Troubleshoot frontend issues

The Funkwhale frontend is a {abbr}`SPA (Single Page Application)` written in [Vue.js](https://vuejs.org). It consumes the Funkwhale API to serve content and to federate with other Fediverse software.

## Tools

The most useful tools for troubleshooting issues with the Funkwhale frontend are your web browser's developer tools. The `Console` and `Network` tabs are particularly useful for tracking down issues in the Javascript code and API responses respectively. Use the following shortcut to open the developer tools for your browser:

| Browser | Shortcut |
| -------- | --------- |
| Google Chrome/Chromium | {kbd}`F12` |
| Microsoft Edge | {kbd}`F12` |
| Opera | {kbd}`F12` |
| Vivaldi | {kbd}`F12` |
| Firefox | {kbd}`F12` |
| Safari | {kbd}`Command+Option+U` |

## Troubleshoot the issue

### Crashes or performance issues

To start troubleshooting your issue, try the following:

1. Open your browser's developer tools.
2. Select the `Console` tab.
3. Open Funkwhale and try to replicate the issue.
4. Take note of any errors or warnings that appear in the `Console` tab.

If applicable, try these steps while logged in and again while logged out to see if there is any difference.

### Content not appearing

If content isn't appearing, it is usually due to one of the following reasons:

1. A conditional statement in the frontend code isn't working.
2. The API is not serving content.

You can confirm which of these is causing the issue by checking the `Network` tab in your browser's developer tools.

1. Open your browser's developer tools.
2. Select the `Network` tab.
3. Open Funkwhale and try to replicate the issue.
4. Take not of any `4XX` or `5XX` responses in the API calls.

If you are receiving `4XX` or `5XX` responses, this means the API isn't serving your content properly. You can investigate further by following the [backend troubleshooting guide](backend.md).

## Get help

If you can't solve the issue yourself, ask the community for help. Check out the [get help](get_help.md) guide for information about where to ask your question and what details to provide.
