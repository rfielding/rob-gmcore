import logging
import os

LOGGER = logging.getLogger(__name__)


class Config:
    def __init__(self, args):
        self.src_generic = args.src_generic
        self.dest_generic = args.dest_generic
        self.src_oci = args.src_oci
        self.dest_oci = args.dest_oci
        self.git_tag = args.git_tag
        if self.git_tag == 'None':
            self.git_tag = "latest"
        if args.action == "promote":
            self.artifactory_url = args.artifactory_url
            self.artifactory_user = args.artifactory_user
            self.artifactory_password = args.artifactory_password
            self.dry_run = args.dry_run

        if os.environ.get('GENERIC_SRC') is not None:
            self.src_generic = os.environ.get('GENERIC_SRC')
        if os.environ.get('GENERIC_DEST') is not None:
            self.dest_generic = os.environ.get('GENERIC_DEST')
        if os.environ.get('OCI_SRC') is not None:
            self.src_oci = os.environ.get('OCI_SRC')
        if os.environ.get('OCI_DEST') is not None:
            self.dest_oci = os.environ.get('OCI_DEST')
        if os.environ.get('GIT_TAG') is not None:
            self.GIT_TAG = os.environ.get('GIT_TAG')
        if args.action == "promote":
            if os.environ.get('BUILDKITE_ARTIFACTORY_URL') is not None:
                self.artifactory_url = os.environ.get('BUILDKITE_ARTIFACTORY_URL')
            if os.environ.get('BUILDKITE_ARTIFACTORY_USER') is not None:
                self.artifactory_user = os.environ.get('BUILDKITE_ARTIFACTORY_USER')
            if os.environ.get('BUILDKITE_ARTIFACTORY_PASSWORD') is not None:
                self.artifactory_password = os.environ.get('BUILDKITE_ARTIFACTORY_PASSWORD')
            if os.environ.get('DRY_RUN') is not None:
                self.dry_run = os.environ.get('DRY_RUN')

        self.validate(args)

    def validate(self, args):
        if args.action == 'promote':
            for x in [self.artifactory_url, self.artifactory_password, self.artifactory_user]:
                if x == 'None':
                    raise Exception(
                        "Artifactory Credentials unset:\n Set environment variables:\nARTIFACTORY_URL, ARTIFACTORY_URL, ARTIFACTORY_PASSWORD\n or use cli flags")
