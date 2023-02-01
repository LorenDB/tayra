# Update UI copy

```{note}
Funkwhale is localized into several languages using [Weblate](https://translate.funkwhale.audio). You must make sure that any frontend strings are properly marked for localization. We use the [vue-i18n package](https://kazupon.github.io/vue-i18n/) to handle translation of frontend files.
```

All UI strings are stored in `front/locales/en.json` file. The file is structured to mimic the format of the repository. Each string should be labeled following the semantic naming for the item it applies to.

UI strings can be added to both the `<script>` and `<template>` part of a Vue file using following syntax:

::::{tab-set}

:::{tab-item} Locale file

```json
{
  "components": {
    "About": {
      "title": "About",
      "header": {
        "funkwhale": "A social platform to enjoy and share music"
      },
      "button": {
        "cancel": "Cancel"
      }
    }
  }
}
```

:::

:::{tab-item} Script

```typescript
import { useI18n } from "vue-i18n";
//...
const { t } = useI18n();
//...
const labels = computed(() => ({
  title: t("components.About.title"),
}));
```

:::

:::{tab-item} Template

```html
<h2>{{ $t('components.About.header.funkwhale') }}</h2>
<button>{{ $t('components.About.button.cancel') }}</button>
```

:::

::::

Some strings change depending on whether they are plural or not. You can create plural strings using the [vue-i18n pluralization syntax](https://kazupon.github.io/vue-i18n/guide/pluralization.html)

::::{tab-set}

:::{tab-item} Locale file

```json
"components": {
    "audio": {
        "ChannelCard": {
            "meta": {
                "episodes": "No episodes | {episode_count} episode | {episode_count} episodes",
                "tracks": "No tracks | {tracks_count} track | {tracks_count} tracks"
            }
        }
    }
}
```

:::

:::{tab-item} Template

```html
<div class="description">
  <span
    v-if="object.artist?.content_category === 'podcast'"
    class="meta ellipsis"
  >
    {{ $t('components.audio.ChannelCard.meta.episodes', {episode_count:
    object.artist.tracks_count}) }}
  </span>
  <span v-else>
    {{ $t('components.audio.ChannelCard.meta.tracks', {tracks_count:
    object.artist?.tracks_count}) }}
  </span>
  <tags-list
    label-classes="tiny"
    :truncate-size="20"
    :limit="2"
    :show-more="false"
    :tags="object.artist?.tags ?? []"
  />
</div>
```

:::

::::
