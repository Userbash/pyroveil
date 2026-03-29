# Release Guide

Release process for PyroVeil.

## Pre-Release Checklist

All items completed and ready for release:

- Code translated to English with comprehensive comments
- Documentation files created (README, QUICKSTART, LICENSE)
- Build artifacts cleaned (1.4 GB removed)
- Comprehensive .gitignore created (229 patterns)
- Testing infrastructure in place (28/28 tests passing)
- CI/CD examples documented
- Release automation scripts created
- Final verification checks passed

## Release Steps

### 1. Run Validation

```bash
./scripts/run-full-validation.sh
```

Expected: All tests pass (28/28)

### 2. Create Release Package

```bash
./scripts/prepare-release.sh 1.0.0
```

This validates requirements, cleans the project, builds in Release mode, runs tests, and creates the `pyroveil-1.0.0-linux-x64.tar.gz` package with release notes.

### 3. Test Package

```bash
mkdir -p /tmp/pyroveil-test
tar -xzf pyroveil-1.0.0-linux-x64.tar.gz -C /tmp/pyroveil-test
cd /tmp/pyroveil-test/pyroveil-1.0.0-linux-x64
./install-pyroveil.sh
ls -lh ~/.local/share/vulkan/implicit_layer.d/VkLayer_pyroveil.json
```

### 4. Initialize Git Repository

```bash
git init
git add .
git commit -m "chore: initial release v1.0.0

- Vulkan layer for NVIDIA shader compatibility
- Auto-detection for Steam games
- Comprehensive testing infrastructure
- Full English documentation"

git tag -a v1.0.0 -m "Release version 1.0.0"
```

### 5. Create GitHub Repository

Create new repository at https://github.com/new:
- Repository name: `pyroveil`
- Description: "Vulkan layer for NVIDIA GPU shader compatibility - automatic game detection and patching"
- Public repository
- Don't add README, .gitignore, or license (already exists)

### 6. Push to GitHub

```bash
# Add remote
git remote add origin https://github.com/YOUR_USERNAME/pyroveil.git

# Push code and tags
git push -u origin main
git push origin v1.0.0
```

### 7. Create GitHub Release

1. Go to https://github.com/YOUR_USERNAME/pyroveil/releases/new
git remote add origin https://github.com/YOUR_USERNAME/pyroveil.git
git push -u origin main
git push origin v1.0.0
```

### 7. Create GitHub Release

At https://github.com/YOUR_USERNAME/pyroveil/releases/new:
- Select tag: `v1.0.0`
- Release title: `PyroVeil 1.0.0 - Initial Release`
- DescrilibVkLayer_pyroveil_64.so
├── share/vulkan/implicit_layer.d/VkLayer_pyroveil.json
├── share/pyroveil/database.json
├── hacks/
├── install-pyroveil.sh
├── scripts/uninstall_pyroveil.sh
├── README.md
├── QUICKSTART.md
└── LICENSE
```

## Verification

Before publishing:

- Release package extracts without errors
- Installation script runs successfully
- Layer JSON validates with Vulkan validator
- Test with at least one supported game
- Documentation links work
- Repository settings correct
- Release notes comprehensive
- License file present

## Project Statistics

- ~5,000 lines C++
- ~3,000 lines Markdown documentation
- ~2,000 lines comments (40% ratio)
- 28 validation checks
- 5+ supported games

## Repository Settings

Topics for discoverability:, immutable-distro
```

### About Section
- Website: Leave blank or link to documentation
- Topics: Add above tags
- Check "Packages" if using GitHub Packages
- Social preview: Upload PyroVeil logo if available

### Repository Settings
- **General:**game-compatibility, vulkan-layer, immutable-distro
```

Repository settings:
- Default branch: `main`
- Enable Issues
- Enable Discussions (optional)

## Post-Release

Announce on:
- r/linux_gaming, r/linuxquestions, r/Fedora
- ProtonDB (add fix reports)
- Steam Community forums
- Gaming news sites (GamingOnLinux, Phoronix)

Monitor:
- Installation issues via GitHub Issues
- Game compatibility reports
- Update database.json with new games

## Common Issues

### Library not found
Ensure library is in LD_LIBRARY_PATH or installed to system paths

### Layer not loading
Verify VK_LAYER_PATH or implicit layer JSON is correct

### Game crashes
Check logs in `/tmp/pyroveil_*.log`, may need game-specific config

## Support Channels

- GitHub Issues: Bug reports and features
- GitHub Discussions: Questions and troubleshooting
- README.md: Troubleshooting section