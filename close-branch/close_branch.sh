#!/bin/bash
set -e

USAGE="Usage: close_branch.sh [MERGED] [SOURCE BRANCH] [TARGET_BRANCH]

This should called from a GitHub Action whenever a branch is closed.
It works without the Lokalise CLI installed."

# Import common functions
DIR=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)
# shellcheck source=./../common.sh
source "$DIR/../common.sh"

if [ $# -ne 3 ]; then
    print_usage_and_exit "Please provide all three arguments"
fi

MERGED=$1
SOURCE_BRANCH=$2
TARGET_BRANCH=$3

if [ "$SOURCE_BRANCH" = "master" ]; then
    print_error_and_exit "The master branch cannot be closed"
fi

print_green "Getting ${SOURCE_BRANCH} branch..."
SOURCE_BRANCH_ID=$(lokalise2 branch list --project-id "$LOKALISE_PROJECT" --token "$LOKALISE_TOKEN" |
    jq " .branches[] | select(.name == \"$SOURCE_BRANCH\") | .branch_id")

if [ -z "$SOURCE_BRANCH_ID" ]; then
    print_magenta "Branch $SOURCE_BRANCH does not exist on Lokalise for this project. Nothing to do."
    exit 0
fi

if [ "$MERGED" = "true" ]; then
    # If the branch was merged then we find the target branch and merge into it
    print_green "Getting ${TARGET_BRANCH} branch..."
    TARGET_BRANCH_ID=$(lokalise2 branch list --project-id "$LOKALISE_PROJECT" --token "$LOKALISE_TOKEN" |
        jq " .branches[] | select(.name == \"$TARGET_BRANCH\") | .branch_id")

    if [ -z "$TARGET_BRANCH_ID" ]; then
        print_yellow "Branch $TARGET_BRANCH does not exist on Lokalise for this project. Creating it."
        TARGET_BRANCH_ID=$(lokalise2 branch create --name "$TARGET_BRANCH" --project-id "$LOKALISE_PROJECT" --token "$LOKALISE_TOKEN" |
            jq .branch.branch_id)
    fi

    if [ "$TARGET_BRANCH" = "master" ]; then
        print_green "Merging ${TARGET_BRANCH} into ${SOURCE_BRANCH} to ensure no strings to missing..."
        MERGE_PAYLOAD="{\"force_conflict_resolve_using\":\"source\", \"target_branch_id\": $SOURCE_BRANCH_ID}"
        curl --request POST --fail \
            --url https://api.lokalise.com/api2/projects/${LOKALISE_PROJECT}/branches/$TARGET_BRANCH_ID/merge \
            --header 'content-type: application/json' \
            --header "x-api-token: $LOKALISE_TOKEN" \
            --data "$MERGE_PAYLOAD"
    fi

    print_green "Merging ${SOURCE_BRANCH} into ${TARGET_BRANCH}..."
    MERGE_PAYLOAD="{\"force_conflict_resolve_using\":\"target\", \"target_branch_id\": $TARGET_BRANCH_ID}"
    curl --request POST --fail \
        --url https://api.lokalise.com/api2/projects/${LOKALISE_PROJECT}/branches/$SOURCE_BRANCH_ID/merge \
        --header 'content-type: application/json' \
        --header "x-api-token: $LOKALISE_TOKEN" \
        --data "$MERGE_PAYLOAD"
fi

# Finally we delete the branch, even if it was not merged
print_green "Deleting ${SOURCE_BRANCH}..."
lokalise2 branch delete --branch-id "$SOURCE_BRANCH_ID" --project-id "$LOKALISE_PROJECT" --token "$LOKALISE_TOKEN"
