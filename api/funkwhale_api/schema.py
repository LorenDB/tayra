import re

from drf_spectacular.openapi import AutoSchema
from pluralizer import Pluralizer


class CustomAutoSchema(AutoSchema):
    method_mapping = {
        "get": "get",
        "post": "create",
        "put": "update",
        "patch": "partial_update",
        "delete": "delete",
    }

    pluralizer = Pluralizer()

    def get_operation_id(self):
        # Modified operation id getter from
        # https://github.com/tfranzel/drf-spectacular/blob/6973aa48f4ff08f7f33799d50c288fcc79ea8076/drf_spectacular/openapi.py#L424-L441

        tokenized_path = self._tokenize_path()

        # replace dashes as they can be problematic later in code generation
        tokenized_path = [t.replace("-", "_") for t in tokenized_path]

        # replace plural forms with singular forms
        tokenized_path = [self.pluralizer.singular(t) for t in tokenized_path]

        if not tokenized_path:
            tokenized_path.append("root")

        model = tokenized_path.pop()
        model_singular = model

        if self.method == "GET" and self._is_list_view():
            action = "get"
            model = self.pluralizer.plural(model)
        else:
            action = self.method_mapping[self.method.lower()]

        if re.search(r"<drf_format_suffix\w*:\w+>", self.path_regex):
            tokenized_path.append("formatted")

        # rename `create_radio_radio` to `create_radio`. Works with all models
        if len(tokenized_path) > 0 and model_singular == tokenized_path[0]:
            tokenized_path.pop(0)

        # rename `get_radio_radio_track` to `get_radio_track`. Works with all models
        if len(tokenized_path) > 1 and tokenized_path[0] == tokenized_path[1]:
            tokenized_path.pop(0)

        # rename `get_manage_channel` to `admin_get_channel`
        if len(tokenized_path) > 0 and tokenized_path[0] == "manage":
            tokenized_path.pop(0)

            # rename `get_manage_library_album` to `admin_get_album`
            if len(tokenized_path) > 0 and tokenized_path[0] == "library":
                tokenized_path.pop(0)

            # rename `get_manage_user_users` to `admin_get_users`
            elif len(tokenized_path) > 0 and tokenized_path[0] == "user":
                tokenized_path.pop(0)

            # rename `get_manage_moderation_note` to `moderation_get_note`
            elif len(tokenized_path) > 0 and tokenized_path[0] == "moderation":
                tokenized_path.pop(0)
                return "_".join(["moderation", action] + tokenized_path + [model])

            return "_".join(["admin", action] + tokenized_path + [model])

        return "_".join([action] + tokenized_path + [model])
