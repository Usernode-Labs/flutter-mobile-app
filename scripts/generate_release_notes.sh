#!/bin/bash
# Generate Release Notes from Git Commits and PRs

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# Get the last tag or first commit if no tags
get_last_tag() {
    git describe --tags --abbrev=0 2>/dev/null || git rev-list --max-parents=0 HEAD
}

# Parse commit type from conventional commits
parse_commit_type() {
    local commit_msg="$1"

    if [[ $commit_msg =~ ^feat(\(.+\))?:.* ]]; then
        echo "feature"
    elif [[ $commit_msg =~ ^fix(\(.+\))?:.* ]]; then
        echo "fix"
    elif [[ $commit_msg =~ ^docs(\(.+\))?:.* ]]; then
        echo "docs"
    elif [[ $commit_msg =~ ^style(\(.+\))?:.* ]]; then
        echo "style"
    elif [[ $commit_msg =~ ^refactor(\(.+\))?:.* ]]; then
        echo "refactor"
    elif [[ $commit_msg =~ ^perf(\(.+\))?:.* ]]; then
        echo "performance"
    elif [[ $commit_msg =~ ^test(\(.+\))?:.* ]]; then
        echo "test"
    elif [[ $commit_msg =~ ^chore(\(.+\))?:.* ]]; then
        echo "chore"
    else
        echo "other"
    fi
}

# Extract commit message (removing type prefix)
extract_message() {
    local commit_msg="$1"

    # Remove conventional commit prefix
    if [[ $commit_msg =~ ^[a-z]+(\(.+\))?:\ (.+)$ ]]; then
        echo "${BASH_REMATCH[2]}"
    else
        echo "$commit_msg"
    fi
}

# Generate release notes
generate_release_notes() {
    local from_ref="${1:-$(get_last_tag)}"
    local to_ref="${2:-HEAD}"
    local format="${3:-markdown}"

    print_info "Generating release notes from $from_ref to $to_ref"

    # Arrays to store categorized commits
    declare -a features=()
    declare -a fixes=()
    declare -a performance=()
    declare -a refactors=()
    declare -a other=()

    # Get commits
    while IFS= read -r commit_line; do
        # Parse commit hash and message
        commit_hash=$(echo "$commit_line" | cut -d'|' -f1)
        commit_msg=$(echo "$commit_line" | cut -d'|' -f2-)

        # Skip merge commits and automated commits
        if [[ $commit_msg =~ ^Merge || $commit_msg =~ ^Bump\ (iOS|Android) ]]; then
            continue
        fi

        commit_type=$(parse_commit_type "$commit_msg")
        message=$(extract_message "$commit_msg")

        # Categorize commits
        case "$commit_type" in
            feature)
                features+=("- $message ($commit_hash)")
                ;;
            fix)
                fixes+=("- $message ($commit_hash)")
                ;;
            performance)
                performance+=("- $message ($commit_hash)")
                ;;
            refactor)
                refactors+=("- $message ($commit_hash)")
                ;;
            *)
                if [[ "$commit_type" != "chore" && "$commit_type" != "docs" && "$commit_type" != "test" ]]; then
                    other+=("- $message ($commit_hash)")
                fi
                ;;
        esac
    done < <(git log --pretty=format:"%h|%s" "$from_ref..$to_ref")

    # Output release notes
    if [ "$format" == "markdown" ]; then
        echo "## Release Notes"
        echo ""

        if [ ${#features[@]} -gt 0 ]; then
            echo "### ✨ New Features"
            printf '%s\n' "${features[@]}"
            echo ""
        fi

        if [ ${#fixes[@]} -gt 0 ]; then
            echo "### 🐛 Bug Fixes"
            printf '%s\n' "${fixes[@]}"
            echo ""
        fi

        if [ ${#performance[@]} -gt 0 ]; then
            echo "### ⚡ Performance Improvements"
            printf '%s\n' "${performance[@]}"
            echo ""
        fi

        if [ ${#refactors[@]} -gt 0 ]; then
            echo "### ♻️ Code Refactoring"
            printf '%s\n' "${refactors[@]}"
            echo ""
        fi

        if [ ${#other[@]} -gt 0 ]; then
            echo "### 🔧 Other Changes"
            printf '%s\n' "${other[@]}"
            echo ""
        fi

        if [ ${#features[@]} -eq 0 ] && [ ${#fixes[@]} -eq 0 ] && [ ${#performance[@]} -eq 0 ] && [ ${#refactors[@]} -eq 0 ] && [ ${#other[@]} -eq 0 ]; then
            echo "No notable changes in this release."
            echo ""
        fi

    elif [ "$format" == "plain" ]; then
        # Plain text format for store submissions
        [ ${#features[@]} -gt 0 ] && printf '%s\n' "${features[@]}" | sed 's/^- /• /'
        [ ${#fixes[@]} -gt 0 ] && printf '%s\n' "${fixes[@]}" | sed 's/^- /• /'
        [ ${#performance[@]} -gt 0 ] && printf '%s\n' "${performance[@]}" | sed 's/^- /• /'
        [ ${#refactors[@]} -gt 0 ] && printf '%s\n' "${refactors[@]}" | sed 's/^- /• /'
        [ ${#other[@]} -gt 0 ] && printf '%s\n' "${other[@]}" | sed 's/^- /• /'
    fi
}

# Main command handling
case "${1:-}" in
    generate)
        from_ref="${2:-}"
        to_ref="${3:-HEAD}"
        format="${4:-markdown}"
        generate_release_notes "$from_ref" "$to_ref" "$format"
        ;;
    *)
        echo "Usage: $0 generate [from_ref] [to_ref] [format]"
        echo ""
        echo "Arguments:"
        echo "  from_ref  - Starting git reference (default: last tag)"
        echo "  to_ref    - Ending git reference (default: HEAD)"
        echo "  format    - Output format: markdown or plain (default: markdown)"
        echo ""
        echo "Example:"
        echo "  $0 generate v1.0.0 HEAD markdown"
        exit 1
        ;;
esac
