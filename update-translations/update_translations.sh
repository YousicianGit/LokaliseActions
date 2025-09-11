#!/bin/bash
set -e

USAGE="Usage: update_translations.sh [FOLDER] [OPTIONS]

Update translations in a folder from Lokalise.

OPTIONS: All options are optional
    --help
        Display these instructions.

    --branch <BRANCH>
        Branched resource to pull the translations from. It not provided, uses main resource.

    --unreviewed
        Include unreviewed translations. This should be only used for testing. If not provided, only reviewed translations will be included.

    --stage-changes
        Stage changes to translation files. Used by CI to commit changes.

    --async
        Use async mode for file download. Required for projects with >= 10,000 key-language pairs."


# Import common functions
DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=./../common.sh
source "$DIR/../common.sh"

init_options() {
    LOCALIZATION_FOLDER=$1
    shift

    BRANCH=""
    INCLUDE_UNREVIEWED=false
    STAGE_CHANGES=false
    PROJECT_PATH=""
    USE_ASYNC=false

    while [ $# -gt 0 ]; do
        case "$1" in
            --help)
                echo "$USAGE"
                exit 1
                ;;
            --branch)
                BRANCH=$2
                shift
                ;;
            --unreviewed)
                INCLUDE_UNREVIEWED=true
                ;;
            --stage-changes)
                STAGE_CHANGES=true
                ;;
            --async)
                USE_ASYNC=true
                ;;
        esac
        shift
    done
}

download_lokalise() {
    if [ "$INCLUDE_UNREVIEWED" = true ]; then
        local mode="translated"
    else
        local mode="last_reviewed_only"
    fi

    local async_flag=""
    if [ "$USE_ASYNC" = true ]; then
        async_flag="--async"
    fi

    local command="lokalise2 file download --format po --unzip-to '$LOCALIZATION_FOLDER' --directory-prefix '%LANG_ISO%' --token '$LOKALISE_TOKEN' --filter-data $mode $async_flag --project-id $LOKALISE_PROJECT"

    if [ -n "$BRANCH" ]; then
        command="$command:$BRANCH"
    fi

    eval "$command"
}

init_options "$@"
download_lokalise

if [ "$STAGE_CHANGES" = true ]; then
    git add "$LOCALIZATION_FOLDER"
fi