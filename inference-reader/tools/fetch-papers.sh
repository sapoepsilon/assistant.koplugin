#!/usr/bin/env bash
# fetch-papers.sh <dest-dir> [papers.tsv]
# Downloads every paper listed in papers.tsv into <dest-dir>/<folder>/<file>
# (folder "." = top level). Files that already exist with the recorded sha256 are
# skipped. A hash mismatch is only a warning (arXiv re-renders some PDFs); a failed
# download or a non-PDF response is an error.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
dest=${1:?usage: fetch-papers.sh <dest-dir> [papers.tsv]}
tsv=${2:-$here/papers.tsv}
ua="koreader-inference-reader/1.0 (+https://github.com/sapoepsilon/assistant.koplugin)"

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

mkdir -p "$dest"
ok=0 skipped=0 failed=0 warned=0
while IFS=$'\t' read -r num folder file _title _authors url sha; do
  [[ -z "$num" || "$num" == \#* ]] && continue
  dir=$dest; [[ "$folder" != "." ]] && dir=$dest/$folder
  mkdir -p "$dir"
  out=$dir/$file
  if [[ -s "$out" && "$(sha256 "$out")" == "$sha" ]]; then
    skipped=$((skipped + 1)); continue
  fi
  tmp=$out.part
  if ! curl -fsSL --retry 3 --retry-delay 2 -A "$ua" -o "$tmp" "$url"; then
    echo "FAIL  $num $file ($url)" >&2; rm -f "$tmp"; failed=$((failed + 1)); continue
  fi
  if [[ "$(head -c 4 "$tmp")" != "%PDF" ]]; then
    echo "FAIL  $num $file: not a PDF ($url)" >&2; rm -f "$tmp"; failed=$((failed + 1)); continue
  fi
  mv "$tmp" "$out"
  if [[ "$(sha256 "$out")" != "$sha" ]]; then
    echo "WARN  $num $file: sha256 differs from papers.tsv (re-rendered upstream?)" >&2
    warned=$((warned + 1))
  fi
  echo "ok    $num $file"
  ok=$((ok + 1))
  sleep 1 # be polite to arXiv
done < "$tsv"

echo "papers: $ok downloaded, $skipped already present, $warned hash warnings, $failed failed -> $dest"
[[ $failed -eq 0 ]]
