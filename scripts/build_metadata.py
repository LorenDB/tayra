#!/usr/bin/env python3

"""
Build metadata is a script that will extract build information from the environment,
either from CI variables or from git commands.

The build information are then mapped to the output format you need. The default output
format will print the build information as json.

- Release tags are stable version tags (e.g. 1.2.9),
- Prerelease tags are unstable version tags (e.g. 1.3.0-rc3),
- Development branches are both the 'stable' and 'develop' branches,
- Feature branches are any branch that will be merged in the development branches.
"""

import json
import logging
import os
import shlex
from argparse import ArgumentParser
from subprocess import check_output
from typing import List, Optional, TypedDict

from packaging.version import Version

logger = logging.getLogger(__name__)

PROJECT_NAME = "Funkwhale"
PROJECT_DESCRIPTION = "Funkwhale platform"
AUTHORS = "Funkwhale Collective"
WEBSITE_URL = "https://funkwhale.audio/"
SOURCE_URL = "https://dev.funkwhale.audio/funkwhale/funkwhale"
DOCUMENTATION_URL = "https://docs.funkwhale.audio"
LICENSE = "AGPL-3.0"


class Metadata(TypedDict):
    commit_tag: str
    commit_branch: str
    commit_sha: str
    commit_timestamp: str
    commit_ref_name: str

    version: str
    """
    Version is:
    - on release tags, the current tag name,
    - on prerelease tags, the current tag name,
    - on development branches, the latest tag name in the branch and the commit sha suffix,
    - on feature branches, an empty string.
    """
    tags: List[str]
    """
    Tags are:
    - on release tags, the current tag name and aliases in the form 'X.Y.Z', 'X.Y', 'X' and 'latest',
    - on prerelease tags, the current tag name,
    - on development branches, the current commit branch name,
    - on feature branches, an empty list.
    """
    latest: bool
    """
    Latest is true when the current tag name is not a prerelease:
    - on release tags: true,
    - on prerelease tags: false,
    - on development branches: false,
    - on feature branches: false.
    """


def sh(cmd: str, **kwargs):
    logger.debug("running command: %s", cmd)
    return check_output(shlex.split(cmd), text=True, **kwargs).strip()


def latest_tag_on_branch() -> str:
    """
    Return the latest tag on the current branch.
    """
    return sh("git describe --tags --abbrev=0")


def env_or_cmd(key: str, cmd: str) -> str:
    if "CI" in os.environ:
        return os.environ.get(key, "")

    return sh(cmd)


def extract_metadata() -> Metadata:
    commit_tag = env_or_cmd(
        "CI_COMMIT_TAG",
        "git tag --points-at HEAD",
    )
    commit_branch = env_or_cmd(
        "CI_COMMIT_BRANCH",
        "git rev-parse --abbrev-ref HEAD",
    )
    commit_sha = env_or_cmd(
        "CI_COMMIT_SHA",
        "git rev-parse HEAD",
    )
    commit_timestamp = env_or_cmd(
        "CI_COMMIT_TIMESTAMP",
        "git show -s --format=%cI HEAD",
    )
    commit_ref_name = os.environ.get(
        "CI_COMMIT_REF_NAME",
        default=commit_tag or commit_branch,
    )

    logger.info("found commit_tag: %s", commit_tag)
    logger.info("found commit_branch: %s", commit_branch)
    logger.info("found commit_sha: %s", commit_sha)
    logger.info("found commit_timestamp: %s", commit_timestamp)
    logger.info("found commit_ref_name: %s", commit_ref_name)

    version = ""
    tags = []
    latest = False
    if commit_tag:  # Tagged version
        version = Version(commit_tag)
        if version.is_prerelease:
            logger.info("build is for a prerelease tag")
            tags.append(commit_tag)

        else:
            logger.info("build is for a release tag")
            tags.append(f"{version.major}.{version.minor}.{version.micro}")
            tags.append(f"{version.major}.{version.minor}")
            tags.append(f"{version.major}")
            tags.append("latest")
            latest = True

        version = tags[0]

    else:  # Branch version
        if commit_branch in ("stable", "develop"):
            logger.info("build is for a development branch")
            tags.append(commit_branch)

            previous_tag = latest_tag_on_branch()
            previous_version = Version(previous_tag)
            version = f"{previous_version.base_version}-dev+{commit_sha[:7]}"

        else:
            logger.info("build is for a feature branch")

    return {
        "commit_tag": commit_tag,
        "commit_branch": commit_branch,
        "commit_sha": commit_sha,
        "commit_timestamp": commit_timestamp,
        "commit_ref_name": commit_ref_name,
        "version": version,
        "tags": tags,
        "latest": latest,
    }


