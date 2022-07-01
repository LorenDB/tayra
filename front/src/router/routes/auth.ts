import { RouteRecordRaw } from 'vue-router'

export default [
  {
    path: '/login',
    name: 'login',
    component: () => import('~/views/auth/Login.vue'),
    // TODO (wvffle): Use named routes EVERYWHERE
    props: route => ({ next: route.query.next || '/library' })
  },
  {
    path: '/auth/password/reset',
    name: 'auth.password-reset',
    component: () => import('~/views/auth/PasswordReset.vue'),
    props: route => ({ defaultEmail: route.query.email })
  },
  {
    path: '/auth/callback',
    name: 'auth.callback',
    component: () => import('~/views/auth/Callback.vue'),
    props: route => ({
      code: route.query.code,
      state: route.query.state
    })
  },
  {
    path: '/auth/email/confirm',
    name: 'auth.email-confirm',
    component: () => import('~/views/auth/EmailConfirm.vue'),
    props: route => ({ defaultKey: route.query.key })
  },
  {
    path: '/auth/password/reset/confirm',
    name: 'auth.password-reset-confirm',
    component: () => import('~/views/auth/PasswordResetConfirm.vue'),
    props: route => ({
      defaultUid: route.query.uid,
      defaultToken: route.query.token
    })
  },
  {
    path: '/authorize',
    name: 'authorize',
    component: () => import('~/components/auth/Authorize.vue'),
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
    component: () => import('~/views/auth/Signup.vue'),
    props: route => ({ defaultInvitation: route.query.invitation })
  },
  {
    path: '/logout',
    name: 'logout',
    component: () => import('~/components/auth/Logout.vue')
  },
] as RouteRecordRaw[]