# Release Guide

This document describes a clean and repeatable release process for PyroVeil.

## Pre-Release Checklist

- Working tree is clean
- Submodules are initialized and up to date
- Full validation passes
- README and QUICKSTART are current
- Version number is decided
- Release notes draft is prepared

## 1. Validate Build and Tests

```bash
scripts/run-full-validation.sh
```

Optional deeper run:

```bash
scripts/comprehensive-test.sh --report
```

## 2. Prepare Release Artifact

```bash
scripts/prepare-release.sh 1.0.0
```

Expected artifact pattern:

- pyroveil-1.0.0-linux-x64.tar.gz

## 3. Verify Release Package Locally

```bash
mkdir -p /tmp/pyroveil-release-test
tar -xzf pyroveil-1.0.0-linux-x64.tar.gz -C /tmp/pyroveil-release-test
cd /tmp/pyroveil-release-test/pyroveil-1.0.0-linux-x64
./install-pyroveil.sh
```

Basic installation checks:

```bash
ls -l $HOME/.local/lib/libVkLayer_pyroveil_64.so
ls -l $HOME/.local/share/vulkan/implicit_layer.d/VkLayer_pyroveil_64.json
vulkaninfo --summary | grep -i pyroveil
```

## 4. Tag the Release

```bash
git add -A
git commit -m "chore(release): v1.0.0"
git tag -a v1.0.0 -m "PyroVeil v1.0.0"
```

## 5. Push Changes and Tag

```bash
git push origin main
git push origin v1.0.0
```

## 6. Create GitHub Release

At GitHub Releases:

- Select tag: v1.0.0
- Title: PyroVeil v1.0.0
- Attach artifact: pyroveil-1.0.0-linux-x64.tar.gz
- Add release notes:
  - Main fixes and supported games updates
  - Breaking changes (if any)
  - Known limitations

## Recommended Release Notes Template

```text
## Highlights
- 

## Fixes
- 

## Compatibility
- NVIDIA driver notes:
- Distros tested:

## Known Issues
- 
```

## Post-Release Tasks

- Verify install reports from users on Fedora/Bazzite/Arch/Ubuntu
- Monitor GitHub Issues for regressions
- Update game database if new fixes are reported
- Plan next patch release if critical regressions appear
