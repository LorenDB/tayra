# Tayra

Tayra is an opinionated Funkwhale client. It is the product of much vibecoding (thanks GitHub for the free Copilot!). This should not be a security issue since Tayra is not a server; however, you are welcome to not use the app if you are offended by this.

## Features

- AMOLED dark theme, all the time.
- A reasonably nice-looking theme that pulls accent colors from album art when possible.
- Year-end reviews a la Spotify Wrapped.
- Download music for offline playback.
- And more!

In fact, Tayra supports most features of the official Funkwhale app (but sometimes slightly buggier).

## Development

I use OpenCode, hence `AGENTS.md` for agent instructions. If you use e.g. Claude Code, you could probably just symlink `AGENTS.md` to `CLAUDE.md`. Or you could use your own brain as the agent. I really don't care, nor do I expect that anyone will care enough to contribute anyway.

The Funkwhale API `schema.yml` is cached in the repo root so agents can refer to it when building against the API.

To build the app locally:

1. Install Flutter (stable) and required Android SDK components. See https://docs.flutter.dev.
2. `flutter run`

You probably should run `dart format .` before committing, but it isn't a huge deal IMO.
