# PyroVeil Deployment Guide

Comprehensive guide for deploying and releasing PyroVeil version 2.0.0-rc1.

## Pre-Release Checklist

### Code Quality
- [x] English-only codebase (no Russian/Cyrillic)
- [x] Shell scripts validate: `bash -n *.sh scripts/*.sh`
- [x] All documentation complete
- [x] Version set to 2.0.0-rc1

### Testing
- [x] Bash syntax validation passed
- [x] Code formatting verified
- [x] All scripts executable
- [x] Documentation comprehensive

### Version Control
- [x] Working tree cleaned
- [x] Build artifacts removed
- [x] All changes documented

## Deployment Steps

### 1. Verify Release Readiness
```bash
cd /var/home/sanya/pyroveil

# Check version
cat VERSION  # Should be 2.0.0-rc1

# Verify scripts
bash -n install-pyroveil.sh scripts/py*.sh

# Check for Russian text
! grep -r '[А-Яа-яЁё]' . --exclude-dir=.git --exclude-dir=third_party
```

### 2. Create Release Commit
```bash
git add -A
git commit -m "Release v2.0.0-rc1: Complete English localization and feature expansion"
```

### 3. Tag Release
```bash
git tag -a v2.0.0-rc1 -m "PyroVeil v2.0.0-rc1 - Release Candidate 1"
git push origin --tags
```

### 4. Create Release Archive
```bash
tar -czf pyroveil-2.0.0-rc1.tar.gz \
  --exclude=.git \
  --exclude=build \
  --exclude='*.so' \
  --exclude=CMakeCache.txt \
  .
```

## Installation for Users

### Quick Start
```bash
bash install-pyroveil.sh
pyroveil-update-database.sh update
pyroveil-auto-detect.sh check 2778720  # Test detection
```

### Distro-Specific
- **Fedora/RHEL**: `bash install-pyroveil.sh`
- **Bazzite/Silverblue**: `bash install-pyroveil.sh --layering`
- **Arch**: `bash install-pyroveil.sh`
- **Ubuntu/Debian**: `bash install-pyroveil.sh`

## Post-Deployment

### 1. Monitor for Issues
- Check GitHub issues regularly
- Respond to user feedback
- Document workarounds as needed

### 2. Support Users
- Reference RELEASE-SUMMARY.md for version info
- Direct users to distro-specific guides in README.md
- Provide database update information

### 3. Plan Next Release
- Create development branch for 2.0.1
- Update version to 2.0.1-dev
- Begin collecting changes for next cycle

## Documentation Files

| File | Purpose |
|------|---------|
| CHANGELOG.md | All version changes and migration info |
| CONTRIBUTORS.md | Attribution and contribution guidelines |
| RELEASE-SUMMARY.md | Executive summary of v2.0.0-rc1 |
| DEPLOYMENT.md | This file - deployment procedures |
| README.md | User-focused documentation |
| README-RELEASE.md | Release process guide |

## Support

For deploymen issues:
- Check RELEASE-SUMMARY.md for feature overview
- See README.md for installation help
- Review CHANGELOG.md for known issues
- File GitHub issues with details

## License

All release files under MIT License (see LICENSE file)
