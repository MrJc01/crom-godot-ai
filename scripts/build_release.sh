#!/bin/bash
# ==============================================================================
# CromAI Build Release Script
# Gera 1 executável standalone por OS na pasta release/
#
# Uso:
#   ./scripts/build_release.sh          # Builda todos os 3 OS
#   ./scripts/build_release.sh linux    # Builda só Linux
#   ./scripts/build_release.sh windows  # Builda só Windows
#   ./scripts/build_release.sh macos    # Builda só macOS
#   ./scripts/build_release.sh sync     # Só sincroniza o addon para releases/
#
# Além do export, o script sincroniza addons/crom_ai/ para o bundle portátil
# releases/ (gitignorado), levando apenas o binário da plataforma do host.
# ==============================================================================

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RELEASE_DIR="${PROJECT_DIR}/release"
RELEASES_DIR="${PROJECT_DIR}/releases"
GODOT_BIN="${GODOT_BIN:-godot}"
VERSION="1.0.0"
APP_NAME="CromAI"
TARGET="${1:-all}"

# Sufixo de binário do host (mesma lógica de crom_plugin._current_bin_suffix).
host_bin_suffix() {
    local arch="amd64"
    case "$(uname -m)" in
        aarch64|arm64) arch="arm64" ;;
    esac
    case "$(uname -s)" in
        Darwin) echo "darwin-${arch}" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows-${arch}.exe" ;;
        *) echo "linux-${arch}" ;;
    esac
}

# Espelha addons/crom_ai/ em releases/addons/crom_ai/, com bin/ contendo só o
# binário do host + CLI (mesma regra de crom_plugin._prune_foreign_binaries).
sync_releases_addon() {
    if [ ! -d "${RELEASES_DIR}" ]; then
        echo "AVISO: ${RELEASES_DIR} não existe; pulando sync do addon."
        return 0
    fi
    local SRC="${PROJECT_DIR}/addons/crom_ai"
    local DST="${RELEASES_DIR}/addons/crom_ai"
    local SUFFIX
    SUFFIX="$(host_bin_suffix)"

    echo ""
    echo "--- Sync releases/addons/crom_ai (binário: ${SUFFIX}) ---"
    mkdir -p "${DST}/bin"
    rsync -a --delete --exclude "bin/" --exclude "chat_history/" "${SRC}/" "${DST}/"

    for f in "crom-agente-${SUFFIX}" "godot-mcp-${SUFFIX}" "crom-agente" "crom-agente-cli"; do
        if [ -f "${SRC}/bin/${f}" ]; then
            cp -a "${SRC}/bin/${f}" "${DST}/bin/${f}"
        fi
    done

    local removed=0
    local base
    for f in "${DST}/bin/"crom-agente-* "${DST}/bin/"godot-mcp-*; do
        [ -f "$f" ] || continue
        base="$(basename "$f")"
        if [[ "${base}" != *"${SUFFIX}" && "${base}" != "crom-agente-cli" ]]; then
            rm -f "$f"
            removed=$((removed + 1))
        fi
    done
    echo "OK: addon sincronizado em ${DST} (${removed} binário(s) de outras plataformas removido(s))"
}

if [ "${TARGET}" = "sync" ]; then
    sync_releases_addon
    exit 0
fi

echo "======================================"
echo "  CromAI Build Release v${VERSION}"
echo "======================================"
echo "Project: ${PROJECT_DIR}"
echo "Output:  ${RELEASE_DIR}"
echo ""

# Verificar se o Godot está instalado
if ! command -v "${GODOT_BIN}" &>/dev/null; then
    echo "ERRO: Godot não encontrado. Defina GODOT_BIN ou instale o Godot."
    echo "  Ex: GODOT_BIN=/home/j/.local/bin/godot ./scripts/build_release.sh"
    exit 1
fi

GODOT_VERSION=$("${GODOT_BIN}" --version 2>/dev/null | head -1)
echo "Godot: ${GODOT_VERSION}"

