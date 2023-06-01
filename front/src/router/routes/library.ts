import type { RouteRecordRaw } from 'vue-router'

export default [
  {
    path: '/library',
    component: () => import('~/components/library/Library.vue'),
    children: [
      {
        path: '',
        component: () => import('~/components/library/Home.vue'),
        name: 'library.index'
      },
      {
        path: 'me',
        component: () => import('~/components/library/Home.vue'),
        name: 'library.me',
        props: () => ({ scope: 'me' })
      },
      {
        path: 'artists/',
        name: 'library.artists.browse',
        component: () => import('~/components/library/Artists.vue'),
        meta: {
          paginateBy: 30
        }
      },
      {
        path: 'me/artists',
        name: 'library.artists.me',
        component: () => import('~/components/library/Artists.vue'),
        props: { scope: 'me' },
        meta: {
          paginateBy: 30
        }
      },
      {
        path: 'albums/',
        name: 'library.albums.browse',
        component: () => import('~/components/library/Albums.vue'),
        meta: {
          paginateBy: 25
        }
      },
      {
        path: 'me/albums',
        name: 'library.albums.me',
        component: () => import('~/components/library/Albums.vue'),
        props: { scope: 'me' },
        meta: {
          paginateBy: 25
        }
      },
      {
        path: 'podcasts/',
        name: 'library.podcasts.browse',
        component: () => import('~/components/library/Podcasts.vue'),
        meta: {
          paginateBy: 30
        }
      },
      {
        path: 'radios/',
        name: 'library.radios.browse',
        component: () => import('~/components/library/Radios.vue'),
        meta: {
          paginateBy: 12
        }
      },
      {
        path: 'me/radios/',
        name: 'library.radios.me',
        component: () => import('~/components/library/Radios.vue'),
        props: { scope: 'me' },
        meta: {
          paginateBy: 12
        }
      },
      {
        path: 'radios/build',
        name: 'library.radios.build',
        component: () => import('~/components/library/radios/Builder.vue'),
        props: true
      },
      {
        path: 'radios/build/:id',
        name: 'library.radios.edit',
        component: () => import('~/components/library/radios/Builder.vue'),
        props: true
      },
      {
        path: 'radios/:id',
        name: 'library.radios.detail',
        component: () => import('~/views/radios/Detail.vue'),
        props: true
      },
      {
        path: 'playlists/',
        name: 'library.playlists.browse',
        component: () => import('~/views/playlists/List.vue'),
        meta: {
          paginateBy: 25
        }
      },
      {
        path: 'me/playlists/',
        name: 'library.playlists.me',
        component: () => import('~/views/playlists/List.vue'),
        props: { scope: 'me' },
        meta: {
          paginateBy: 25
        }
      },
      {
        path: 'playlists/:id',
        name: 'library.playlists.detail',
        component: () => import('~/views/playlists/Detail.vue'),
        props: route => ({
          id: route.params.id,
          defaultEdit: route.query.mode === 'edit'
        })
      },
      {
        path: 'tags/:id',
        name: 'library.tags.detail',
        component: () => import('~/components/library/TagDetail.vue'),
        props: true
      },
      {
        path: 'artists/:id',
        component: () => import('~/components/library/ArtistBase.vue'),
        props: true,
        children: [
          {
            path: '',
            name: 'library.artists.detail',
            component: () => import('~/components/library/ArtistDetail.vue')
          },
          {
            path: 'edit',
            name: 'library.artists.edit',
            component: () => import('~/components/library/ArtistEdit.vue')
          },
          {
            path: 'edit/:editId',
            name: 'library.artists.edit.detail',
            component: () => import('~/components/library/EditDetail.vue'),
            props: true
          }
        ]
      },
      {
        path: 'albums/:id',
        component: () => import('~/components/library/AlbumBase.vue'),
        props: true,
        children: [
          {
            path: '',
            name: 'library.albums.detail',
            component: () => import('~/components/library/AlbumDetail.vue')
          },
          {
            path: 'edit',
            name: 'library.albums.edit',
            component: () => import('~/components/library/AlbumEdit.vue')
          },
          {
            path: 'edit/:editId',
            name: 'library.albums.edit.detail',
            component: () => import('~/components/library/EditDetail.vue'),
            props: true
          }
        ]
      },
      {
        path: 'tracks/:id',
        component: () => import('~/components/library/TrackBase.vue'),
        props: true,
        children: [
          {
            path: '',
            name: 'library.tracks.detail',
            component: () => import('~/components/library/TrackDetail.vue')
          },
          {
            path: 'edit',
            name: 'library.tracks.edit',
            component: () => import('~/components/library/TrackEdit.vue')
          },
          {
            path: 'edit/:editId',
            name: 'library.tracks.edit.detail',
            component: () => import('~/components/library/EditDetail.vue'),
            props: true
          }
        ]
      },
      {
        path: 'uploads/:id',
        name: 'library.uploads.detail',
        props: true,
        component: () => import('~/components/library/UploadDetail.vue')
      },
      {
        // browse a single library via it's uuid
        path: ':id([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})',
        props: true,
        component: () => import('~/views/library/LibraryBase.vue'),
        children: [
          {
            path: '',
            name: 'library.detail',
            component: () => import('~/views/library/DetailOverview.vue')
          },
          {
            path: 'albums',
            name: 'library.detail.albums',
            component: () => import('~/views/library/DetailAlbums.vue')
          },
          {
            path: 'tracks',
            name: 'library.detail.tracks',
            component: () => import('~/views/library/DetailTracks.vue')
          },
          {
            path: 'edit',
            name: 'library.detail.edit',
            component: () => import('~/views/library/Edit.vue')
          },
          {
            path: 'upload',
            name: 'library.detail.upload',
            component: () => import('~/views/library/Upload.vue'),
            props: route => ({
              defaultImportReference: route.query.import
            })
          }
        ]
      }
    ]
  }
] as RouteRecordRaw[]
