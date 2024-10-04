#!/bin/bash
set -e

USAGE="Usage: upload_strings.sh [PATH TO PO FILE] [BRANCH]"

# Import common functions
DIR=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)
# shellcheck source=./../common.sh
source "$DIR/../common.sh"

if [ $# -ne 2 ]; then
    print_usage_and_exit "Please provide both parameters"
fi

LOCALIZATION_FILE=$1
BRANCH=$2

if [ ! -f "$LOCALIZATION_FILE" ]; then
    print_error_and_exit "Could not find file at $LOCALIZATION_FILE"
fi

LOCALIZATION_FOLDER=$(dirname "$LOCALIZATION_FILE")
DOWNLOADED_PATH="$LOCALIZATION_FOLDER/Lokalise/$(basename "$LOCALIZATION_FILE")"

print_diff() {
    # Pull current resource from Lokalise. If the branch exists then pull that, otherwise pull default branch.
    local command="lokalise2 file download --format po --filter-langs en --unzip-to '$LOCALIZATION_FOLDER' --directory-prefix Lokalise --token '$LOKALISE_TOKEN' --project-id $LOKALISE_PROJECT"

    if [ -n "$BRANCH" ] && branch_exists; then
        command="$command:$BRANCH"
    fi

    eval "$command"

    # The resource pulled from Lokalise has all the strings in our catalog.
    # We need to filter it down to only contain strings the app actually uses.
    msgcomm --output="$DOWNLOADED_PATH" "$LOCALIZATION_FILE" "$DOWNLOADED_PATH" || echo "msgcomm can fail when plurals are added or removed for strings"

    # Clean up both files. This can fail sometimes with the following error:
    # msgfilter: write to echo subprocess failed: Broken pipe
    for i in {1..5}; do
        msgfilter --input="$DOWNLOADED_PATH" --output="$DOWNLOADED_PATH" --keep-header --sort-output && break ||
            print_yellow "Failed to run msgfilter"
    done
    sed_replace "/^#/d" "$DOWNLOADED_PATH"

    CLEAN_PO_PATH="$LOCALIZATION_FILE.clean"
    for i in {1..5}; do
        msgfilter --input="$LOCALIZATION_FILE" --output="$CLEAN_PO_PATH" --keep-header --sort-output && break ||
            print_yellow "Failed to run msgfilter"
    done
    sed_replace "/^#/d" "$CLEAN_PO_PATH"

    print_green "Printing diff of resource files..."
    git --no-pager diff --color --no-index --unified=0 "$DOWNLOADED_PATH" "$CLEAN_PO_PATH" && NO_CHANGES=true || true
}

upload() {
    print_green "Uploading resource files to Lokalise..."
    if [ -n "$BRANCH" ]; then
        if ! branch_exists; then
            if [ "$NO_CHANGES" = true ]; then
                print_magenta "No changes found and the branch does not exist yet. Skipping upload."
                exit 0
            fi

            lokalise2 branch create --name "$BRANCH" --project-id "$LOKALISE_PROJECT" --token "$LOKALISE_TOKEN"
        fi

        lokalise2 file upload --file "$LOCALIZATION_FILE" --lang-iso en --project-id "$LOKALISE_PROJECT:$BRANCH" --token "$LOKALISE_TOKEN" --cleanup-mode --keys-to-values --convert-placeholders=false --replace-modified
    else
        lokalise2 file upload --file "$LOCALIZATION_FILE" --lang-iso en --project-id "$LOKALISE_PROJECT" --token "$LOKALISE_TOKEN" --keys-to-values --convert-placeholders=false --replace-modified
    fi
}

print_diff
upload