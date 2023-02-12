from unittest import mock

import pytest
from build_metadata import (
    AUTHORS,
    DOCUMENTATION_URL,
    LICENSE,
    PROJECT_DESCRIPTION,
    PROJECT_NAME,
    SOURCE_URL,
    WEBSITE_URL,
    bake_output,
    env_output,
    extract_metadata,
)

common_docker_labels = {
    "org.opencontainers.image.title": PROJECT_NAME,
    "org.opencontainers.image.description": PROJECT_DESCRIPTION,
    "org.opencontainers.image.url": WEBSITE_URL,
    "org.opencontainers.image.source": SOURCE_URL,
    "org.opencontainers.image.documentation": DOCUMENTATION_URL,
    "org.opencontainers.image.licenses": LICENSE,
    "org.opencontainers.image.vendor": AUTHORS,
}

test_cases = [
    {  # On a random feature branch
        "environ": {
            "CI": "true",
            "CI_COMMIT_TAG": "",
            "CI_COMMIT_BRANCH": "ci_build_metadata",
            "CI_COMMIT_SHA": "de206ac559a171b68fb894b2d61db298fc386705",
            "CI_COMMIT_TIMESTAMP": "2023-01-31T13:31:13+01:00",
            "CI_COMMIT_REF_NAME": "ci_build_metadata",
        },
        "metadata": {
            "commit_tag": "",
            "commit_branch": "ci_build_metadata",
            "commit_sha": "de206ac559a171b68fb894b2d61db298fc386705",
            "commit_timestamp": "2023-01-31T13:31:13+01:00",
            "commit_ref_name": "ci_build_metadata",
            "version": "",
            "tags": [],
            "latest": False,
        },
        "bake_output": {
            "target": {
                "api": {
                    "tags": [],
                    "labels": {
                        **common_docker_labels,
                        "org.opencontainers.image.version": "ci_build_metadata",
                        "org.opencontainers.image.created": "2023-01-31T13:31:13+01:00",
                        "org.opencontainers.image.revision": "de206ac559a171b68fb894b2d61db298fc386705",
                    },
                }
            }
        },
        "env_output": [
            "BUILD_COMMIT_TAG=",
            "BUILD_COMMIT_BRANCH=ci_build_metadata",
            "BUILD_COMMIT_SHA=de206ac559a171b68fb894b2d61db298fc386705",
            "BUILD_COMMIT_TIMESTAMP=2023-01-31T13:31:13+01:00",
            "BUILD_COMMIT_REF_NAME=ci_build_metadata",
            "BUILD_VERSION=",
            "BUILD_TAGS=",
            "BUILD_LATEST=false",
        ],
    },
    {  # On the develop (or stable) branch
        "environ": {
            "CI": "true",
            "CI_COMMIT_TAG": "",
            "CI_COMMIT_BRANCH": "develop",
            "CI_COMMIT_SHA": "de206ac559a171b68fb894b2d61db298fc386705",
            "CI_COMMIT_TIMESTAMP": "2023-01-31T13:31:13+01:00",
            "CI_COMMIT_REF_NAME": "develop",
        },
        "metadata": {
            "commit_tag": "",
            "commit_branch": "develop",
            "commit_sha": "de206ac559a171b68fb894b2d61db298fc386705",
            "commit_timestamp": "2023-01-31T13:31:13+01:00",
            "commit_ref_name": "develop",
            "version": "1.7.2-dev+de206ac",
            "tags": ["develop"],
            "latest": False,
        },
        "bake_output": {
            "target": {
                "api": {
                    "tags": ["funkwhale/api:develop"],
                    "labels": {
                        **common_docker_labels,
                        "org.opencontainers.image.version": "develop",
                        "org.opencontainers.image.created": "2023-01-31T13:31:13+01:00",
                        "org.opencontainers.image.revision": "de206ac559a171b68fb894b2d61db298fc386705",
                    },
                }
            }
        },
        "env_output": [
            "BUILD_COMMIT_TAG=",
            "BUILD_COMMIT_BRANCH=develop",
            "BUILD_COMMIT_SHA=de206ac559a171b68fb894b2d61db298fc386705",
            "BUILD_COMMIT_TIMESTAMP=2023-01-31T13:31:13+01:00",
            "BUILD_COMMIT_REF_NAME=develop",
            "BUILD_VERSION=1.7.2-dev+de206ac",
            "BUILD_TAGS=develop",
            "BUILD_LATEST=false",
        ],
    },
    {  # A release tag
        "environ": {
            "CI": "true",
            "CI_COMMIT_TAG": "1.2.9",
            "CI_COMMIT_BRANCH": "",
            "CI_COMMIT_SHA": "817c8fbcaa0706ccc9b724da8546f44ba7d2d841",
            "CI_COMMIT_TIMESTAMP": "2022-11-25T17:59:23+01:00",
            "CI_COMMIT_REF_NAME": "1.2.9",
        },
        "metadata": {
            "commit_tag": "1.2.9",
            "commit_branch": "",
            "commit_sha": "817c8fbcaa0706ccc9b724da8546f44ba7d2d841",
            "commit_timestamp": "2022-11-25T17:59:23+01:00",
            "commit_ref_name": "1.2.9",
            "version": "1.2.9",
            "tags": ["1.2.9", "1.2", "1", "latest"],
            "latest": True,
        },
        "bake_output": {
            "target": {
                "api": {
                    "tags": [
                        "funkwhale/api:1.2.9",
                        "funkwhale/api:1.2",
                        "funkwhale/api:1",
                        "funkwhale/api:latest",
                    ],
                    "labels": {
                        **common_docker_labels,
                        "org.opencontainers.image.version": "1.2.9",
                        "org.opencontainers.image.created": "2022-11-25T17:59:23+01:00",
                        "org.opencontainers.image.revision": "817c8fbcaa0706ccc9b724da8546f44ba7d2d841",
                    },
                }
            }
        },
        "env_output": [
            "BUILD_COMMIT_TAG=1.2.9",
            "BUILD_COMMIT_BRANCH=",
            "BUILD_COMMIT_SHA=817c8fbcaa0706ccc9b724da8546f44ba7d2d841",
            "BUILD_COMMIT_TIMESTAMP=2022-11-25T17:59:23+01:00",
            "BUILD_COMMIT_REF_NAME=1.2.9",
            "BUILD_VERSION=1.2.9",
            "BUILD_TAGS=1.2.9,1.2,1,latest",
            "BUILD_LATEST=true",
        ],
    },
    {  # A prerelease tag
        "environ": {
            "CI": "true",
            "CI_COMMIT_TAG": "1.3.0-rc3",
            "CI_COMMIT_BRANCH": "",
            "CI_COMMIT_SHA": "e04a1b188d3f463e7b3e2484578d63d754b09b9d",
            "CI_COMMIT_TIMESTAMP": "2023-01-23T14:24:46+01:00",
            "CI_COMMIT_REF_NAME": "1.3.0-rc3",
        },
        "metadata": {
            "commit_tag": "1.3.0-rc3",
            "commit_branch": "",
            "commit_sha": "e04a1b188d3f463e7b3e2484578d63d754b09b9d",
            "commit_timestamp": "2023-01-23T14:24:46+01:00",
            "commit_ref_name": "1.3.0-rc3",
            "version": "1.3.0-rc3",
            "tags": ["1.3.0-rc3"],
            "latest": False,
        },
        "bake_output": {
            "target": {
                "api": {
                    "tags": ["funkwhale/api:1.3.0-rc3"],
                    "labels": {
                        **common_docker_labels,
                        "org.opencontainers.image.version": "1.3.0-rc3",
                        "org.opencontainers.image.created": "2023-01-23T14:24:46+01:00",
                        "org.opencontainers.image.revision": "e04a1b188d3f463e7b3e2484578d63d754b09b9d",
                    },
                }
            }
        },
        "env_output": [
            "BUILD_COMMIT_TAG=1.3.0-rc3",
            "BUILD_COMMIT_BRANCH=",
            "BUILD_COMMIT_SHA=e04a1b188d3f463e7b3e2484578d63d754b09b9d",
            "BUILD_COMMIT_TIMESTAMP=2023-01-23T14:24:46+01:00",
            "BUILD_COMMIT_REF_NAME=1.3.0-rc3",
            "BUILD_VERSION=1.3.0-rc3",
            "BUILD_TAGS=1.3.0-rc3",
            "BUILD_LATEST=false",
        ],
    },
]


@pytest.mark.parametrize(
    "environ, expected_metadata, expected_bake_output, expected_env_output",
    map(
        lambda i: (i["environ"], i["metadata"], i["bake_output"], i["env_output"]),
        test_cases,
    ),
)
def test_extract_metadata(
    environ,
    expected_metadata,
    expected_bake_output,
    expected_env_output,
):
    with mock.patch("build_metadata.latest_tag_on_branch") as latest_tag_on_branch_mock:
        latest_tag_on_branch_mock.return_value = "1.7.2-rc5"
        with mock.patch.dict("os.environ", environ, clear=True):
            found_metadata = extract_metadata()

    assert found_metadata == expected_metadata

    found_bake_output = bake_output(
        metadata=found_metadata,
        target="api",
        images=["funkwhale/api"],
    )
    assert found_bake_output == expected_bake_output

    found_env_output = env_output(metadata=found_metadata)
    assert found_env_output == expected_env_output
