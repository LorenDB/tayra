# Contribute to the frontend

The Funkwhale frontend is a {abbr}`SPA (Single Page Application)` written in [Typescript](https://typescriptlang.org) and [Vue.js](https://vuejs.org).

## Styles

We currently use [Fomantic UI](https://fomantic-ui.com) as our UI framework. We customize this with our own SCSS files located in `front/src/styles/_main.scss`.

We apply changes to the Fomantic CSS files before we import them:

1. We replace hardcoded color values with CSS variables to make themin easier. For example: `color: orange` is replaced by `color: var(--vibrant-color)`
2. We remove unused values from the CSS files to keep the size down

These changes are applied when you run `yarn install` through a `postinstall` hook. If you want to modify these changes, check the `front/scripts/fix-fomantic-css.py` script.

We plan to replace Fomantic with our own UI framework in the near future. Check our [Penpot](https://design.funkwhale.audio) to see what we've got planned.

## Components

Our [component library](https://ui.funkwhale.audio) contains reusable Vue components that you can add to the Funkwhale frontend. If you want to add a new component, check out [the repository](https://dev.funkwhale.audio/funkwhale/vui).

## Testing

The Funkwhale frontend contains some tests to catch errors before changes go live. The coverage is still fairly low, so we welcome any contributions.

To run the test suite, run the following command:

```sh
sudo docker compose -f dev.yml run --rm front yarn test:unit
```

To run tests as you make changes, launch the test suite with the `-w` flag:

```sh
sudo docker compose -f dev.yml run --rm front yarn test:unit -w
```
