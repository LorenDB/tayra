<template>
  <section class="ui vertical stripe segment">
    <div class="ui text container">
      <h2>
        <translate
          v-if="canEdit"
          translate-context="Content/*/Title"
        >
          Edit this track
        </translate>
        <translate
          key="2"
          translate-context="Content/*/Title"
        >
          Suggest an edit on this track
        </translate>
      </h2>
      <div
        v-if="!object.is_local"
        class="ui message"
      >
        <translate translate-context="Content/*/Message">
          This object is managed by another server, you cannot edit it.
        </translate>
      </div>
      <edit-form
        v-else-if="!isLoadingLicenses"
        :object-type="objectType"
        :object="object"
        :can-edit="canEdit"
        :licenses="licenses"
      />
      <div
        v-else
        class="ui inverted active dimmer"
      >
        <div class="ui loader" />
      </div>
    </div>
  </section>
</template>

<script>
import axios from 'axios'

import EditForm from '~/components/library/EditForm.vue'
export default {
  components: {
    EditForm
  },
  props: {
    objectType: { type: String, required: true },
    object: { type: Object, required: true },
    libraries: { type: Array, default: null }
  },
  data () {
    return {
      id: this.object.id,
      isLoadingLicenses: false,
      licenses: []
    }
  },
  computed: {
    canEdit () {
      return true
    }
  },
  created () {
    this.fetchLicenses()
  },
  methods: {
    fetchLicenses () {
      const self = this
      self.isLoadingLicenses = true
      axios.get('licenses/').then((response) => {
        self.isLoadingLicenses = false
        self.licenses = response.data.results
      })
    }
  }
}
</script>
