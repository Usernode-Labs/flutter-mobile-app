#!/bin/bash
# Version Manager Script for Usernode CI/CD
# Uses pubspec.yaml as the single source of truth for version and build numbers

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PUBSPEC_FILE="$PROJECT_ROOT/pubspec.yaml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Check if pubspec.yaml exists
if [ ! -f "$PUBSPEC_FILE" ]; then
    print_error "pubspec.yaml not found: $PUBSPEC_FILE"
    exit 1
fi

# Function to read version line from pubspec.yaml
read_version_line() {
    grep "^version:" "$PUBSPEC_FILE" | head -n 1
}

# Function to parse version and build number from pubspec.yaml
# Format: version: MAJOR.MINOR.PATCH+BUILD
parse_version() {
    local version_line=$(read_version_line)
    local version_string=$(echo "$version_line" | sed 's/version: *//' | tr -d ' ')

    if [ -z "$version_string" ]; then
        print_error "No version found in pubspec.yaml"
        exit 1
    fi

    echo "$version_string"
}

# Function to get semantic version (without build number)
get_semantic_version() {
    local full_version=$(parse_version)
    echo "$full_version" | cut -d'+' -f1
}

# Function to get build number
get_build_number_only() {
    local full_version=$(parse_version)
    if [[ "$full_version" == *"+"* ]]; then
        echo "$full_version" | cut -d'+' -f2
    else
        echo "1"  # Default if no build number exists
    fi
}

# Function to get current version
# For backward compatibility with old script interface
# Ignores flavor parameter since we now have single build number
get_version() {
    local env_type="${1:-PROD}"
    # Support legacy flavor parameters for backward compatibility
    case "$env_type" in
        production) env_type="PROD" ;;
        internal|alpha|beta) env_type="NONPROD" ;;
    esac
    
    local semantic_version=$(get_semantic_version)
    local build_number=$(get_build_number_only)

    if [ "$env_type" == "PROD" ]; then
        echo "${semantic_version}"
    else
        # For NONPROD builds, append build number and internal suffix
        echo "${semantic_version}.${build_number}-internal"
    fi
}

# Function to get build number
# For backward compatibility, accepts flavor parameter but ignores it
get_build_number() {
    local flavor=$1  # Accepted but ignored for backward compatibility
    get_build_number_only
}

# Function to increment build number
# For backward compatibility, accepts flavor parameter but ignores it
increment_build() {
    local flavor=$1  # Accepted but ignored for backward compatibility
    local current_build=$(get_build_number_only)
    local new_build=$((current_build + 1))
    local semantic_version=$(get_semantic_version)
    local new_version="${semantic_version}+${new_build}"

    # Update pubspec.yaml using sed
    # macOS and Linux compatible approach
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/^version: .*/version: ${new_version}/" "$PUBSPEC_FILE"
    else
        # Linux
        sed -i "s/^version: .*/version: ${new_version}/" "$PUBSPEC_FILE"
    fi

    print_info "Incremented build number: $current_build -> $new_build"
    print_info "New version: ${new_version}"
    echo "$new_build"
}

set_build_number() {
    local new_build=$1
    if ! [[ "$new_build" =~ ^[0-9]+$ ]]; then
        print_error "Invalid build number: $new_build"
        exit 1
    fi

    local semantic_version
    semantic_version=$(get_semantic_version)
    local new_version="${semantic_version}+${new_build}"

    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/^version: .*/version: ${new_version}/" "$PUBSPEC_FILE"
    else
        sed -i "s/^version: .*/version: ${new_version}/" "$PUBSPEC_FILE"
    fi

    print_info "Set build number to ${new_build}"
    print_info "New version: ${new_version}"
    echo "$new_build"
}

# Function to bump version (major, minor, or patch)
bump_version() {
    local bump_type=$1
    local full_version=$(parse_version)
    local semantic_version=$(get_semantic_version)
    local build_number=$(get_build_number_only)

    # Split semantic version into parts
    local major=$(echo "$semantic_version" | cut -d'.' -f1)
    local minor=$(echo "$semantic_version" | cut -d'.' -f2)
    local patch=$(echo "$semantic_version" | cut -d'.' -f3)

    case "$bump_type" in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            # Reset build number on major bump
            build_number=1
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            # Reset build number on minor bump
            build_number=1
            ;;
        patch)
            patch=$((patch + 1))
            # Keep build number on patch bump
            ;;
        *)
            print_error "Invalid bump type: $bump_type. Use major, minor, or patch"
            exit 1
            ;;
    esac

    local new_version="${major}.${minor}.${patch}+${build_number}"

    # Update pubspec.yaml
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/^version: .*/version: ${new_version}/" "$PUBSPEC_FILE"
    else
        # Linux
        sed -i "s/^version: .*/version: ${new_version}/" "$PUBSPEC_FILE"
    fi

    print_info "Bumped version to ${new_version}"
    echo "${major}.${minor}.${patch}"
}

# Function to display current version info
display_version_info() {
    local full_version=$(parse_version)
    local semantic_version=$(get_semantic_version)
    local build_number=$(get_build_number_only)

    print_info "Current Version: ${semantic_version}"
    print_info "Build Number: ${build_number}"
    print_info "Full Version String: ${full_version}"
    print_info ""
    print_info "Environment Versions:"
    echo "  - PROD:        $(get_version PROD)"
    echo "  - NONPROD:     $(get_version NONPROD)"
    print_info ""
    print_info "Legacy Format Compatibility:"
    echo "  - Production:  $(get_version production)"
    echo "  - Internal:    $(get_version internal)"
    print_warning "Note: All environments now share the same build number"
}

# Main command handling
case "${1:-}" in
    get)
        env_type="${2:-PROD}"
        get_version "$env_type"
        ;;
    get-build)
        env_type="${2:-PROD}"  # Parameter ignored for compatibility
        get_build_number "$env_type"
        ;;
    increment)
        env_type="${2:-PROD}"  # Parameter ignored for compatibility
        increment_build "$env_type"
        ;;
    set-build)
        new_build="${2:-}"
        if [ -z "$new_build" ]; then
            print_error "Usage: $0 set-build <number>"
            exit 1
        fi
        set_build_number "$new_build"
        ;;
    bump)
        bump_type="${2:-patch}"
        bump_version "$bump_type"
        ;;
    info)
        display_version_info
        ;;
    *)
        echo "Usage: $0 {get|get-build|increment|set-build|bump|info} [args]"
        echo ""
        echo "Commands:"
        echo "  get [env]              - Get version string for environment (PROD/NONPROD, default: PROD)"
        echo "  get-build [flavor]     - Get build number (flavor parameter ignored)"
        echo "  increment [flavor]     - Increment build number (flavor parameter ignored)"
        echo "  set-build <number>     - Force build number to a specific value"
        echo "  bump [type]            - Bump version (major|minor|patch, default: patch)"
        echo "  info                   - Display current version information"
        echo ""
        echo "Note: Flavors parameter accepted for backward compatibility but ignored."
        echo "      All builds now share a single version and build number from pubspec.yaml"
        exit 1
        ;;
esac
