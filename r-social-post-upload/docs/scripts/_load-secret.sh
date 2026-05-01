#!/usr/bin/env bash
# Walk up from this file to find <repo>/.gsai/secret and source it.
# Lets scripts pick up UPLOAD_POST_API_KEY without the caller pre-exporting it.
# Sourced (not executed) by each script before the key check.

if [ -z "${UPLOAD_POST_API_KEY:-}" ]; then
  _ls_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [ "$_ls_dir" != "/" ]; do
    if [ -f "$_ls_dir/.gsai/secret" ]; then
      # shellcheck disable=SC1090
      source "$_ls_dir/.gsai/secret"
      break
    fi
    _ls_dir="$(dirname "$_ls_dir")"
  done
  unset _ls_dir
fi
