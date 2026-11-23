#!/usr/bin/env bash
# Cut a release: bump the app version, run the checks, commit, tag and push.
#
#   ./scripts/release.sh X.Y.Z [--dry-run]
#
# Run it from a clean main branch. The app-vX.Y.Z tag triggers the release
# workflow (only app-v* tags publish the desktop app; vX.Y.Z belongs to the
# terminal script).
#
# Required tools: git, node (pnpm), cargo.

set -euo pipefail

usage() {
    sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
}

die() {
    echo "Error: $*" >&2
    exit 1
}

VERSION=""
DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        -h | --help)
            usage
            exit 0
            ;;
        -*)
            die "opción desconocida: $arg"
            ;;
        *)
            [[ -z "$VERSION" ]] || die "solo se admite una versión"
            VERSION="$arg"
            ;;
    esac
done

[[ -n "$VERSION" ]] || {
    usage
    exit 1
}
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "versión inválida: $VERSION (se espera X.Y.Z)"

TAG="app-v$VERSION"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || die "no estás dentro de un repositorio git"
cd "$ROOT"

[[ "$(git branch --show-current)" == "main" ]] || die "lanza el release desde la rama main"
[[ -z "$(git status --porcelain)" ]] || die "el árbol de trabajo no está limpio; haz commit o stash antes de seguir"
git remote get-url origin >/dev/null 2>&1 || die "falta el remoto origin"

PUBKEY="$(node -p "require('./app/src-tauri/tauri.conf.json').plugins.updater.pubkey || ''")"
if [[ -z "$PUBKEY" || "$PUBKEY" == REPLACE_* ]]; then
    die "configura la clave del updater en app/src-tauri/tauri.conf.json (plugins.updater.pubkey)"
fi

if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
    die "la etiqueta $TAG ya existe en local"
fi
if [[ -n "$(git ls-remote --tags origin "refs/tags/$TAG")" ]]; then
    die "la etiqueta $TAG ya existe en origin; sube la versión"
fi

CURRENT="$(node -p "require('./app/package.json').version")"
echo "Versión: $CURRENT -> $VERSION (etiqueta $TAG)"

echo "Comprobaciones (Rust + frontend)..."
(
    cd app/src-tauri
    cargo fmt --check
    cargo clippy --all-targets -- -D warnings
    cargo test
)
(
    cd app
    pnpm exec tsc --noEmit
    pnpm build
)

if [[ "$DRY_RUN" == 1 ]]; then
    echo "Dry run: no se ha cambiado nada. Todo listo para lanzar $TAG."
    exit 0
fi

echo "Actualizando versiones..."
FILES=(app/package.json app/src-tauri/tauri.conf.json app/src-tauri/Cargo.toml app/src-tauri/Cargo.lock)
sed -i -E "s/^  \"version\": \"[0-9]+\.[0-9]+\.[0-9]+\",$/  \"version\": \"$VERSION\",/" \
    app/package.json app/src-tauri/tauri.conf.json
sed -i -E "s/^version = \"[0-9]+\.[0-9]+\.[0-9]+\"$/version = \"$VERSION\"/" \
    app/src-tauri/Cargo.toml
# Only the remo entry in the lock file: package entries start with name/version.
sed -i -E "/^name = \"remo\"$/{n;s/^version = \".*\"$/version = \"$VERSION\"/}" \
    app/src-tauri/Cargo.lock

if [[ "$(node -p "require('./app/package.json').version")" != "$VERSION" ]] ||
    [[ "$(node -p "require('./app/src-tauri/tauri.conf.json').version")" != "$VERSION" ]] ||
    ! grep -q "^version = \"$VERSION\"$" app/src-tauri/Cargo.toml ||
    [[ "$(sed -n '/^name = \"remo\"$/{n;p;}' app/src-tauri/Cargo.lock)" != "version = \"$VERSION\"" ]]; then
    git checkout -- "${FILES[@]}"
    die "no se pudo actualizar la versión en todos los archivos"
fi

echo "Creando el commit y la etiqueta..."
git add "${FILES[@]}"
git commit -m "chore(app): release $TAG"
git tag -a "$TAG" -m "Remo $TAG"

echo "Subiendo main y $TAG..."
if ! git push --atomic origin main "refs/tags/$TAG"; then
    die "no se pudo subir; el commit y la etiqueta están en local. Reintenta: git push --atomic origin main refs/tags/$TAG"
fi

echo "Release $TAG lanzado:"
echo "  https://github.com/$(git remote get-url origin | sed -E 's#.*[:/]([^/]+/[^/.]+)(\.git)?$#\1#')/actions/workflows/release-app.yml"
