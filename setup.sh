#!/bin/bash
# Initialize Monorepo
mkdir ebook-reader && cd ebook-reader
pnpm init
echo "packages:
  - 'apps/*'
  - 'packages/*'" > pnpm-workspace.yaml

# Create Folders
mkdir -p apps/desktop apps/mobile packages/core packages/ui

# Initialize Core Package
cd packages/core
pnpm init
mkdir -p src/api src/sync src/utils
touch src/index.ts
cd ../..

# Initialize Next.js Apps
cd apps
pnpm create next-app desktop --typescript --tailwind --eslint --app --src-dir --import-alias "@/*"
pnpm create next-app mobile --typescript --tailwind --eslint --app --src-dir --import-alias "@/*"

# Add Capacitor to Mobile
cd mobile
pnpm add @capacitor/core @capacitor/cli
npx cap init ebook-reader com.example.reader --web-dir out