<script>
import axios from 'axios'

export default {
  computed: {
      playable () {
      if (this.isPlayable) {
        return true
      }
      if (this.track) {
        return this.track.uploads && this.track.uploads.length > 0
      } else if (this.artist && this.artist.tracks_count) {
        return this.artist.tracks_count > 0
      } else if (this.artist && this.artist.albums) {
        return this.artist.albums.filter((a) => {
          return a.is_playable === true
        }).length > 0
      } else if (this.album) {
        return true
      } else if (this.tracks) {
        return this.tracks.filter((t) => {
          return t.uploads && t.uploads.length > 0
        }).length > 0
      }
      return false
    },
    filterableArtist () {
      if (this.track) {
        return this.track.artist
      }
      if (this.album) {
        return this.album.artist
      }
      if (this.artist) {
        return this.artist
      }
    },
  },
  methods: {
    filterArtist () {
      this.$store.dispatch('moderation/hide', {type: 'artist', target: this.filterableArtist})
    },
    activateTrack(track, index) {
      if (
        this.currentTrack &&
        this.isPlaying &&
        track.id === this.currentTrack.id
      ) {
        this.pausePlayback();
      } else if (
        this.currentTrack &&
        !this.isPlaying &&
        track.id === this.currentTrack.id
      ) {
        this.resumePlayback();
      } else {
        this.replacePlay(this.tracks, index);
      }
    },
    getTracksPage (page, params, resolve, tracks) {
      if (page > 10) {
        // it's 10 * 100 tracks already, let's stop here
        resolve(tracks)
      }
      // when fetching artists/or album tracks, sometimes, we may have to fetch
      // multiple pages
      let self = this
      params['page_size'] = 100
      params['page'] = page
      params['hidden'] = ''
      params['playable'] = 'true'
      tracks = tracks || []
      axios.get('tracks/', {params: params}).then((response) => {
        response.data.results.forEach(t => {
          tracks.push(t)
        })
        if (response.data.next) {
          self.getTracksPage(page + 1, params, resolve, tracks)
        } else {
          resolve(tracks)
        }
      })
    },
    getPlayableTracks () {
      let self = this
      this.isLoading = true
      let getTracks = new Promise((resolve, reject) => {
        if (self.tracks) {
          resolve(self.tracks)
        } else if (self.track) {
          if (!self.track.uploads || self.track.uploads.length === 0) {
            // fetch uploads from api
            axios.get(`tracks/${self.track.id}/`).then((response) => {
              resolve([response.data])
            })
          } else {
            resolve([self.track])
          }
        } else if (self.playlist) {
          let url = 'playlists/' + self.playlist.id + '/'
          axios.get(url + 'tracks/').then((response) => {
            let artistIds = self.$store.getters['moderation/artistFilters']().map((f) => {
              return f.target.id
            })
            let tracks = response.data.results.map(plt => {
              return plt.track
            })
            if (artistIds.length > 0) {
              // skip tracks from hidden artists
              tracks = tracks.filter((t) => {
                let matchArtist = artistIds.indexOf(t.artist.id) > -1
                return !(matchArtist || t.album && artistIds.indexOf(t.album.artist.id) > -1)
              })
            }

            resolve(tracks)
          })
        } else if (self.artist) {
          let params = {'artist': self.artist.id, include_channels: 'true', 'ordering': 'album__release_date,disc_number,position'}
          self.getTracksPage(1, params, resolve)
        } else if (self.album) {
          let params = {'album': self.album.id, include_channels: 'true', 'ordering': 'disc_number,position'}
          self.getTracksPage(1, params, resolve)
        } else if (self.library) {
          let params = {'library': self.library.uuid, 'ordering': '-creation_date'}
          self.getTracksPage(1, params, resolve)
        }
      })
      return getTracks.then((tracks) => {
        setTimeout(e => {
          self.isLoading = false
        }, 250)
        return tracks.filter(e => {
          return e.uploads && e.uploads.length > 0
        })
      })
    },
    add () {
      let self = this
      this.getPlayableTracks().then((tracks) => {
        self.$store.dispatch('queue/appendMany', {tracks: tracks}).then(() => self.addMessage(tracks))
      })
      jQuery(self.$el).find('.ui.dropdown').dropdown('hide')
    },
    replacePlay () {
      let self = this
      self.$store.dispatch('queue/clean')
      this.getPlayableTracks().then((tracks) => {
        self.$store.dispatch('queue/appendMany', {tracks: tracks}).then(() => {
          if (self.track) {
            // set queue position to selected track
            const trackIndex = self.tracks.findIndex(track => track.id === self.track.id)
            self.$store.dispatch('queue/currentIndex', trackIndex)
          }
          self.addMessage(tracks)
        })
      })
      jQuery(self.$el).find('.ui.dropdown').dropdown('hide')
    },
    addNext (next) {
      let self = this
      let wasEmpty = this.$store.state.queue.tracks.length === 0
      this.getPlayableTracks().then((tracks) => {
        self.$store.dispatch('queue/appendMany', {tracks: tracks, index: self.$store.state.queue.currentIndex + 1}).then(() => self.addMessage(tracks))
        let goNext = next && !wasEmpty
        if (goNext) {
          self.$store.dispatch('queue/next')
        }
      })
      jQuery(self.$el).find('.ui.dropdown').dropdown('hide')
    },
    addMessage (tracks) {
      if (tracks.length < 1) {
        return
      }
      let msg = this.$npgettext('*/Queue/Message', '%{ count } track was added to your queue', '%{ count } tracks were added to your queue', tracks.length)
      this.$store.commit('ui/addMessage', {
        content: this.$gettextInterpolate(msg, {count: tracks.length}),
        date: new Date()
      })
    },
  }
}
</script>