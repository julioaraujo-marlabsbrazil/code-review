#!/usr/bin/env bash
#
# Instala os agents e skills de Code Review (marlabs-code-review) na pasta .github/ do projeto.
#
# Copia o pacote para os mesmos caminhos usados pelo POC:
#   .github/agents/        (2 agents)
#   .github/skills/        (skills)
#   .github/code-review/   (CHANGELOG.md e review-decisions.md)
#
# Cuidados:
#   - Confere o SHA256SUMS do pacote antes de copiar e os arquivos instalados depois de copiar.
#   - Nunca sobrescreve .github/code-review/review-decisions.md (decisoes do time).
#   - Se ja houver uma versao instalada, mostra as versoes e pede confirmacao antes de substituir.
#   - Nao altera nada fora de .github/agents, .github/skills e .github/code-review.
#   - Nao faz commit: o time revisa e comita a alteracao.
#
# Uso:
#   bash install.sh [--target <projeto>] [--source <marketplace>] [--repo code-review] [--ref v1.0.0] [--yes] [--dry-run]
#
#   A partir de um clone do repositorio do marketplace (usa o pacote do clone):
#     bash install.sh --target /caminho/do/projeto
#
#   Remoto, executado na raiz do projeto (--repo/--ref explicitos sempre baixam do repositorio):
#     curl -fsSL https://raw.githubusercontent.com/code-review/v1.0.0/install.sh | bash
#
set -euo pipefail

SOURCE=""
REPO="code-review"
REF="v1.0.0"
TARGET=""
YES=0
DRY_RUN=0
PLUGIN_REL="plugins/marlabs-code-review"
TEMP_CLONE=""
REMOTE_REQUESTED=0

err() { printf 'ERRO: %s\n' "$*" >&2; exit 1; }

cleanup() { if [ -n "$TEMP_CLONE" ] && [ -d "$TEMP_CLONE" ]; then rm -rf "$TEMP_CLONE"; fi; }
trap cleanup EXIT

while [ $# -gt 0 ]; do
  case "$1" in
    --source)  SOURCE="${2:-}"; shift 2 ;;
    --repo)    REPO="${2:-}"; REMOTE_REQUESTED=1; shift 2 ;;
    --ref)     REF="${2:-}"; REMOTE_REQUESTED=1; shift 2 ;;
    --target)  TARGET="${2:-}"; shift 2 ;;
    --yes|-y)  YES=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) sed -n '2,25p' "${BASH_SOURCE[0]:-/dev/null}" 2>/dev/null | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) err "Opcao desconhecida: $1" ;;
  esac
done

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1
  else err "sha256sum ou shasum nao encontrado."; fi
}

package_version() {
  [ -f "$1" ] || return 0
  local v
  v=$(sed -n 's/.*do pacote: \([^*]*\)\*\*.*/\1/p' "$1" | head -n1 | tr -d '\r')
  printf '%s' "${v:-desconhecida}"
}

