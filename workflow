name: EAS Build and Download Artifact

on:
  push:
    branches:
      - main

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout Repository
        uses: actions/checkout@v3

      - name: Install Node.js
        uses: actions/setup-node@v3
        with:
          node-version: 16

      - name: Cache Node Modules
        uses: actions/cache@v3
        with:
          path: ~/.npm
          key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
          restore-keys: |
            ${{ runner.os }}-node-

      - name: Install EAS CLI
        run: npm install --global eas-cli

      - name: Authenticate with Expo
        env:
          EAS_TOKEN: ${{ secrets.EAS_TOKEN }}
        run: eas whoami

      - name: Run EAS Build
        run: eas build --platform ios

      - name: Get Build ID
        id: get_build_id
        run: |
          BUILD_ID=$(eas build:list --platform ios --status finished --limit 1 --json | jq -r '.[0].id')
          if [ -z "$BUILD_ID" ] || [ "$BUILD_ID" == "null" ]; then
            echo "Error: Failed to retrieve build ID."
            exit 1
          fi
          echo "Build ID: $BUILD_ID"
          echo "BUILD_ID=$BUILD_ID" >> $GITHUB_ENV

      - name: Fetch Artifact URL
        id: fetch_artifact
        run: |
          BUILD_ARTIFACT_URL=$(eas build:view --id $BUILD_ID --json | jq -r '.artifacts.buildUrl')

          if [ -z "$BUILD_ARTIFACT_URL" ] || [ "$BUILD_ARTIFACT_URL" == "null" ]; then
            echo "No artifact URL found: Build might have failed or is still in progress."
            exit 1
          fi
          echo "Artifact URL: $BUILD_ARTIFACT_URL"
          echo "BUILD_ARTIFACT_URL=$BUILD_ARTIFACT_URL" >> $GITHUB_ENV

      - name: Download Artifact
        run: |
          curl -o output.ipa "$BUILD_ARTIFACT_URL"

      - name: Upload iOS Artifact
        uses: actions/upload-artifact@v3
        with:
          name: iOS-Build
          path: output.ipa