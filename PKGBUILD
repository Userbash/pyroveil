# Maintainer: Your Name <your@email>

pkgname=pyroveil-git
pkgver=1.0.r0.g$(date +%s)
pkgrel=1
pkgdesc="Vulkan implicit layer for shader roundtrip/hacks (NVIDIA workaround, HansKristian-Work)"
arch=('x86_64')
url="https://github.com/HansKristian-Work/pyroveil"
license=('MIT')
depends=('vulkan-icd-loader' 'cmake' 'ninja' 'gcc' 'git')
makedepends=('distrobox' 'bash')
provides=('pyroveil')
conflicts=('pyroveil')
source=("git+https://github.com/HansKristian-Work/pyroveil.git")
md5sums=('SKIP')

pkgver() {
  cd "$srcdir/pyroveil"
  git describe --long --tags 2>/dev/null | sed 's/^v//;s/-/./g' || echo "1.0.r0.g$(date +%s)"
}

build() {
  cd "$srcdir/pyroveil"
  git submodule update --init --recursive
  cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$pkgdir/usr"
  ninja -C build
}

package() {
  cd "$srcdir/pyroveil"
  DESTDIR="$pkgdir" ninja -C build install
  # Install hacks
  install -d "$pkgdir/usr/share/pyroveil/hacks"
  cp -r hacks/* "$pkgdir/usr/share/pyroveil/hacks/"
  # Install example scripts
  install -Dm755 scripts/self_heal_build.sh "$pkgdir/usr/bin/pyroveil-self-heal"
  install -Dm755 scripts/uninstall_pyroveil.sh "$pkgdir/usr/bin/pyroveil-uninstall"
}
