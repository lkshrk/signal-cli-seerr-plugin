#!/bin/bash

# Release script for Seerr Notification Plugin
# Usage: ./scripts/release.sh [patch|minor|major]
# Default: patch

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get current version from git tags
get_current_version() {
    local version
    version=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
    # Remove 'v' prefix if present
    echo "${version#v}"
}

# Get current version
CURRENT_VERSION=$(get_current_version)

if [ "$CURRENT_VERSION" = "0.0.0" ]; then
    echo -e "${YELLOW}No previous tags found. This will be the first release.${NC}"
    CURRENT_VERSION="0.0.0"
fi

echo -e "${BLUE}Current version: ${CURRENT_VERSION}${NC}"

# Determine bump type
BUMP_TYPE=${1:-patch}

if [[ ! "$BUMP_TYPE" =~ ^(patch|minor|major)$ ]]; then
    echo -e "${RED}Error: Invalid bump type. Use 'patch', 'minor', or 'major'${NC}"
    echo "Usage: ./scripts/release.sh [patch|minor|major]"
    exit 1
fi

echo -e "${BLUE}Bump type: ${BUMP_TYPE}${NC}"

# Parse current version
IFS='.' read -r -a VERSION_PARTS <<< "$CURRENT_VERSION"
MAJOR=${VERSION_PARTS[0]}
MINOR=${VERSION_PARTS[1]}
PATCH=${VERSION_PARTS[2]}

# Calculate new version
case $BUMP_TYPE in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    patch)
        PATCH=$((PATCH + 1))
        ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
echo -e "${GREEN}New version: ${NEW_VERSION}${NC}"

# Check if we're in a git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}Error: Not a git repository${NC}"
    exit 1
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "main" ]; then
    echo -e "${RED}Error: Releases can only be created from the main branch${NC}"
    echo -e "Current branch: ${YELLOW}${CURRENT_BRANCH}${NC}"
    echo -e "Switch to main first: ${BLUE}git checkout main${NC}"
    exit 1
fi

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo -e "${YELLOW}Warning: You have uncommitted changes${NC}"
    read -p "Do you want to commit them before releasing? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Staging all changes...${NC}"
        git add .
        read -p "Enter commit message: " commit_message
        git commit -m "$commit_message"
    else
        echo -e "${RED}Release aborted. Please commit or stash your changes first.${NC}"
        exit 1
    fi
fi

# Get commit messages since last tag (if any)
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

if [ -z "$LAST_TAG" ]; then
    echo -e "${YELLOW}No previous tags found. This appears to be the first release.${NC}"
    COMMIT_MESSAGES=$(git log --pretty=format:"- %s" --no-merges)
else
    echo -e "${BLUE}Generating changelog from commits since ${LAST_TAG}...${NC}"
    COMMIT_MESSAGES=$(git log ${LAST_TAG}..HEAD --pretty=format:"- %s" --no-merges)
fi

if [ -z "$COMMIT_MESSAGES" ]; then
    echo -e "${YELLOW}Warning: No new commits since last tag${NC}"
    read -p "Do you want to continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Release aborted.${NC}"
        exit 1
    fi
fi

# Show summary
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Release Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Version: ${GREEN}${CURRENT_VERSION}${NC} → ${GREEN}${NEW_VERSION}${NC}"
echo -e "Bump type: ${YELLOW}${BUMP_TYPE}${NC}"
echo ""
echo -e "${BLUE}Changes:${NC}"
echo "$COMMIT_MESSAGES"
echo ""
echo -e "${BLUE}========================================${NC}"

# Confirm release
read -p "Do you want to create the release? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Release aborted.${NC}"
    exit 1
fi

# Commit version bump (if there are any staged changes)
if ! git diff-index --quiet HEAD --; then
    git add -A
    git commit -m "Release v${NEW_VERSION}" || true
    echo -e "${GREEN}✓ Committed changes${NC}"
fi

# Create tag
git tag -a "v${NEW_VERSION}" -m "Release v${NEW_VERSION}

Changes:
${COMMIT_MESSAGES}"
echo -e "${GREEN}✓ Created tag v${NEW_VERSION}${NC}"

# Get repository URL for the message
REPO_URL=$(git remote get-url origin | sed -e 's|git@github.com:|https://github.com/|' -e 's|\.git$||')

# Push to remote
echo -e "${BLUE}Pushing to remote...${NC}"
git push origin main
git push origin "v${NEW_VERSION}"
echo -e "${GREEN}✓ Pushed to remote${NC}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Release v${NEW_VERSION} Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "GitHub Actions will now build and publish the release."
echo -e "Check progress at: ${REPO_URL}/actions"