destination_path() {
  case "$1" in
    com.github.copilot/agents/*.agent.md)
      local name="${1#com.github.copilot/agents/}"
      printf '.github/agents/%s.md' "${name%.agent.md}" ;;
    skills/*|code-review/*) printf '.github/%s' "$1" ;;
    *) err "Arquivo inesperado no SHA256SUMS: $1" ;;
  esac
}

# 1. Projeto de destino
[ -n "$TARGET" ] || TARGET="$(pwd)"
[ -d "$TARGET" ] || err "Pasta de destino nao encontrada: $TARGET"
command -v git >/dev/null 2>&1 || err "git nao encontrado no PATH."
ROOT="$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null)" \
  || err "O destino nao esta dentro de um repositorio git: $TARGET. Os agents dependem do git para calcular o Change Set."

# 2. Origem do pacote
if [ -z "$SOURCE" ] && [ "$REMOTE_REQUESTED" -eq 0 ] && [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  [ -f "$SCRIPT_DIR/$PLUGIN_REL/plugin.json" ] && SOURCE="$SCRIPT_DIR"
fi
if [ -z "$SOURCE" ]; then
  [ "$REPO" != "code-review" ] || err "Repositorio do marketplace nao configurado. Informe --repo code-review ou --source <pasta do marketplace>."
  URL="$REPO"
  case "$REPO" in *:*|*@*|*.git) ;; *) URL="https://github.com/$REPO.git" ;; esac
  TEMP_CLONE="$(mktemp -d 2>/dev/null || mktemp -d -t marlabs-code-review)"
  echo "Baixando $URL ($REF)..."
  git -c core.autocrlf=false clone --quiet --depth 1 --branch "$REF" "$URL" "$TEMP_CLONE/repo" \
    || err "Falha ao clonar $URL na referencia $REF."
  SOURCE="$TEMP_CLONE/repo"
fi
PKG="$SOURCE/$PLUGIN_REL"
SUMS="$SOURCE/SHA256SUMS"
[ -f "$PKG/plugin.json" ] || err "Pacote nao encontrado em: $PKG"
[ -f "$SUMS" ] || err "SHA256SUMS nao encontrado em: $SOURCE"

# 3. Conferencia do pacote e plano
ACTIONS=(); RELS=(); DSTS=(); HASHES=()
while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"
  [ -n "$line" ] || continue
  hash="${line%% *}"
  rel="${line#* }"; rel="${rel#\*}"; rel="${rel# }"
  printf '%s' "$hash" | grep -Eq '^[0-9a-fA-F]{64}$' || err "Linha invalida no SHA256SUMS: $line"
  hash="$(printf '%s' "$hash" | tr 'A-F' 'a-f')"
  [ -f "$PKG/$rel" ] || err "Arquivo do pacote ausente: $rel"
  [ "$(sha256 "$PKG/$rel")" = "$hash" ] || err "Hash divergente no pacote: $rel. O download pode estar corrompido."
  dst="$(destination_path "$rel")"
  action="criar"
  if [ -e "$ROOT/$dst" ]; then
    if [ "$dst" = ".github/code-review/review-decisions.md" ]; then action="manter"
    elif [ "$(sha256 "$ROOT/$dst")" = "$hash" ]; then action="igual"
    else action="substituir"; fi
  fi
  ACTIONS+=("$action"); RELS+=("$rel"); DSTS+=("$dst"); HASHES+=("$hash")
done < "$SUMS"
[ "${#RELS[@]}" -gt 0 ] || err "SHA256SUMS vazio."

PLUGIN_VERSION="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PKG/plugin.json" | head -n1)"
NEW_VERSION="$(package_version "$PKG/skills/code-review-core/SKILL.md")"
OLD_VERSION="$(package_version "$ROOT/.github/skills/code-review-core/SKILL.md")"

echo
echo "Projeto:            $ROOT"
echo "Pacote (plugin):    $PLUGIN_VERSION"
echo "Versao das regras:  $NEW_VERSION"
echo "Versao instalada:   ${OLD_VERSION:-nenhuma}"
echo
TO_WRITE=0; TO_REPLACE=0
for i in "${!RELS[@]}"; do
  printf '  %-11s %s\n' "${ACTIONS[$i]}" "${DSTS[$i]}"
  case "${ACTIONS[$i]}" in
    criar) TO_WRITE=$((TO_WRITE + 1)) ;;
    substituir) TO_WRITE=$((TO_WRITE + 1)); TO_REPLACE=$((TO_REPLACE + 1)) ;;
  esac
done
echo

if [ "$TO_WRITE" -eq 0 ]; then
  echo "Nada a fazer: o pacote ja esta instalado nesta versao."
  exit 0
fi
if [ "$DRY_RUN" -eq 1 ]; then
  echo "Simulacao (--dry-run): nenhum arquivo foi alterado."
  exit 0
fi
if [ "$TO_REPLACE" -gt 0 ] && [ "$YES" -ne 1 ]; then
  # Via "curl | bash" a entrada padrao e o proprio script: a pergunta e lida do terminal.
  if ! { exec 3</dev/tty; } 2>/dev/null; then
    err "$TO_REPLACE arquivo(s) seriam substituidos. Execute novamente com --yes para confirmar."
  fi
  printf '%s arquivo(s) existentes serao substituidos. Continuar? (s/N) ' "$TO_REPLACE"
  read -r answer <&3 || answer=""
  exec 3<&-
  case "$answer" in
    s|S|sim|SIM|y|Y|yes|YES) ;;
    *) echo "Instalacao cancelada. Nenhum arquivo foi alterado."; exit 0 ;;
  esac
fi

# 4. Copia
for i in "${!RELS[@]}"; do
  case "${ACTIONS[$i]}" in
    criar|substituir)
      mkdir -p "$(dirname "$ROOT/${DSTS[$i]}")"
      cp "$PKG/${RELS[$i]}" "$ROOT/${DSTS[$i]}" ;;
  esac
done

# 5. Conferencia da instalacao
for i in "${!RELS[@]}"; do
  case "${ACTIONS[$i]}" in
    criar|substituir)
      [ "$(sha256 "$ROOT/${DSTS[$i]}")" = "${HASHES[$i]}" ] || err "Hash divergente apos a copia: ${DSTS[$i]}" ;;
  esac
done

echo "Instalado com sucesso: $TO_WRITE arquivo(s) gravado(s) e conferido(s)."
echo
echo "Proximos passos (revisar e comitar):"
echo "  git status -- .github"
echo "  git checkout -b chore/code-review-$NEW_VERSION"
echo "  git add .github/agents .github/skills .github/code-review"
echo "  git commit -m \"chore: instala Code Review $NEW_VERSION\""
