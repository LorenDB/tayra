<script setup lang="ts">
import { truncate } from '~/utils/filters'
import { useRouter } from 'vue-router'
import { ref } from 'vue'

import axios from 'axios'

import useErrorHandler from '~/composables/useErrorHandler'

interface Props {
  id: number
}

const props = defineProps<Props>()

const router = useRouter()

const isLoading = ref(false)
const object = ref()
const fetchData = async () => {
  isLoading.value = true

  try {
    const response = await axios.get(`manage/tags/${props.id}/`)
    object.value = response.data
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoading.value = false
}

fetchData()

const remove = async () => {
  isLoading.value = true

  try {
    await axios.delete(`manage/tags/${props.id}/`)
    router.push({ name: 'manage.library.tags' })
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoading.value = false
}

const getQuery = (field: string, value: string) => `${field}:"${value}"`
</script>

<template>
  <main>
    <div
      v-if="isLoading"
      class="ui vertical segment"
    >
      <div :class="['ui', 'centered', 'active', 'inline', 'loader']" />
    </div>
    <template v-if="object">
      <section
        v-title="object.name"
        :class="['ui', 'head', 'vertical', 'stripe', 'segment']"
      >
        <div class="ui stackable one column grid">
          <div class="ui column">
            <div class="segment-content">
              <h2 class="ui header">
                <i class="circular inverted hashtag icon" />
                <div class="content">
                  {{ truncate(object.name) }}
                </div>
              </h2>
              <div class="header-buttons">
                <div class="ui icon buttons">
                  <router-link
                    class="ui labeled icon button"
                    :to="{name: 'library.tags.detail', params: {id: object.name }}"
                  >
                    <i class="info icon" />
                    Open local profile&nbsp;
                  </router-link>
                  <button
                    v-dropdown
                    class="ui floating dropdown icon button"
                  >
                    <i class="dropdown icon" />
                    <div class="menu">
                      <a
                        v-if="$store.state.auth.profile && $store.state.auth.profile.is_superuser"
                        class="basic item"
                        :href="$store.getters['instance/absoluteUrl'](`/api/admin/tags/tag/${object.id}`)"
                        target="_blank"
                        rel="noopener noreferrer"
                      >
                        <i class="wrench icon" />
                        View in Django's admin&nbsp;
                      </a>
                    </div>
                  </button>
                </div>
                <div class="ui buttons">
                  <dangerous-button
                    :class="['ui', {loading: isLoading}, 'basic danger button']"
                    :action="remove"
                  >
                    Delete
                    <template #modal-header>
                      <p>
                        Delete this tag?
                      </p>
                    </template>
                    <template #modal-content>
                      <div>
                        <p>
                          The tag will be removed and unlinked from any existing entity. This action is irreversible.
                        </p>
                      </div>
                    </template>
                    <template #modal-confirm>
                      <p>
                        Delete
                      </p>
                    </template>
                  </dangerous-button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>
      <div class="ui vertical stripe segment">
        <div class="ui stackable three column grid">
          <div class="column">
            <section>
              <h3 class="ui header">
                <i class="info icon" />
                <div class="content">
                  Tag data
                </div>
              </h3>
              <table class="ui very basic table">
                <tbody>
                  <tr>
                    <td>
                      Name
                    </td>
                    <td>
                      {{ object.name }}
                    </td>
                  </tr>
                </tbody>
              </table>
            </section>
          </div>
          <div class="column">
            <section>
              <h3 class="ui header">
                <i class="feed icon" />
                <div class="content">
                  Activity&nbsp;
                </div>
              </h3>
              <table class="ui very basic table">
                <tbody>
                  <tr>
                    <td>
                      First seen
                    </td>
                    <td>
                      <human-date :date="object.creation_date" />
                    </td>
                  </tr>
                </tbody>
              </table>
            </section>
          </div>
          <div class="column">
            <section>
              <h3 class="ui header">
                <i class="music icon" />
                <div class="content">
                  Audio content&nbsp;
                </div>
              </h3>
              <table class="ui very basic table">
                <tbody>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.artists', query: {q: getQuery('tag', object.name) }}">
                        Artists
                      </router-link>
                    </td>
                    <td>
                      {{ object.artists_count }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.albums', query: {q: getQuery('tag', object.name) }}">
                        Albums
                      </router-link>
                    </td>
                    <td>
                      {{ object.albums_count }}
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <router-link :to="{name: 'manage.library.tracks', query: {q: getQuery('tag', object.name) }}">
                        Tracks
                      </router-link>
                    </td>
                    <td>
                      {{ object.tracks_count }}
                    </td>
                  </tr>
                </tbody>
              </table>
            </section>
          </div>
        </div>
      </div>
    </template>
  </main>
</template>
