import Vue from 'vue'

Vue.component('HumanDate', () => import(/* webpackChunkName: "common" */ '@/components/common/HumanDate'))
Vue.component('HumanDuration', () => import(/* webpackChunkName: "common" */ '@/components/common/HumanDuration'))
Vue.component('Username', () => import(/* webpackChunkName: "common" */ '@/components/common/Username'))
Vue.component('UserLink', () => import(/* webpackChunkName: "common" */ '@/components/common/UserLink'))
Vue.component('ActorLink', () => import(/* webpackChunkName: "common" */ '@/components/common/ActorLink'))
Vue.component('ActorAvatar', () => import(/* webpackChunkName: "common" */ '@/components/common/ActorAvatar'))
Vue.component('Duration', () => import(/* webpackChunkName: "common" */ '@/components/common/Duration'))
Vue.component('DangerousButton', () => import(/* webpackChunkName: "common" */ '@/components/common/DangerousButton'))
Vue.component('Message', () => import(/* webpackChunkName: "common" */ '@/components/common/Message'))
Vue.component('CopyInput', () => import(/* webpackChunkName: "common" */ '@/components/common/CopyInput'))
Vue.component('AjaxButton', () => import(/* webpackChunkName: "common" */ '@/components/common/AjaxButton'))
Vue.component('Tooltip', () => import(/* webpackChunkName: "common" */ '@/components/common/Tooltip'))
Vue.component('EmptyState', () => import(/* webpackChunkName: "common" */ '@/components/common/EmptyState'))
Vue.component('ExpandableDiv', () => import(/* webpackChunkName: "common" */ '@/components/common/ExpandableDiv'))
Vue.component('CollapseLink', () => import(/* webpackChunkName: "common" */ '@/components/common/CollapseLink'))
Vue.component('ActionFeedback', () => import(/* webpackChunkName: "common" */ '@/components/common/ActionFeedback'))
Vue.component('RenderedDescription', () => import(/* webpackChunkName: "common" */ '@/components/common/RenderedDescription'))
Vue.component('ContentForm', () => import(/* webpackChunkName: "common" */ '@/components/common/ContentForm'))
Vue.component('InlineSearchBar', () => import(/* webpackChunkName: "common" */ '@/components/common/InlineSearchBar'))

export default {}
