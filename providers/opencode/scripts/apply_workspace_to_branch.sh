#!/bin/bash
# apply_workspace.sh
# Usage: ./apply_workspace.sh project-alpha agent_branch_name

PROJECT=$1
BRANCH=$2
WORKSPACE_DIR=~/opencode-projects/$PROJECT/.workspace
REPO_DIR=~/opencode-projects/$PROJECT

# Step 0: Enter project folder
cd $REPO_DIR || exit 1

# Step 1: Create or checkout agent-specific branch
git checkout -B $BRANCH

# Step 2: Copy workspace changes into repo
cp -r $WORKSPACE_DIR/changes/* .

# Step 3: Stage changes
git add .

# Step 4: Commit with metadata info
if [[ -f $WORKSPACE_DIR/metadata.json ]]; then
    METADATA=$(cat $WORKSPACE_DIR/metadata.json)
    git commit -m "Agent commit: $METADATA"
else
    git commit -m "Agent commit"
fi

echo "Agent changes committed to branch $BRANCH. Ready for PR review."