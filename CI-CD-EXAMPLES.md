# CI/CD Integration

Configuration examples for automated testing and validation.

## Table of Contents

- [GitHub Actions](#github-actions)
- [GitLab CI](#gitlab-ci)
- [Jenkins](#jenkins)
- [Local Pre-Commit Hooks](#local-pre-commit-hooks)

## GitHub Actions

### Basic Workflow

Create `.github/workflows/validate.yml`:

```yaml
name: PyroVeil Validation

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  validate:
    name: Build and Test
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          submodules: recursive
      
      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y \
            cmake \
            ninja-build \
            g++ \
            shellcheck \
            cppcheck \
            jq \
            libvulkan-dev
      
      - name: Run validation suite
        run: ./scripts/run-full-validation.sh
      
      - name: Upload build artifacts
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: build-artifacts
          path: |
            build/layer/libVkLayer_pyroveil_64.so
            build/layer/VkLayer_pyroveil_64.json
            build/build.log
```

### Advanced Workflow with Matrix

```yaml
name: PyroVeil Multi-Platform Build

on: [push, pull_request]

jobs:
  build-matrix:
    name: Build on ${{ matrix.os }}
    runs-on: ${{ matrix.os }}
    
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-20.04, ubuntu-22.04, ubuntu-24.04]
        build_type: [Debug, Release]
    
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive
      
      - name: Install deps
        run: |
          sudo apt-get update
          sudo apt-get install -y cmake ninja-build g++ libvulkan-dev jq
      
      - name: Configure
        run: |
          cmake -B build -G Ninja \
            -DCMAKE_BUILD_TYPE=${{ matrix.build_type }}
      
      - name: Build
        run: ninja -C build
      
      - name: Test modules
        run: ./scripts/test-modules.sh
      
      - name: Test logging
        run: ./scripts/test-logging.sh
```

## GitLab CI

### Basic Pipeline

Create `.gitlab-ci.yml`:

```yaml
stages:
  - build
  - test
  - validate

variables:
  GIT_SUBMODULE_STRATEGY: recursive

build:
  stage: build
  image: fedora:latest
  before_script:
    - dnf install -y cmake gcc-c++ ninja-build vulkan-headers
  script:
    - cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
    - ninja -C build
  artifacts:
    paths:
      - build/layer/libVkLayer_pyroveil_64.so
      - build/layer/VkLayer_pyroveil_64.json
    expire_in: 1 week

test:modules:
  stage: test
  image: fedora:latest
  dependencies:
    - build
  script:
    - dnf install -y jq
    - ./scripts/test-modules.sh

test:logging:
  stage: test
  image: fedora:latest
  dependencies:
    - build
  script:
    - ./scripts/test-logging.sh

validate:full:
  stage: validate
  image: fedora:latest
  before_script:
    - dnf install -y cmake gcc-c++ ninja-build shellcheck cppcheck jq
  script:
    - ./scripts/run-full-validation.sh
  only:
    - main
    - merge_requests
```

### Multi-Distribution Pipeline

```yaml
.build_template: &build_template
  stage: build
  before_script:
    - |
      if [ -f /etc/debian_version ]; then
        apt-get update
        apt-get install -y cmake ninja-build g++ libvulkan-dev
      else
        dnf install -y cmake gcc-c++ ninja-build vulkan-headers
      fi
  script:
    - cmake -B build -G Ninja
    - ninja -C build
  artifacts:
    paths:
      - build/

build:fedora40:
  <<: *build_template
  image: fedora:40

build:ubuntu24:
  <<: *build_template
  image: ubuntu:24.04

build:debian12:
  <<: *build_template
  image: debian:12

validate:
  stage: validate
  image: fedora:latest
  dependencies:
    - build:fedora40
  script:
    - dnf install -y shellcheck cppcheck jq
    - ./scripts/run-full-validation.sh
```

## Jenkins

### Jenkinsfile (Declarative)

```groovy
pipeline {
    agent any
    
    environment {
        BUILD_DIR = 'build'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh 'git submodule update --init --recursive'
            }
        }
        
        stage('Install Dependencies') {
            steps {
                sh '''
                    sudo dnf install -y cmake gcc-c++ ninja-build \
                        vulkan-headers shellcheck cppcheck jq
                '''
            }
        }
        
        stage('Build') {
            steps {
                sh '''
                    cmake -B ${BUILD_DIR} -G Ninja -DCMAKE_BUILD_TYPE=Release
                    ninja -C ${BUILD_DIR}
                '''
            }
        }
        
        stage('Test Modules') {
            steps {
                sh './scripts/test-modules.sh'
            }
        }
        
        stage('Test Logging') {
            steps {
                sh './scripts/test-logging.sh'
            }
        }
        
        stage('Full Validation') {
            steps {
                sh './scripts/run-full-validation.sh'
            }
        }
    }
    
    post {
        always {
            archiveArtifacts artifacts: 'build/layer/*.so,build/layer/*.json', fingerprint: true
            cleanWs()
        }
        success {
            echo 'PyroVeil validation passed!'
        }
        failure {
            echo 'PyroVeil validation failed - check logs'
        }
    }
}
```

### Jenkinsfile (Scripted)

```groovy
node {
    try {
        stage('Checkout') {
            checkout scm
            sh 'git submodule update --init --recursive'
        }
        
        stage('Dependencies') {
            sh 'sudo apt-get update && sudo apt-get install -y cmake ninja-build g++ jq'
        }
        
        stage('Build') {
            sh '''
                cmake -B build -G Ninja
                ninja -C build
            '''
        }
        
        stage('Validate') {
            parallel(
                "Modules": {
                    sh './scripts/test-modules.sh'
                },
                "Logging": {
                    sh './scripts/test-logging.sh'
                }
            )
        }
        
        stage('Full Check') {
            sh './scripts/run-full-validation.sh'
        }
        
        currentBuild.result = 'SUCCESS'
    } catch (Exception e) {
        currentBuild.result = 'FAILURE'
        throw e
    } finally {
        archiveArtifacts artifacts: 'build/**/*.so,build/**/*.json', allowEmptyArchive: true
        cleanWs()
    }
}
```

## Local Pre-Commit Hooks

### Git Pre-Commit Hook

Create `.git/hooks/pre-commit`:

```bash
#!/usr/bin/env bash
#
# Pre-commit hook for PyroVeil
# Runs quick validation before allowing commit

set -e

echo "Running PyroVeil pre-commit validation..."

# Quick checks
./scripts/ci-validate.sh quick

echo "✓ Pre-commit validation passed"
exit 0
```

Make it executable:
```bash
chmod +x .git/hooks/pre-commit
```

### Pre-Push Hook

Create `.git/hooks/pre-push`:

```bash
#!/usr/bin/env bash
#
# Pre-push hook for PyroVeil
# Runs full validation before allowing push

set -e

echo "Running full PyroVeil validation before push..."

./scripts/run-full-validation.sh

echo "✓ All validation checks passed - push allowed"
exit 0
```

Make it executable:
```bash
chmod +x .git/hooks/pre-push
```

## Docker-Based CI

### Dockerfile for CI

```dockerfile
FROM fedora:latest

# Install build dependencies
RUN dnf install -y \
    cmake \
    gcc-c++ \
    ninja-build \
    git \
    vulkan-headers \
    shellcheck \
    cppcheck \
    jq \
    && dnf clean all

# Set working directory
WORKDIR /workspace

# Copy source
COPY . .

# Initialize submodules
RUN git submodule update --init --recursive

# Default command: run validation
CMD ["./scripts/run-full-validation.sh"]
```

### Docker Compose for CI

```yaml
version: '3.8'

services:
  pyroveil-ci:
    build: .
    volumes:
      - .:/workspace
      - build-cache:/workspace/build
    command: ./scripts/run-full-validation.sh
  
  pyroveil-test:
    build: .
    volumes:
      - .:/workspace
    command: ./scripts/test-modules.sh

volumes:
  build-cache:
```

Run locally:
```bash
docker-compose up pyroveil-ci
docker-compose up pyroveil-test
```

## Continuous Deployment

### GitHub Actions Release Workflow

```yaml
name: Release PyroVeil

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive
      
      - name: Install dependencies
        run: sudo apt-get install -y cmake ninja-build g++
      
      - name: Build Release
        run: |
          cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
          ninja -C build
      
      - name: Package
        run: |
          mkdir -p pyroveil-${{ github.ref_name }}
          cp build/layer/libVkLayer_pyroveil_64.so pyroveil-${{ github.ref_name }}/
          cp build/layer/VkLayer_pyroveil_64.json pyroveil-${{ github.ref_name }}/
          tar -czf pyroveil-${{ github.ref_name }}-linux-x64.tar.gz pyroveil-${{ github.ref_name }}
      
      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: pyroveil-${{ github.ref_name }}-linux-x64.tar.gz
```

## Troubleshooting

### Build Fails in CI but Works Locally

```bashrecursive --force
cmake -B build -G Ninja
ninja -C build
```

### CI Timeout

Increase timeout in GitHub Actions:

```yaml
jobs:
  build:
    timeout-minutes: 30
```

### Cache Issues

Add caching to speed up builds:

```yaml
- name: Cache build
  uses: actions/cache@v4
  with:
    path: |
      build/
      third_party/
    key: ${{ runner.os }}-build-${{ hashFiles('**/CMakeLists.txt') }}
```

## Best Practices

- Always run validation before pushing code
- Use pre-commit hooks for local validation
- Cache dependencies in CI to speed up builds
- Run full validation on main branch and PRs
- Archive build artifacts for debugging
- Test on multiple distributions before release
