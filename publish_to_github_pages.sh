#!/usr/bin/env bash
# publish_to_github_pages.sh
# Usage: ./publish_to_github_pages.sh
# Precondition: index.html exists in the same folder.
# Requires: git and GitHub CLI (gh). Authenticate first with `gh auth login` if not already.

set -euo pipefail

# --- CONFIGURE THIS (script uses your provided username) ---
GH_USER="pgbpro20"
REPO_NAME="absolute-nonsense-2025"   # project repo -> served at https://<GH_USER>.github.io/<REPO_NAME>/
INDEX_FILE="index.html"
BRANCH="main"

# --- sanity checks ---
command -v git >/dev/null 2>&1 || { echo "ERROR: git is required. Install it (eg. sudo apt install git)"; exit 1; }
command -v gh >/dev/null 2>&1 || { echo "ERROR: GitHub CLI (gh) is required. Install it: https://cli.github.com/"; exit 1; }

if [ ! -f "$INDEX_FILE" ]; then
  echo "ERROR: $INDEX_FILE not found in $(pwd). Put your index.html here and re-run."
  exit 1
fi

# Check gh authentication
if ! gh auth status >/dev/null 2>&1 ; then
  echo "You are not authenticated with gh. Run: gh auth login"
  echo "  (choose GitHub.com, HTTPS, and follow the interactive flow or use a token)"
  exit 1
fi

# If current dir already a git repo with different origin, that's fine; we'll initialize/reset as needed.
# Create a temporary git repo in place (safe for an empty or new project)
if [ -d .git ]; then
  echo "Using existing git repository in $(pwd)"
else
  echo "Initializing git repository..."
  git init
fi

git add -A
# If there are no commits yet, create initial commit; otherwise create a new commit
if git rev-parse --verify HEAD >/dev/null 2>&1; then
  git commit -m "Update site" || echo "No changes to commit."
else
  git commit -m "Initial commit: publish site" || true
fi

# Ensure branch name is main
git branch -M "$BRANCH" || true

# Check if repo already exists on GitHub
if gh repo view "$GH_USER/$REPO_NAME" >/dev/null 2>&1; then
  echo "Repository $GH_USER/$REPO_NAME already exists on GitHub."
  # Set origin if not already set
  if git remote get-url origin >/dev/null 2>&1; then
    echo "Using existing remote origin: $(git remote get-url origin)"
  else
    echo "Adding origin remote..."
    git remote add origin "https://github.com/${GH_USER}/${REPO_NAME}.git"
  fi
  echo "Pushing to origin/${BRANCH}..."
  git push -u origin "$BRANCH"
else
  echo "Creating repository $GH_USER/$REPO_NAME on GitHub and pushing..."
  # creates, sets remote, and pushes the current directory to the new repo
  gh repo create "${GH_USER}/${REPO_NAME}" --public --source=. --remote=origin --push
fi

# Try to enable Pages publishing from the branch root via GitHub REST API (may not be strictly necessary for user-site)
echo "Configuring GitHub Pages to publish from ${BRANCH}/ (best-effort)..."
set +e
gh api -X PUT /repos/"${GH_USER}"/"${REPO_NAME}"/pages -f source='{"branch":"'"${BRANCH}"'","path":"/"}' >/dev/null 2>&1
API_EXIT=$?
set -e
if [ $API_EXIT -eq 0 ]; then
  echo "Pages configuration updated via API."
else
  echo "Warning: could not update Pages via API (this is okay). You can verify/enable Pages in the repo Settings → Pages."
fi

SITE_URL="https://${GH_USER}.github.io/${REPO_NAME}/"
echo
echo "DONE — your site should be available at:"
echo "  $SITE_URL"
echo
echo "Note: GitHub may take a minute to publish the page. If it doesn't show up immediately, wait ~30–60s and refresh."
