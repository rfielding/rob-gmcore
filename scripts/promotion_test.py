#!/usr/bin/env python3

import logging

from pyartifactory.models.artifact import (
    ArtifactListResponse,
)

from promotion import *

LOGGER = logging.getLogger()

handler = logging.StreamHandler(sys.stdout)
if os.getenv('DEBUG'):
    LOGGER.setLevel(logging.DEBUG)
    handler.setLevel(logging.DEBUG)
else:
    LOGGER.setLevel(logging.INFO)
    handler.setLevel(logging.INFO)

handler.setFormatter(logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s'))
LOGGER.addHandler(handler)


def test_filter_artifact_list_generic():
    LIST_ARTIFACTS_RESPONSE = {
        "uri": "https://greymatter.jfrog.io/artifactory/api/storage/dev-generic/greymatter-catalog",
        "created": "2019-06-06T13:19:14.514Z",
        "files": [
            {
                "uri": "/greymatter-catalog_009a70a9c2fdc070a27c8cba87ea098d0697101f_linux_amd64.tar.gz",
                "size": 8417997,
                "lastModified": "2019-06-06T13:19:14.514Z",
                "folder": False,
                "sha1": "1b7bbb12e2c3db025d3c901d1d1ad8814e20047b",
                "sha2": "3839bf36deecf6284995b1e8b92c62e20c812cb85cf66d82cf449a078c877d26",

            },
            {
                "uri": "/greymatter-catalog_latest_linux_amd64.tar.gz",
                "size": 253207,
                "lastModified": "2019-06-06T13:19:14.514Z",
                "folder": False,
                "sha1": "962c287c760e03b03c17eb920f5358d05f44dd3b",
                "sha2": "962c287c760e03b03c1234520f5358d05f44dd3b",
            },
            {
                "uri": "/greymatter-catalog_3.0.12_linux_amd64.tar.gz",
                "size": 253100,
                "lastModified": "2019-06-06T13:19:14.514Z",
                "folder": False,
                "sha1": "542c287c760e03b03c17eb920f5358d05f44dd3b",
                "sha2": "3839bf36deecf6284995b1e8b92c62e20c812cb85c145682cf449a078c877d26",
            },
            {
                "uri": "/greymatter-catalog_3.0.12_darwin_arm64.tar.gz",
                "size": 253100,
                "lastModified": "2019-06-06T13:19:14.514Z",
                "folder": False,
                "sha1": "542c287c760e03b03c17eb920f5358d05f44dd3b",
                "sha2": "3839bf36deecf6284995b1e8b92c62e20c812cb85c145682cf449a078c877d26",
            },
        ],
    }
    LIST_ARTIFACTS = ArtifactListResponse(**LIST_ARTIFACTS_RESPONSE)
    resp = filter_artifact_list("generic", LIST_ARTIFACTS, "catalog", "3.0.12")
    assert resp == ["greymatter-catalog_3.0.12_linux_amd64.tar.gz", "greymatter-catalog_3.0.12_darwin_arm64.tar.gz"]


def test_filter_artifact_list_oci():
    LIST_ARTIFACTS_RESPONSE = {
        "uri": "https://greymatter.jfrog.io/artifactory/api/storage/dev-oci/greymatter-cli",
        "created": "2019-06-06T13:19:14.514Z",
        "files": [
            {
                "uri": "/release-4.7.1",
                "size": 8417997,
                "lastModified": "2019-06-06T13:19:14.514Z",
                "folder": False,

            },
            {
                "uri": "/latest",
                "size": 253207,
                "lastModified": "2019-06-06T13:19:14.514Z",
                "folder": True,
            },
            {
                "uri": "/sc-33858-add-external-kubernetes-secret-resolver",
                "size": -1,
                "lastModified": "2019-06-06T13:19:14.514Z",
                "folder": True,
            },
            {
                "uri": "/4.7.7",
                "size": -1,
                "lastModified": "2019-06-06T13:19:14.514Z",
                "folder": True,

            },
        ],
    }
    LIST_ARTIFACTS = ArtifactListResponse(**LIST_ARTIFACTS_RESPONSE)
    resp = filter_artifact_list("oci", LIST_ARTIFACTS, "cli", "4.7.7")
    assert resp == ["4.7.7"]


def test_sub_map_for_download_script():
    component_version_dict = {
        'cli': '9.9.9',
        'operator': '1.16.4',
        'vector': '0.24.0-debian',
        'observables': '1.1.7',
        'keycloak': '19.0.3',
        'keycloak-postgres': '15.0',
        'proxy': '1.8.6',
        'catalog': '3.0.12',
        'dashboard': '6.0.10',
        'control': '1.8.10',
        'control-api': '1.8.10',
        'redis': '7.0.8',
        'prometheus': 'v2.40.1',
        'core': 'latest'
    }
    ds = sub_map_for_download_script(component_version_dict)
    LOGGER.info(ds)
    assert ds.get("<CLI_VERSION>") == "9.9.9"
    assert ds.get("<OPERATOR_VERSION>") == "1.16.4"
    assert ds.get("<OBSERVABLES_VERSION>") == "1.1.7"
    assert ds.get("<PROXY_VERSION>") == "1.8.6"
    assert ds.get("<CATALOG_VERSION>") == "3.0.12"
    assert ds.get("<DASHBOARD_VERSION>") == "6.0.10"
    assert ds.get("<CONTROL_VERSION>") == "1.8.10"
    assert ds.get("<CONTROL_API_VERSION>") == "1.8.10"
    assert ds.get("<CORE_VERSION>") == "latest"
