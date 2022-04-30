import { createRouter, createWebHistory } from 'vue-router'
import store from '~/store'

function adminPermissions (to, from, next) {
  if (store.state.auth.authenticated === true && store.state.auth.availablePermissions.settings === true) {
    next()
  } else {
    console.log('Not authenticated. Redirecting to library.')
    next({ name: 'library.index' })
  }
}

function moderatorPermissions (to, from, next) {
  if (store.state.auth.authenticated === true && store.state.auth.availablePermissions.moderation === true) {
    next()
  } else {
    console.log('Not authenticated. Redirecting to library.')
    next({ name: 'library.index' })
  }
}

function libraryPermissions (to, from, next) {
  if (store.state.auth.authenticated === true && store.state.auth.availablePermissions.library === true) {
    next()
  } else {
    console.log('Not authenticated. Redirecting to library.')
    next({ name: 'library.index' })
  }
}

console.log('PROCESS', import.meta.env)
export default createRouter({
  history: createWebHistory(import.meta.env.VUE_APP_ROUTER_BASE_URL as string ?? '/'),
  linkActiveClass: 'active',
  scrollBehavior (to, from, savedPosition) {
    if (to.meta.preserveScrollPosition) {
      return savedPosition ?? { left: 0, top: 0 }
    }

    return new Promise(resolve => {
      setTimeout(() => {
        if (to.hash) {
          resolve({ el: to.hash, behavior: 'smooth' })
        }

        const pos = savedPosition ?? { left: 0, top: 0 }
        resolve(pos)
      }, 100)
    })
  },
  routes: [
    {
      path: '/',
      name: 'index',
      component: () =>
        import('~/components/Home.vue')
    },
    {
      path: '/front',
      name: 'front',
      redirect: to => {
        const { hash, query } = to
        return { name: 'index', hash, query }
      }
    },
    {
      path: '/about',
      name: 'about',
      component: () =>
        import('~/components/About.vue')
    },
    {
      path: '/about/pod',
      name: 'about-pod',
      component: () =>
        import('~/components/AboutPod.vue')
    },
    {
      path: '/login',
      name: 'login',
      component: () =>
        import('~/views/auth/Login.vue'),
      props: route => ({ next: route.query.next || '/library' })
    },
    {
      path: '/notifications',
      name: 'notifications',
      component: () =>
        import('~/views/Notifications.vue')
    },
    {
      path: '/auth/password/reset',
      name: 'auth.password-reset',
      component: () =>
        import('~/views/auth/PasswordReset.vue'),
      props: route => ({
        defaultEmail: route.query.email
      })
    },
    {
      path: '/auth/callback',
      name: 'auth.callback',
      component: () =>
        import('~/views/auth/Callback.vue'),
      props: route => ({
        code: route.query.code,
        state: route.query.state
      })
    },
    {
      path: '/auth/email/confirm',
      name: 'auth.email-confirm',
      component: () =>
        import('~/views/auth/EmailConfirm.vue'),
      props: route => ({
        defaultKey: route.query.key
      })
    },
    {
      path: '/search',
      name: 'search',
      component: () =>
        import('~/views/Search.vue'),
      props: route => ({
        initialId: route.query.id,
        initialType: route.query.type || 'artists',
        initialQuery: route.query.q,
        initialPage: parseInt(route.query.page) || 1
      })
    },
    {
      path: '/auth/password/reset/confirm',
      name: 'auth.password-reset-confirm',
      component: () =>
        import(
          '~/views/auth/PasswordResetConfirm.vue'
        ),
      props: route => ({
        defaultUid: route.query.uid,
        defaultToken: route.query.token
      })
    },
    {
      path: '/authorize',
      name: 'authorize',
      component: () =>
        import('~/components/auth/Authorize.vue'),
      props: route => ({
        clientId: route.query.client_id,
        redirectUri: route.query.redirect_uri,
        scope: route.query.scope,
        responseType: route.query.response_type,
        nonce: route.query.nonce,
        state: route.query.state
      })
    },
    {
      path: '/signup',
      name: 'signup',
      component: () =>
        import('~/views/auth/Signup.vue'),
      props: route => ({
        defaultInvitation: route.query.invitation
      })
    },
    {
      path: '/logout',
      name: 'logout',
      component: () =>
        import('~/components/auth/Logout.vue')
    },
    {
      path: '/settings',
      name: 'settings',
      component: () =>
        import('~/components/auth/Settings.vue')
    },
    {
      path: '/settings/applications/new',
      name: 'settings.applications.new',
      props: route => ({
        scopes: route.query.scopes,
        name: route.query.name,
        redirect_uris: route.query.redirect_uris
      }),
      component: () =>
        import(
          '~/components/auth/ApplicationNew.vue'
        )
    },
    {
      path: '/settings/plugins',
      name: 'settings.plugins',
      component: () =>
        import(
          '~/views/auth/Plugins.vue'
        )
    },
    {
      path: '/settings/applications/:id/edit',
      name: 'settings.applications.edit',
      component: () =>
        import(
          '~/components/auth/ApplicationEdit.vue'
        ),
      props: true
    },
    ...[{ suffix: '.full', path: '/@:username@:domain' }, { suffix: '', path: '/@:username' }].map((route) => {
      return {
        path: route.path,
        name: `profile${route.suffix}`,
        component: () =>
          import('~/views/auth/ProfileBase.vue'),
        props: true,
        children: [
          {
            path: '',
            name: `profile${route.suffix}.overview`,
            component: () =>
              import(
                '~/views/auth/ProfileOverview.vue'
              )
          },
          {
            path: 'activity',
            name: `profile${route.suffix}.activity`,
            component: () =>
              import(
                '~/views/auth/ProfileActivity.vue'
              )
          }
        ]
      }
    }),
    {
      path: '/favorites',
      name: 'favorites',
      component: () =>
        import('~/components/favorites/List.vue'),
      props: route => ({
        defaultOrdering: route.query.ordering,
        defaultPage: route.query.page,
        defaultPaginateBy: route.query.paginateBy
      })
    },
    {
      path: '/content',
      component: () =>
        import('~/views/content/Base.vue'),
      children: [
        {
          path: '',
          name: 'content.index',
          component: () =>
            import('~/views/content/Home.vue')
        }
      ]
    },
    {
      path: '/content/libraries/tracks',
      component: () =>
        import('~/views/content/Base.vue'),
      children: [
        {
          path: '',
          name: 'content.libraries.files',
          component: () =>
            import(
              '~/views/content/libraries/Files.vue'
            ),
          props: route => ({
            query: route.query.q
          })
        }
      ]
    },
    {
      path: '/content/libraries',
      component: () =>
        import('~/views/content/Base.vue'),
      children: [
        {
          path: '',
          name: 'content.libraries.index',
          component: () =>
            import(
              '~/views/content/libraries/Home.vue'
            )
        }
      ]
    },
    {
      path: '/content/remote',
      component: () =>
        import('~/views/content/Base.vue'),
      children: [
        {
          path: '',
          name: 'content.remote.index',
          component: () =>
            import('~/views/content/remote/Home.vue')
        }
      ]
    },
    {
      path: '/manage/settings',
      name: 'manage.settings',
      beforeEnter: adminPermissions,
      component: () =>
        import('~/views/admin/Settings.vue')
    },
    {
      path: '/manage/library',
      beforeEnter: libraryPermissions,
      component: () =>
        import('~/views/admin/library/Base.vue'),
      children: [
        {
          path: 'edits',
          name: 'manage.library.edits',
          component: () =>
            import(
              '~/views/admin/library/EditsList.vue'
            ),
          props: route => {
            return {
              defaultQuery: route.query.q
            }
          }
        },
        {
          path: 'artists',
          name: 'manage.library.artists',
          component: () =>
            import(
              '~/views/admin/library/ArtistsList.vue'
            ),
          props: route => {
            return {
              defaultQuery: route.query.q
            }
          }
        },
        {
          path: 'artists/:id',
          name: 'manage.library.artists.detail',
          component: () =>
            import(
              '~/views/admin/library/ArtistDetail.vue'
            ),
          props: true
        },
        {
          path: 'channels',
          name: 'manage.channels',
          component: () =>
            import(
              '~/views/admin/ChannelsList.vue'
            ),
          props: route => {
            return {
              defaultQuery: route.query.q
            }
          }
        },
        {
          path: 'channels/:id',
          name: 'manage.channels.detail',
          component: () =>
            import(
              '~/views/admin/ChannelDetail.vue'
            ),
          props: true
        },
        {
          path: 'albums',
          name: 'manage.library.albums',
          component: () =>
            import(
              '~/views/admin/library/AlbumsList.vue'
            ),
          props: route => {
            return {
              defaultQuery: route.query.q
            }
          }
        },
        {
          path: 'albums/:id',
          name: 'manage.library.albums.detail',
          component: () =>
            import(
              '~/views/admin/library/AlbumDetail.vue'
            ),
          props: true
        },
        {
          path: 'tracks',
          name: 'manage.library.tracks',
          component: () =>
            import(
              '~/views/admin/library/TracksList.vue'
            ),
          props: route => {
            return {
              defaultQuery: route.query.q
            }
          }
        },
        {
          path: 'tracks/:id',
          name: 'manage.library.tracks.detail',
          component: () =>
            import(
              '~/views/admin/library/TrackDetail.vue'
            ),
          props: true
        },
        {
          path: 'libraries',
          name: 'manage.library.libraries',
          component: () =>
            import(
              '~/views/admin/library/LibrariesList.vue'
            ),
          props: route => {
            return {
              defaultQuery: route.query.q
            }
          }
        },
        {
          path: 'libraries/:id',
          name: 'manage.library.libraries.detail',
          component: () =>
            import(
              '~/views/admin/library/LibraryDetail.vue'
            ),
          props: true
        },
        {
          path: 'uploads',
          name: 'manage.library.uploads',
          component: () =>
            import(
              '~/views/admin/library/UploadsList.vue'
            ),
          props: route => {
            return {
              defaultQuery: route.query.q
            }
          }
        },
        {
          path: 'uploads/:id',
          name: 'manage.library.uploads.detail',
          component: () =>
            import(
              '~/views/admin/library/UploadDetail.vue'
            ),
          props: true
        },
        {
          path: 'tags',
          name: 'manage.library.tags',
          component: () =>
            import(
              '~/views/admin/library/TagsList.vue'
            ),
          props: route => {
            return {
              defaultQuery: route.query.q
            }
          }
        },
        {
          path: 'tags/:id',
          name: 'manage.library.tags.detail',
          component: () =>
            import(
              '~/views/admin/library/TagDetail.vue'
            ),
          props: true
        }
      ]
    },
    {
      path: '/manage/users',
      beforeEnter: adminPermissions,
      component: () =>
        import('~/views/admin/users/Base.vue'),
      children: [
        {
          path: 'users',
          name: 'manage.users.users.list',
          component: () =>
            import(
              '~/views/admin/users/UsersList.vue'
            )
        },
        {
          path: 'invitations',
          name: 'manage.users.invitations.list',
          component: () =>
            import(
              '~/views/admin/users/InvitationsList.vue'
            )
        }
      ]
    },
    {
      path: '/manage/moderation',
      beforeEnter: moderatorPermissions,
      component: () =>
        import('~/views/admin/moderation/Base.vue'),
      children: [
        {
          path: 'domains',
          name: 'manage.moderation.domains.list',
          component: () =>
            import(
              '~/views/admin/moderation/DomainsList.vue'
            )
        },
        {
          path: 'domains/:id',
          name: 'manage.moderation.domains.detail',
          component: () =>
            import(
              '~/views/admin/moderation/DomainsDetail.vue'
            ),
          props: true
        },
        {
          path: 'accounts',
          name: 'manage.moderation.accounts.list',
          component: () =>
            import(
              '~/views/admin/moderation/AccountsList.vue'
            ),
          props: route => {
            return {
              defaultQuery: route.query.q
            }
          }
        },
        {
          path: 'accounts/:id',
          name: 'manage.moderation.accounts.detail',
          component: () =>
            import(
              '~/views/admin/moderation/AccountsDetail.vue'
            ),
          props: true
        },
        {
          path: 'reports',
          name: 'manage.moderation.reports.list',
          component: () =>
            import(
              '~/views/admin/moderation/ReportsList.vue'
            ),
          props: route => {
            return {
              defaultQuery: route.query.q,
              updateUrl: true
            }
          }
        },
        {
          path: 'reports/:id',
          name: 'manage.moderation.reports.detail',
          component: () =>
            import(
              '~/views/admin/moderation/ReportDetail.vue'
            ),
          props: true
        },
        {
          path: 'requests',
          name: 'manage.moderation.requests.list',
          component: () =>
            import(
              '~/views/admin/moderation/RequestsList.vue'
            ),
          props: route => {
            return {
              defaultQuery: route.query.q,
              updateUrl: true
            }
          }
        },
        {
          path: 'requests/:id',
          name: 'manage.moderation.requests.detail',
          component: () =>
            import(
              '~/views/admin/moderation/RequestDetail.vue'
            ),
          props: true
        }
      ]
    },
    {
      path: '/library',
      component: () =>
        import('~/components/library/Library.vue'),
      children: [
        {
          path: '',
          component: () =>
            import('~/components/library/Home.vue'),
          name: 'library.index'
        },
        {
          path: 'me',
          component: () =>
            import('~/components/library/Home.vue'),
          name: 'library.me',
          props: route => ({
            scope: 'me'
          })
        },
        {
          path: 'artists/',
          name: 'library.artists.browse',
          component: () =>
            import(
              '~/components/library/Artists.vue'
            ),
          props: route => ({
            defaultOrdering: route.query.ordering,
            defaultQuery: route.query.query,
            defaultTags: Array.isArray(route.query.tag || [])
              ? route.query.tag
              : [route.query.tag],
            defaultPaginateBy: route.query.paginateBy,
            defaultPage: route.query.page
          })
        },
        {
          path: 'me/artists',
          name: 'library.artists.me',
          component: () =>
            import(
              '~/components/library/Artists.vue'
            ),
          props: route => ({
            scope: 'me',
            defaultOrdering: route.query.ordering,
            defaultQuery: route.query.query,
            defaultTags: Array.isArray(route.query.tag || [])
              ? route.query.tag
              : [route.query.tag],
            defaultPaginateBy: route.query.paginateBy,
            defaultPage: route.query.page
          })
        },
        {
          path: 'albums/',
          name: 'library.albums.browse',
          component: () =>
            import(
              '~/components/library/Albums.vue'
            ),
          props: route => ({
            defaultOrdering: route.query.ordering,
            defaultQuery: route.query.query,
            defaultTags: Array.isArray(route.query.tag || [])
              ? route.query.tag
              : [route.query.tag],
            defaultPaginateBy: route.query.paginateBy,
            defaultPage: route.query.page
          })
        },
        {
          path: 'podcasts/',
          name: 'library.podcasts.browse',
          component: () =>
            import(
              '~/components/library/Podcasts.vue'
            ),
          props: route => ({
            defaultOrdering: route.query.ordering,
            defaultQuery: route.query.query,
            defaultTags: Array.isArray(route.query.tag || [])
              ? route.query.tag
              : [route.query.tag],
            defaultPaginateBy: route.query.paginateBy,
            defaultPage: route.query.page
          })
        },
        {
          path: 'me/albums',
          name: 'library.albums.me',
          component: () =>
            import(
              '~/components/library/Albums.vue'
            ),
          props: route => ({
            scope: 'me',
            defaultOrdering: route.query.ordering,
            defaultQuery: route.query.query,
            defaultTags: Array.isArray(route.query.tag || [])
              ? route.query.tag
              : [route.query.tag],
            defaultPaginateBy: route.query.paginateBy,
            defaultPage: route.query.page
          })
        },
        {
          path: 'radios/',
          name: 'library.radios.browse',
          component: () =>
            import(
              '~/components/library/Radios.vue'
            ),
          props: route => ({
            defaultOrdering: route.query.ordering,
            defaultQuery: route.query.query,
            defaultPaginateBy: route.query.paginateBy,
            defaultPage: route.query.page
          })
        },
        {
          path: 'me/radios/',
          name: 'library.radios.me',
          component: () =>
            import(
              '~/components/library/Radios.vue'
            ),
          props: route => ({
            scope: 'me',
            defaultOrdering: route.query.ordering,
            defaultQuery: route.query.query,
            defaultPaginateBy: route.query.paginateBy,
            defaultPage: route.query.page
          })
        },
        {
          path: 'radios/build',
          name: 'library.radios.build',
          component: () =>
            import(
              '~/components/library/radios/Builder.vue'
            ),
          props: true
        },
        {
          path: 'radios/build/:id',
          name: 'library.radios.edit',
          component: () =>
            import(
              '~/components/library/radios/Builder.vue'
            ),
          props: true
        },
        {
          path: 'radios/:id',
          name: 'library.radios.detail',
          component: () =>
            import('~/views/radios/Detail.vue'),
          props: true
        },
        {
          path: 'playlists/',
          name: 'library.playlists.browse',
          component: () =>
            import('~/views/playlists/List.vue'),
          props: route => ({
            defaultOrdering: route.query.ordering,
            defaultQuery: route.query.query,
            defaultPaginateBy: route.query.paginateBy,
            defaultPage: route.query.page
          })
        },
        {
          path: 'me/playlists/',
          name: 'library.playlists.me',
          component: () =>
            import('~/views/playlists/List.vue'),
          props: route => ({
            scope: 'me',
            defaultOrdering: route.query.ordering,
            defaultQuery: route.query.query,
            defaultPaginateBy: route.query.paginateBy,
            defaultPage: route.query.page
          })
        },
        {
          path: 'playlists/:id',
          name: 'library.playlists.detail',
          component: () =>
            import('~/views/playlists/Detail.vue'),
          props: route => ({
            id: route.params.id,
            defaultEdit: route.query.mode === 'edit'
          })
        },
        {
          path: 'tags/:id',
          name: 'library.tags.detail',
          component: () =>
            import(
              '~/components/library/TagDetail.vue'
            ),
          props: true
        },
        {
          path: 'artists/:id',
          component: () =>
            import(
              '~/components/library/ArtistBase.vue'
            ),
          props: true,
          children: [
            {
              path: '',
              name: 'library.artists.detail',
              component: () =>
                import(
                  '~/components/library/ArtistDetail.vue'
                )
            },
            {
              path: 'edit',
              name: 'library.artists.edit',
              component: () =>
                import(
                  '~/components/library/ArtistEdit.vue'
                )
            },
            {
              path: 'edit/:editId',
              name: 'library.artists.edit.detail',
              component: () =>
                import(
                  '~/components/library/EditDetail.vue'
                ),
              props: true
            }
          ]
        },
        {
          path: 'albums/:id',
          component: () =>
            import(
              '~/components/library/AlbumBase.vue'
            ),
          props: true,
          children: [
            {
              path: '',
              name: 'library.albums.detail',
              component: () =>
                import(
                  '~/components/library/AlbumDetail.vue'
                )
            },
            {
              path: 'edit',
              name: 'library.albums.edit',
              component: () =>
                import(
                  '~/components/library/AlbumEdit.vue'
                )
            },
            {
              path: 'edit/:editId',
              name: 'library.albums.edit.detail',
              component: () =>
                import(
                  '~/components/library/EditDetail.vue'
                ),
              props: true
            }
          ]
        },
        {
          path: 'tracks/:id',
          component: () =>
            import(
              '~/components/library/TrackBase.vue'
            ),
          props: true,
          children: [
            {
              path: '',
              name: 'library.tracks.detail',
              component: () =>
                import(
                  '~/components/library/TrackDetail.vue'
                )
            },
            {
              path: 'edit',
              name: 'library.tracks.edit',
              component: () =>
                import(
                  '~/components/library/TrackEdit.vue'
                )
            },
            {
              path: 'edit/:editId',
              name: 'library.tracks.edit.detail',
              component: () =>
                import(
                  '~/components/library/EditDetail.vue'
                ),
              props: true
            }
          ]
        },
        {
          path: 'uploads/:id',
          name: 'library.uploads.detail',
          props: true,
          component: () =>
            import(
              '~/components/library/UploadDetail.vue'
            )
        },
        {
          // browse a single library via it's uuid
          path: ':id([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})',
          props: true,
          component: () =>
            import(
              '~/views/library/DetailBase.vue'
            ),
          children: [
            {
              path: '',
              name: 'library.detail',
              component: () =>
                import(
                  '~/views/library/DetailOverview.vue'
                )
            },
            {
              path: 'albums',
              name: 'library.detail.albums',
              component: () =>
                import(
                  '~/views/library/DetailAlbums.vue'
                )
            },
            {
              path: 'tracks',
              name: 'library.detail.tracks',
              component: () =>
                import(
                  '~/views/library/DetailTracks.vue'
                )
            },
            {
              path: 'edit',
              name: 'library.detail.edit',
              component: () =>
                import(
                  '~/views/library/Edit.vue'
                )
            },
            {
              path: 'upload',
              name: 'library.detail.upload',
              component: () =>
                import(
                  '~/views/library/Upload.vue'
                ),
              props: route => ({
                defaultImportReference: route.query.import
              })
            }
          ]
        }
      ]
    },
    {
      path: '/channels/:id',
      props: true,
      component: () =>
        import(
          '~/views/channels/DetailBase.vue'
        ),
      children: [
        {
          path: '',
          name: 'channels.detail',
          component: () =>
            import(
              '~/views/channels/DetailOverview.vue'
            )
        },
        {
          path: 'episodes',
          name: 'channels.detail.episodes',
          component: () =>
            import(
              '~/views/channels/DetailEpisodes.vue'
            )
        }
      ]
    },
    {
      path: '/subscriptions',
      name: 'subscriptions',
      props: route => {
        return {
          defaultQuery: route.query.q
        }
      },
      component: () =>
        import(
          '~/views/channels/SubscriptionsList.vue'
        )
    },
    {
      path: '/index.html',
      redirect: '/'
    },
    {
      path: '/:pathMatch(.*)*',
      name: '404',
      component: () =>
        import('~/components/PageNotFound.vue')
    }
  ]
})
