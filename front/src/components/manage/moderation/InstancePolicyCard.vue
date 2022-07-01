<template>
  <div>
    <slot />
    <p>
      <i class="clock outline icon" /><human-date :date="object.creation_date" /> &nbsp;
      <i class="user icon" />{{ object.actor }}  &nbsp;
      <template v-if="object.is_active">
        <i class="play icon" />
        <translate translate-context="*/*/*/State of feature">
          Enabled
        </translate>
      </template>
      <template v-if="!object.is_active">
        <i class="pause icon" />
        <translate translate-context="Content/Moderation/Card.List item">
          Paused
        </translate>
      </template>
    </p>
    <div>
      <p><strong><translate translate-context="Content/Moderation/Card.Title/Noun">Rule</translate></strong></p>
      <p v-if="object.block_all">
        <i class="ban icon" />
        <translate translate-context="Content/Moderation/*/Verb">
          Block everything
        </translate>
      </p>
      <div
        v-else
        class="ui list"
      >
        <div
          v-if="object.silence_activity"
          class="ui item"
        >
          <i class="feed icon" />
          <div class="content">
            <translate translate-context="Content/Moderation/*/Verb">
              Mute activity
            </translate>
          </div>
        </div>
        <div
          v-if="object.silence_notifications"
          class="ui item"
        >
          <i class="bell icon" />
          <div class="content">
            <translate translate-context="Content/Moderation/*/Verb">
              Mute notifications
            </translate>
          </div>
        </div>
        <div
          v-if="object.reject_media"
          class="ui item"
        >
          <i class="file icon" />
          <div class="content">
            <translate translate-context="Content/Moderation/*/Verb">
              Reject media
            </translate>
          </div>
        </div>
      </div>
    </div>
    <div v-if="markdown && object.summary">
      <div class="ui hidden divider" />
      <p><strong><translate translate-context="Content/Moderation/*/Noun">Reason</translate></strong></p>
      <sanitized-html :html="markdown.makeHtml(object.summary)" />
    </div>
    <div class="ui hidden divider" />
    <button
      class="ui right floated labeled icon button"
      @click="$emit('update')"
    >
      <i class="edit icon" />
      <translate translate-context="Content/*/Button.Label/Verb">
        Edit
      </translate>
    </button>
  </div>
</template>

<script>
import showdown from 'showdown'

export default {
  props: {
    object: { type: Object, default: null }
  },
  data () {
    return {
      markdown: null
    }
  },
  created () {
    this.markdown = showdown.Converter({ simplifiedAutoLink: true, openLinksInNewWindow: true })
  }
}
</script>
