#!/bin/bash
# Version Manager Script for Usernode CI/CD

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION_FILE="$PROJECT_ROOT/version.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    print_error "jq is required but not installed. Please install it: brew install jq"
    exit 1
fi

# Function to read version file
read_version() {
    if [ ! -f "$VERSION_FILE" ]; then
        print_error "Version file not found: $VERSION_FILE"
        exit 1
    fi
    cat "$VERSION_FILE"
}

# Function to get current version
get_version() {
    local flavor=$1
    local version_data=$(read_version)
    local major=$(echo "$version_data" | jq -r '.major')
    local minor=$(echo "$version_data" | jq -r '.minor')
    local patch=$(echo "$version_data" | jq -r '.patch')
    local build=$(echo "$version_data" | jq -r ".build.$flavor")

    if [ "$flavor" == "production" ]; then
        echo "${major}.${minor}.${patch}"
    else
        echo "${major}.${minor}.${patch}.${build}-${flavor}"
    fi
}

# Function to get build number
get_build_number() {
    local flavor=$1
    local version_data=$(read_version)
    echo "$version_data" | jq -r ".build.$flavor"
}

# Function to increment build number
increment_build() {
    local flavor=$1
    local version_data=$(read_version)
    local current_build=$(echo "$version_data" | jq -r ".build.$flavor")
    local new_build=$((current_build + 1))

    echo "$version_data" | jq ".build.$flavor = $new_build" > "$VERSION_FILE"
    print_info "Incremented $flavor build number: $current_build -> $new_build"
    echo "$new_build"
}

# Function to bump version (major, minor, or patch)
bump_version() {
    local bump_type=$1
    local version_data=$(read_version)
    local major=$(echo "$version_data" | jq -r '.major')
    local minor=$(echo "$version_data" | jq -r '.minor')
    local patch=$(echo "$version_data" | jq -r '.patch')

    case "$bump_type" in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        *)
            print_error "Invalid bump type: $bump_type. Use major, minor, or patch"
            exit 1
            ;;
    esac

    echo "$version_data" | jq ".major = $major | .minor = $minor | .patch = $patch" > "$VERSION_FILE"
    print_info "Bumped version to ${major}.${minor}.${patch}"
    echo "${major}.${minor}.${patch}"
}

# Function to display current version info
display_version_info() {
    local version_data=$(read_version)
    local major=$(echo "$version_data" | jq -r '.major')
    local minor=$(echo "$version_data" | jq -r '.minor')
    local patch=$(echo "$version_data" | jq -r '.patch')

    print_info "Current Version: ${major}.${minor}.${patch}"
    print_info "Build Numbers:"
    echo "  - Internal:   $(get_version internal)"
    echo "  - Alpha:      $(get_version alpha)"
    echo "  - Beta:       $(get_version beta)"
    echo "  - Production: $(get_version production)"
}

# Main command handling
case "${1:-}" in
    get)
        flavor="${2:-production}"
        get_version "$flavor"
        ;;
    get-build)
        flavor="${2:-production}"
        get_build_number "$flavor"
        ;;
    increment)
        flavor="${2:-production}"
        increment_build "$flavor"
        ;;
    bump)
        bump_type="${2:-patch}"
        bump_version "$bump_type"
        ;;
    info)
        display_version_info
        ;;
    *)
        echo "Usage: $0 {get|get-build|increment|bump|info} [flavor|bump_type]"
        echo ""
        echo "Commands:"
        echo "  get [flavor]           - Get version string for flavor (default: production)"
        echo "  get-build [flavor]     - Get build number for flavor (default: production)"
        echo "  increment [flavor]     - Increment build number for flavor (default: production)"
        echo "  bump [type]            - Bump version (major|minor|patch, default: patch)"
        echo "  info                   - Display current version information"
        echo ""
        echo "Flavors: internal, alpha, beta, production"
        exit 1
        ;;
esac