# Verificar export templates
TEMPLATE_DIR="${HOME}/.local/share/godot/export_templates"
if [ ! -d "${TEMPLATE_DIR}" ] || [ -z "$(ls -A "${TEMPLATE_DIR}" 2>/dev/null)" ]; then
    echo ""
    echo "AVISO: Export Templates não encontrados em ${TEMPLATE_DIR}"
    echo "Para instalar:"
    echo "  1. Abra o Godot Editor"
    echo "  2. Vá em Editor > Manage Export Templates"
    echo "  3. Clique 'Download and Install'"
    echo ""
    echo "Ou baixe manualmente de:"
    echo "  https://godotengine.org/download/"
    exit 1
fi

# Verificar export_presets.cfg
if [ ! -f "${PROJECT_DIR}/export_presets.cfg" ]; then
    echo "AVISO: export_presets.cfg não encontrado."
    echo "Criando presets padrão..."
    cat > "${PROJECT_DIR}/export_presets.cfg" << 'EOF'
[preset.0]

name="Linux"
platform="Linux"
runnable=true
export_filter="all_resources"
include_filter=""
exclude_filter="external/*, .git/*, release/*"
export_path="release/linux/CromAI.x86_64"

[preset.0.options]

binary_format/architecture="x86_64"

[preset.1]

name="Windows Desktop"
platform="Windows Desktop"
runnable=true
export_filter="all_resources"
include_filter=""
exclude_filter="external/*, .git/*, release/*"
export_path="release/windows/CromAI.exe"

[preset.1.options]

binary_format/architecture="x86_64"

[preset.2]

name="macOS"
platform="macOS"
runnable=true
export_filter="all_resources"
include_filter=""
exclude_filter="external/*, .git/*, release/*"
export_path="release/macos/CromAI.zip"

[preset.2.options]

binary_format/architecture="universal"
EOF
    echo "Presets criados."
fi

# Função de build
build_platform() {
    local PRESET_NAME="$1"
    local OUTPUT_DIR="$2"
    local OUTPUT_FILE="$3"

    echo ""
    echo "--- Building ${PRESET_NAME} ---"
    mkdir -p "${RELEASE_DIR}/${OUTPUT_DIR}"

    "${GODOT_BIN}" --headless --export-release "${PRESET_NAME}" "${RELEASE_DIR}/${OUTPUT_DIR}/${OUTPUT_FILE}" 2>&1 || {
        echo "ERRO ao buildar ${PRESET_NAME}. Verifique os export templates."
        return 1
    }

    if [ -f "${RELEASE_DIR}/${OUTPUT_DIR}/${OUTPUT_FILE}" ]; then
        local SIZE=$(du -h "${RELEASE_DIR}/${OUTPUT_DIR}/${OUTPUT_FILE}" | cut -f1)
        echo "OK: ${RELEASE_DIR}/${OUTPUT_DIR}/${OUTPUT_FILE} (${SIZE})"
    else
        echo "FALHA: Arquivo não gerado."
        return 1
    fi
}

case "${TARGET}" in
    linux)
        build_platform "Linux" "linux" "CromAI.x86_64"
        ;;
    windows)
        build_platform "Windows Desktop" "windows" "CromAI.exe"
        ;;
    macos)
        build_platform "macOS" "macos" "CromAI.zip"
        ;;
    all)
        build_platform "Linux" "linux" "CromAI.x86_64"
        build_platform "Windows Desktop" "windows" "CromAI.exe"
        build_platform "macOS" "macos" "CromAI.zip"
        ;;
    *)
        echo "Uso: $0 [linux|windows|macos|all|sync]"
        exit 1
        ;;
esac

sync_releases_addon

echo ""
echo "======================================"
echo "  Build completo!"
echo "======================================"
echo ""
ls -lh "${RELEASE_DIR}"/*/* 2>/dev/null || echo "(Nenhum executável gerado)"
