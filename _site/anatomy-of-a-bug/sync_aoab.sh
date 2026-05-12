#!/bin/bash

# 1. Define Variables
REPO_URL="https://raw.githubusercontent.com/tralsesec/AnatomyOfABug/main/README.md"
TARGET_FILE="anatomy-of-a-bug.md"

# 2. Create the Front Matter (The "Header" for Jekyll)
# We use a heredoc to write the YAML block first
cat <<EOF > $TARGET_FILE
---
layout: page
title: "#! Anatomy of a Bug"
sidebar_link: true
order: 1
permalink: /anatomy-of-a-bug/
---

EOF

# 3. Fetch the README, strip the first line (The H1 title), and append to target
# We use tail -n +2 to skip the first line (assuming line 1 is "# Anatomy of a Bug")
curl -s $REPO_URL | tail -n +2 >> $TARGET_FILE

echo "[+] Intel synced. $TARGET_FILE updated from remote."
