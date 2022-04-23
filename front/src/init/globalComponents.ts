import { InitModule } from '~/types'

import HumanDate from '~/components/common/HumanDate.vue'
import HumanDuration from '~/components/common/HumanDuration.vue'
import Username from '~/components/common/Username.vue'
import UserLink from '~/components/common/UserLink.vue'
import ActorLink from '~/components/common/ActorLink.vue'
import ActorAvatar from '~/components/common/ActorAvatar.vue'
import Duration from '~/components/common/Duration.vue'
import DangerousButton from '~/components/common/DangerousButton.vue'
import Message from '~/components/common/Message.vue'
import CopyInput from '~/components/common/CopyInput.vue'
import AjaxButton from '~/components/common/AjaxButton.vue'
import Tooltip from '~/components/common/Tooltip.vue'
import EmptyState from '~/components/common/EmptyState.vue'
import ExpandableDiv from '~/components/common/ExpandableDiv.vue'
import CollapseLink from '~/components/common/CollapseLink.vue'
import ActionFeedback from '~/components/common/ActionFeedback.vue'
import RenderedDescription from '~/components/common/RenderedDescription.vue'
import ContentForm from '~/components/common/ContentForm.vue'
import InlineSearchBar from '~/components/common/InlineSearchBar.vue'

export const install: InitModule = ({ app }) => {
  app.component('HumanDate', HumanDate)
  app.component('HumanDuration', HumanDuration)
  app.component('Username', Username)
  app.component('UserLink', UserLink)
  app.component('ActorLink', ActorLink)
  app.component('ActorAvatar', ActorAvatar)
  app.component('Duration', Duration)
  app.component('DangerousButton', DangerousButton)
  app.component('Message', Message)
  app.component('CopyInput', CopyInput)
  app.component('AjaxButton', AjaxButton)
  app.component('Tooltip', Tooltip)
  app.component('EmptyState', EmptyState)
  app.component('ExpandableDiv', ExpandableDiv)
  app.component('CollapseLink', CollapseLink)
  app.component('ActionFeedback', ActionFeedback)
  app.component('RenderedDescription', RenderedDescription)
  app.component('ContentForm', ContentForm)
  app.component('InlineSearchBar', InlineSearchBar)
}
