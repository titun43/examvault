#!/usr/bin/env bash
# =============================================================================
# ExamVault - Deploy Firebase Rules
# Run this script from the examvault-work folder to deploy the updated
# Firestore + Storage security rules. You only need to do this ONCE after
# updating the rules files.
#
# Prerequisites:
#   1. Node.js installed
#   2. Firebase CLI:   npm install -g firebase-tools
#   3. Firebase login: firebase login   (opens a browser to authenticate)
#
# Usage:
#   cd examvault-work
#   bash deploy-rules.sh
# =============================================================================

set -e

echo "=== ExamVault Firebase Rules Deploy ==="
echo ""

# Check firebase CLI
if ! command -v firebase &> /dev/null; then
  echo "Firebase CLI not found. Installing..."
  npm install -g firebase-tools
fi

# Check login
if ! firebase login:list 2>&1 | grep -q "@"; then
  echo "You are not logged in to Firebase. Starting login..."
  firebase login
fi

echo ""
echo "Deploying Firestore rules..."
firebase deploy --only firestore:rules

echo ""
echo "Deploying Storage rules..."
firebase deploy --only storage

echo ""
echo "Done! Rules deployed to project: examvaultnew"
echo ""
echo "What was deployed:"
echo "  - firestore.rules  (premium_plans, notifications, test_purchases, user_photos, etc.)"
echo "  - storage.rules    (user_avatars, user_photos paths)"
echo ""
echo "The admin panel can now write to premium_plans, notifications, etc."
echo "The user app can now upload profile photos and save test purchases."
