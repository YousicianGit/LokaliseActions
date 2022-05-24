#!/bin/bash
set -e

if [ -z "$LOKALISE_TOKEN" ]; then
    if [ "$CI" = "true" ]; then
        print_error_and_exit "LOKALISE_TOKEN was not set"
    elif [ -f "$HOME/.lokalise" ]; then
        LOKALISE_TOKEN=$(cat "$HOME/.lokalise")
    else
        print_error_and_exit "LOKALISE_TOKEN was not set. You can create a file at ~/.lokalise with your token in it to retrieve it automatically."
    fi
fi

if [ -z "$LOKALISE_PROJECT" ]; then
    if [ -f ".lokalise" ]; then
        LOKALISE_PROJECT=$(cat .lokalise)
    else
        print_error_and_exit "LOKALISE_PROJECT was not set. You can create a .lokalise file in the repository to retrieve it automatically."
    fi
fi

# Set Bash platform script is running on (mac/windows/linux).
# BSD (Mac) and GNU (Linux & Git for Windows) core-utils implementations
# have some differences for example in the available command line options.
case "$(uname -s)" in
    "Darwin")
        BASH_PLATFORM="mac"
        ;;
    "MINGW"*)
        BASH_PLATFORM="windows"
        ;;
    *)
        BASH_PLATFORM="linux"
        ;;
esac

# Print an error and exit the program. If no error is provided then $USAGE is printed.
print_usage_and_exit() {
    if [ $# -eq 1 ]; then
        print_red "ERROR: $1"
    fi
    echo "$USAGE"
    exit 1
}

# Print a message with magenta color since bold does not work well in Jenkins log
print_magenta() {
    printf "\e[1;49;35m${1}\e[0m\n"
}

# Print a message with red color
print_red() {
    printf "\e[1;49;31m${1}\e[0m\n"
}

# Print a message with green color
print_green() {
    printf "\e[1;49;32m${1}\e[0m\n"
}

# Print a message with yellow color
print_yellow() {
    printf "\e[1;49;33m${1}\e[0m\n"
}

# Print an error and exit the program
print_error_and_exit() {
    print_red "ERROR: ${1}"
    exit "${2:-1}"
}

# Returns 1 when the $BRANCH exists.
branch_exists() {
    if lokalise2 branch list --project-id "$LOKALISE_PROJECT" --token "$LOKALISE_TOKEN" | grep -q "\"name\": \"$BRANCH\""; then
        # Grep returns 1 when there is no match
        return 0
    else
        return 1
    fi
}

sed_replace() {
    if [ "$BASH_PLATFORM" = "mac" ]; then
        # macOS uses BSD sed, expecting a space between '-i' and the extension
        sed -i "" "$@"
    else
        # Linux and Windows use GNU sed, expecting no space between '-i' and the extension
        sed -i "$@"
    fi
}
