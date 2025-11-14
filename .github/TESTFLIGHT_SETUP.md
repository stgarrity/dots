# TestFlight Automated Deployment Setup

This document explains how to set up automated TestFlight deployments for the Dots iOS app via GitHub Actions.

## Overview

Every push to the `master` branch will automatically:
1. Build the iOS app with an auto-generated build number
2. Archive and export the IPA
3. Upload to TestFlight
4. Notify you when ready for testing

## Required GitHub Secrets

You need to configure these secrets in your GitHub repository:

**Repository Settings → Secrets and variables → Actions → New repository secret**

### 1. `APPLE_CERTIFICATE_P12`

Your Apple Distribution certificate in base64-encoded format.

**How to get it:**
```bash
# Export certificate from Keychain Access
# 1. Open Keychain Access
# 2. Find "Apple Distribution: <Your Name> (<Team ID>)"
# 3. Right-click → Export → Save as .p12 with a password
# 4. Then run:
base64 -i YourCertificate.p12 | pbcopy
# 5. Paste into GitHub secret
```

### 2. `APPLE_CERTIFICATE_PASSWORD`

The password you used when exporting the .p12 certificate file.

### 3. `APPLE_PROVISIONING_PROFILE`

Your App Store provisioning profile in base64-encoded format.

**How to get it:**
```bash
# Download from Apple Developer Portal
# 1. Go to https://developer.apple.com/account/resources/profiles/list
# 2. Find or create an "App Store" profile for Bundle ID: org.g7g.Dots
# 3. Download the .mobileprovision file
# 4. Then run:
base64 -i YourProfile.mobileprovision | pbcopy
# 5. Paste into GitHub secret
```

### 4. `APP_STORE_CONNECT_KEY_ID`

Your App Store Connect API Key ID (looks like: `ABC123DEFG`).

**How to get it:**
```
1. Go to https://appstoreconnect.apple.com/access/api
2. Click the "Keys" tab
3. Create a new key (or use existing) with "App Manager" role or higher
4. Copy the Key ID
```

### 5. `APP_STORE_CONNECT_ISSUER_ID`

Your App Store Connect Issuer ID (UUID format).

**How to get it:**
```
1. Go to https://appstoreconnect.apple.com/access/api
2. Find "Issuer ID" at the top of the page
3. Copy the UUID
```

### 6. `APP_STORE_CONNECT_API_KEY`

Your App Store Connect API key (.p8 file) in base64-encoded format.

**How to get it:**
```bash
# When creating the API key in step 4, download the .p8 file
# IMPORTANT: You can only download this ONCE when creating the key!
# Then run:
base64 -i AuthKey_ABC123DEFG.p8 | pbcopy
# Paste into GitHub secret
```

## Project Configuration

The following settings have been configured in the Xcode project:

- **Bundle ID**: `org.g7g.Dots`
- **Team ID**: `9CD2CVAPU9`
- **Export Compliance**: Set to `NO` (app only uses standard HTTPS/TLS encryption)
- **Build Number**: Auto-generated in format `YYYYMMDD.HHMM` (e.g., `20251114.1530`)

## Workflow Details

**File**: `.github/workflows/testflight.yml`

**Trigger**: Push to `master` branch

**Steps**:
1. Checkout code
2. Set up Xcode 16.4
3. Generate timestamp-based build number
4. Install signing certificate in temporary keychain
5. Install provisioning profile
6. Build and archive app
7. Export IPA
8. Upload to TestFlight
9. Clean up keychain (always runs, even on failure)

**Build Time**: ~2-3 minutes

## Usage

Once configured:

1. Make your code changes
2. Commit and push to `master` branch
3. GitHub Actions automatically starts building
4. Check progress at: https://github.com/YOUR_USERNAME/dots/actions
5. Wait ~10-15 minutes for Apple to process the build
6. You'll receive an email when the build is ready
7. Add release notes and distribute to testers in App Store Connect

## Build Number Format

Build numbers are automatically generated as: `YYYYMMDD.HHMM`

Example: `20251114.1530` means:
- Date: November 14, 2025
- Time: 15:30 UTC

This ensures:
- Chronological ordering
- Unique builds
- No version conflicts
- Human-readable timestamps

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| "No destinations found" | Check Xcode version compatibility |
| "Provisioning profile not found" | Verify profile Bundle ID matches `org.g7g.Dots` |
| "Code signing failed" | Check certificate and team ID match |
| "Upload failed" | Verify API key has "App Manager" role or higher |
| "Export compliance missing" | Already configured in project settings |

### Checking Workflow Logs

1. Go to your GitHub repository
2. Click "Actions" tab
3. Click on the failed workflow run
4. Expand each step to see detailed logs
5. Look for error messages in red

### Testing Locally

You can test the build locally before pushing:

```bash
# Set a test build number
BUILD_NUMBER=$(date -u +"%Y%m%d.%H%M")

# Build archive (without signing)
xcodebuild archive \
  -scheme Dots \
  -sdk iphoneos \
  -configuration Release \
  -archivePath ./build/Dots.xcarchive \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  IPHONEOS_DEPLOYMENT_TARGET=18.0
```

## Security Notes

- All secrets are encrypted by GitHub
- Temporary keychain is created and destroyed for each build
- Certificate and keys are never logged or exposed
- Build artifacts are temporary and deleted after upload

## References

- [Apple Developer Portal](https://developer.apple.com/account/)
- [App Store Connect](https://appstoreconnect.apple.com/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

---

**Last Updated**: 2025-11-14
**App**: Dots
**Bundle ID**: org.g7g.Dots
**Team ID**: 9CD2CVAPU9