def bake_output(
    metadata: Metadata,
    target: Optional[str],
    images: Optional[List[str]],
) -> dict:
    if target is None:
        logger.error("no bake target provided, exiting...")
        raise SystemExit(1)
    if images is None:
        logger.error("no bake images provided, exiting...")
        raise SystemExit(1)

    docker_tags = [f"{img}:{tag}" for img in images for tag in metadata["tags"]]

    docker_labels = {
        "org.opencontainers.image.title": PROJECT_NAME,
        "org.opencontainers.image.description": PROJECT_DESCRIPTION,
        "org.opencontainers.image.url": WEBSITE_URL,
        "org.opencontainers.image.source": SOURCE_URL,
        "org.opencontainers.image.documentation": DOCUMENTATION_URL,
        "org.opencontainers.image.licenses": LICENSE,
        "org.opencontainers.image.vendor": AUTHORS,
        "org.opencontainers.image.version": metadata["commit_ref_name"],
        "org.opencontainers.image.created": metadata["commit_timestamp"],
        "org.opencontainers.image.revision": metadata["commit_sha"],
    }

    return {
        "target": {
            target: {
                "tags": docker_tags,
                "labels": docker_labels,
            }
        }
    }


def env_output(metadata: Metadata) -> list[str]:
    env_dict = {
        "BUILD_COMMIT_TAG": str(metadata["commit_tag"]),
        "BUILD_COMMIT_BRANCH": str(metadata["commit_branch"]),
        "BUILD_COMMIT_SHA": str(metadata["commit_sha"]),
        "BUILD_COMMIT_TIMESTAMP": str(metadata["commit_timestamp"]),
        "BUILD_COMMIT_REF_NAME": str(metadata["commit_ref_name"]),
        "BUILD_VERSION": str(metadata["version"]),
        "BUILD_TAGS": ",".join(metadata["tags"]),
        "BUILD_LATEST": str(metadata["latest"]).lower(),
    }
    return [f"{key}={value}" for key, value in env_dict.items()]


def main(
    format_: str,
    bake_target: Optional[str],
    bake_images: Optional[List[str]],
) -> int:
    metadata = extract_metadata()

    if format_ == "bake":
        result = json.dumps(
            bake_output(metadata=metadata, target=bake_target, images=bake_images),
            indent=2,
        )
    elif format_ == "env":
        result = "\n".join(env_output(metadata=metadata))
    else:
        result = json.dumps(metadata, indent=2)

    print(result)
    return 0


if __name__ == "__main__":
    parser = ArgumentParser()
    parser.add_argument(
        "-f",
        "--format",
        choices=["bake", "env"],
        default=None,
        help="Print format for the metadata",
    )
    parser.add_argument(
        "--bake-target",
        help="Target for the bake metadata",
    )
    parser.add_argument(
        "--bake-image",
        action="append",
        dest="bake_images",
        help="Image names for the bake metadata",
    )
    args = parser.parse_args()
    logging.basicConfig(level=logging.DEBUG, format="%(levelname)s: %(message)s")

    raise SystemExit(main(args.format, args.bake_target, args.bake_images))
