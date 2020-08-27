#!/usr/bin/env bash

# WARNING: DO NOT EDIT!
#
# This file was generated by plugin_template, and is managed by it. Please use
# './plugin-template --travis pulp_rpm' to update this file.
#
# For more info visit https://github.com/pulp/plugin_template

set -euv

if [ "$TEST" = "docs" ]; then
  pip install -r ../pulpcore/doc_requirements.txt
  pip install -r doc_requirements.txt
fi

pip install -r functest_requirements.txt

cd .travis

# Although the tag name is not used outside of this script, we might use it
# later. And it is nice to have a friendly identifier for it.
# So we use the branch preferably, but need to replace the "/" with the valid
# character "_" .
#
# Note that there are lots of other valid git branch name special characters
# that are invalid in image tag names. To try to convert them, this would be a
# starting point:
# https://stackoverflow.com/a/50687120
#
# If we are on a tag
if [ -n "$TRAVIS_TAG" ]; then
  TAG=$(echo $TRAVIS_TAG | tr / _)
# If we are on a PR
elif [ -n "$TRAVIS_PULL_REQUEST_BRANCH" ]; then
  TAG=$(echo $TRAVIS_PULL_REQUEST_BRANCH | tr / _)
# For push builds and hopefully cron builds
elif [ -n "$TRAVIS_BRANCH" ]; then
  TAG=$(echo $TRAVIS_BRANCH | tr / _)
  if [ "${TAG}" = "master" ]; then
    TAG=latest
  fi
else
  # Fallback
  TAG=$(git rev-parse --abbrev-ref HEAD | tr / _)
fi
if [ -n "$TRAVIS_TAG" ]; then
  # Install the plugin only and use published PyPI packages for the rest
  # Quoting ${TAG} ensures Ansible casts the tag as a string.
  cat >> vars/main.yaml << VARSYAML
image:
  name: pulp
  tag: "${TAG}"
plugins:
  - name: pulpcore
    source: pulpcore>=3.6,<3.7
  - name: pulp_rpm
    source: ./pulp_rpm
services:
  - name: pulp
    image: "pulp:${TAG}"
    volumes:
      - ./settings:/etc/pulp
VARSYAML
else
  cat >> vars/main.yaml << VARSYAML
image:
  name: pulp
  tag: "${TAG}"
plugins:
  - name: pulpcore
    source: ./pulpcore
  - name: pulp_rpm
    source: ./pulp_rpm
services:
  - name: pulp
    image: "pulp:${TAG}"
    volumes:
      - ./settings:/etc/pulp
VARSYAML
fi

cat >> vars/main.yaml << VARSYAML
pulp_settings: {"allowed_export_paths": ["/tmp"], "allowed_import_paths": ["/tmp"]}
VARSYAML

if [[ "$TEST" == "pulp" || "$TEST" == "performance" || "$TEST" == "s3" ]]; then
  sed -i -e '/^services:/a \
  - name: pulp-fixtures\
    image: docker.io/pulp/pulp-fixtures:latest\
    env: {BASE_URL: "http://pulp-fixtures"}' vars/main.yaml
fi

if [ "$TEST" = "s3" ]; then
  export MINIO_ACCESS_KEY=AKIAIT2Z5TDYPX3ARJBA
  export MINIO_SECRET_KEY=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
  sed -i -e '/^services:/a \
  - name: minio\
    image: minio/minio\
    env:\
      MINIO_ACCESS_KEY: "'$MINIO_ACCESS_KEY'"\
      MINIO_SECRET_KEY: "'$MINIO_SECRET_KEY'"\
    command: "server /data"' vars/main.yaml
  sed -i -e '$a s3_test: true\
minio_access_key: "'$MINIO_ACCESS_KEY'"\
minio_secret_key: "'$MINIO_SECRET_KEY'"' vars/main.yaml
fi

ansible-playbook build_container.yaml
ansible-playbook start_container.yaml
