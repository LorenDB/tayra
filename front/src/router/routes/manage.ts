import { NavigationGuardNext, RouteLocationNormalized, RouteRecordRaw } from 'vue-router'
import { Permission } from '~/store/auth'
import store from '~/store'

const hasPermissions = (permission: Permission) => (to: RouteLocationNormalized, from: RouteLocationNormalized, next: NavigationGuardNext) => {
  if (store.state.auth.authenticated && store.state.auth.availablePermissions[permission]) {
    return next()
  }

  console.log('Not authenticated. Redirecting to library.')
  next({ name: 'library.index' })
}

export default [
  {
    path: '/manage/settings',
    name: 'manage.settings',
    beforeEnter: hasPermissions('admin'),
    component: () => import('~/views/admin/Settings.vue')
  },
  {
    path: '/manage/library',
    beforeEnter: hasPermissions('library'),
    component: () => import('~/views/admin/library/Base.vue'),
    children: [
      {
        path: 'edits',
        name: 'manage.library.edits',
        component: () => import('~/views/admin/library/EditsList.vue'),
        props: route => ({ defaultQuery: route.query.q })
      },
      {
        path: 'artists',
        name: 'manage.library.artists',
        component: () => import('~/views/admin/library/ArtistsList.vue'),
        props: route => ({ defaultQuery: route.query.q })
      },
      {
        path: 'artists/:id',
        name: 'manage.library.artists.detail',
        component: () => import('~/views/admin/library/ArtistDetail.vue'),
        props: true
      },
      {
        path: 'channels',
        name: 'manage.channels',
        component: () => import('~/views/admin/ChannelsList.vue'),
        props: route => ({ defaultQuery: route.query.q })
      },
      {
        path: 'channels/:id',
        name: 'manage.channels.detail',
        component: () => import('~/views/admin/ChannelDetail.vue'),
        props: true
      },
      {
        path: 'albums',
        name: 'manage.library.albums',
        component: () => import('~/views/admin/library/AlbumsList.vue'),
        props: route => ({ defaultQuery: route.query.q })
      },
      {
        path: 'albums/:id',
        name: 'manage.library.albums.detail',
        component: () => import('~/views/admin/library/AlbumDetail.vue'),
        props: true
      },
      {
        path: 'tracks',
        name: 'manage.library.tracks',
        component: () => import('~/views/admin/library/TracksList.vue'),
        props: route => ({ defaultQuery: route.query.q })
      },
      {
        path: 'tracks/:id',
        name: 'manage.library.tracks.detail',
        component: () => import('~/views/admin/library/TrackDetail.vue'),
        props: true
      },
      {
        path: 'libraries',
        name: 'manage.library.libraries',
        component: () => import('~/views/admin/library/LibrariesList.vue'),
        props: route => ({ defaultQuery: route.query.q })
      },
      {
        path: 'libraries/:id',
        name: 'manage.library.libraries.detail',
        component: () => import('~/views/admin/library/LibraryDetail.vue'),
        props: true
      },
      {
        path: 'uploads',
        name: 'manage.library.uploads',
        component: () => import('~/views/admin/library/UploadsList.vue'),
        props: route => ({ defaultQuery: route.query.q })
      },
      {
        path: 'uploads/:id',
        name: 'manage.library.uploads.detail',
        component: () => import('~/views/admin/library/UploadDetail.vue'),
        props: true
      },
      {
        path: 'tags',
        name: 'manage.library.tags',
        component: () => import('~/views/admin/library/TagsList.vue'),
        props: route => ({ defaultQuery: route.query.q })
      },
      {
        path: 'tags/:id',
        name: 'manage.library.tags.detail',
        component: () => import('~/views/admin/library/TagDetail.vue'),
        props: true
      }
    ]
  },
  {
    path: '/manage/users',
    beforeEnter: hasPermissions('admin'),
    component: () => import('~/views/admin/users/Base.vue'),
    children: [
      {
        path: 'users',
        name: 'manage.users.users.list',
        component: () => import('~/views/admin/users/UsersList.vue')
      },
      {
        path: 'invitations',
        name: 'manage.users.invitations.list',
        component: () => import('~/views/admin/users/InvitationsList.vue')
      }
    ]
  },
  {
    path: '/manage/moderation',
    beforeEnter: hasPermissions('moderation'),
    component: () => import('~/views/admin/moderation/Base.vue'),
    children: [
      {
        path: 'domains',
        name: 'manage.moderation.domains.list',
        component: () => import('~/views/admin/moderation/DomainsList.vue')
      },
      {
        path: 'domains/:id',
        name: 'manage.moderation.domains.detail',
        component: () => import('~/views/admin/moderation/DomainsDetail.vue'),
        props: true
      },
      {
        path: 'accounts',
        name: 'manage.moderation.accounts.list',
        component: () => import('~/views/admin/moderation/AccountsList.vue'),
        props: route => ({ defaultQuery: route.query.q })
      },
      {
        path: 'accounts/:id',
        name: 'manage.moderation.accounts.detail',
        component: () => import('~/views/admin/moderation/AccountsDetail.vue'),
        props: true
      },
      {
        path: 'reports',
        name: 'manage.moderation.reports.list',
        component: () => import('~/views/admin/moderation/ReportsList.vue'),
        props: route => ({ defaultQuery: route.query.q, updateUrl: true })
      },
      {
        path: 'reports/:id',
        name: 'manage.moderation.reports.detail',
        component: () => import('~/views/admin/moderation/ReportDetail.vue'),
        props: true
      },
      {
        path: 'requests',
        name: 'manage.moderation.requests.list',
        component: () => import('~/views/admin/moderation/RequestsList.vue'),
        props: route => ({ defaultQuery: route.query.q, updateUrl: true })
      },
      {
        path: 'requests/:id',
        name: 'manage.moderation.requests.detail',
        component: () => import('~/views/admin/moderation/RequestDetail.vue'),
        props: true
      }
    ]
  },
] as RouteRecordRaw[]
