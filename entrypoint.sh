#!/usr/bin/env bash

set -euo pipefail

echo "::group::stylelint-changed-files"

if [[ -n $INPUT_PATH ]]; then
  REPO_DIR="$GITHUB_WORKSPACE/$INPUT_PATH"

  echo "Resolving repository path: $REPO_DIR"
  if [[ ! -d "$REPO_DIR" ]]; then
    echo "::error::Invalid repository path: $REPO_DIR"
    echo "::endgroup::"
    exit 1
  fi
  cd "$REPO_DIR"
fi

TEMP_DIR=$(mktemp -d)
RD_JSON_FILE="$TEMP_DIR/rd.json"
STYLELINT_FORMATTER="$TEMP_DIR/formatter.cjs"

if [[ "$INPUT_SKIP_ANNOTATIONS" != "true" ]]; then
  curl -sf -o "$STYLELINT_FORMATTER" https://raw.githubusercontent.com/reviewdog/action-stylelint/master/stylelint-formatter-rdjson/index.js
  # shellcheck disable=SC2034
  export REVIEWDOG_GITHUB_API_TOKEN=$INPUT_TOKEN
fi

EXTRA_ARGS="--no-warn-ignored $INPUT_EXTRA_ARGS"
CONFIG_ARG=""

if [[ -n "$INPUT_CONFIG_PATH" ]]; then
  CONFIG_ARG="--config=${INPUT_CONFIG_PATH}"
fi

if [[ "$INPUT_ALL_FILES" == "true" ]]; then
  echo "Running Stylelint on all files..."
  if [[ "$INPUT_SKIP_ANNOTATIONS" == "true" ]]; then
    echo "Skipping annotations..."
    # shellcheck disable=SC2086
    npx stylelint ${CONFIG_ARG} ${EXTRA_ARGS} && exit_status=$? || exit_status=$?
  else
    # shellcheck disable=SC2086
    npx stylelint ${CONFIG_ARG} ${EXTRA_ARGS} -f="${STYLELINT_FORMATTER}" . > "$RD_JSON_FILE" && exit_status=$? || exit_status=$?
  fi
  
  if [[ "$INPUT_SKIP_ANNOTATIONS" != "true" ]]; then
    reviewdog -f=rdjson \
      -name=stylelint \
      -reporter="${INPUT_REPORTER}" \
      -filter-mode="nofilter" \
      -fail-on-error="${INPUT_FAIL_ON_ERROR}" \
      -level="${INPUT_LEVEL}" < "$RD_JSON_FILE" || true
  fi

  if [[ $exit_status -ne 0 ]]; then
    echo "::error::Error running stylelint."
    rm -rf "$TEMP_DIR"
    echo "::endgroup::"
    exit 1;
  fi
else
  if [[ -n "${INPUT_CHANGED_FILES[*]}" ]]; then
      echo "Running Stylelint on changed files..."
      if [[ "$INPUT_SKIP_ANNOTATIONS" == "true" ]]; then
        echo "Skipping annotations..."
        # shellcheck disable=SC2086
        npx stylelint ${CONFIG_ARG} ${EXTRA_ARGS} ${INPUT_CHANGED_FILES} && exit_status=$? || exit_status=$?
      else
        # shellcheck disable=SC2086
        npx stylelint ${CONFIG_ARG} ${EXTRA_ARGS} -f="${STYLELINT_FORMATTER}" ${INPUT_CHANGED_FILES} > "$RD_JSON_FILE" && exit_status=$? || exit_status=$?
      fi
      
      if [[ "$INPUT_SKIP_ANNOTATIONS" != "true" ]]; then
        reviewdog -f=rdjson \
          -name=stylelint \
          -reporter="${INPUT_REPORTER}" \
          -filter-mode="nofilter" \
          -fail-on-error="${INPUT_FAIL_ON_ERROR}" \
          -level="${INPUT_LEVEL}" < "$RD_JSON_FILE" || true
      fi

      if [[ $exit_status -ne 0 ]]; then
        echo "::error::Error running stylelint."
        rm -rf "$TEMP_DIR"
        echo "::endgroup::"
        exit 1;
      fi
  else
      echo "Skipping: No files to lint"
  fi
fi

rm -rf "$TEMP_DIR"

echo "::endgroup::"
