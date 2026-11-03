#!/usr/bin/env python3
"""make-metadata.py <papers-dir> <out-dir>

Writes <out-dir>/<folder>/<name>.sdr/custom_metadata.lua for every row of papers.tsv
(KOReader custom metadata: clean title/authors in the library and in the AI context).
<papers-dir> has the fetch-papers.sh layout (<folder>/<file>). Needs `pdfinfo`
(poppler) for page counts / original PDF metadata; without it nothing is written and
the pre-generated files in library/ are used as they are."""
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def q(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'


def main():
    src, out = sys.argv[1], sys.argv[2]
    if not shutil.which("pdfinfo"):
        print("make-metadata: pdfinfo not found, keeping pre-generated metadata")
        return
    for line in open(os.path.join(HERE, "papers.tsv"), encoding="utf-8"):
        line = line.rstrip("\n")
        if not line or line.startswith("#"):
            continue
        _num, folder, fname, title, authors, _url, _sha = line.split("\t")
        rel = fname if folder == "." else os.path.join(folder, fname)
        pdf = os.path.join(src, rel)
        if not os.path.exists(pdf):
            print("skip (missing)", rel)
            continue
        info = subprocess.run(["pdfinfo", pdf], capture_output=True, text=True).stdout
        meta = {}
        for l in info.splitlines():
            if ":" in l:
                k, v = l.split(":", 1)
                meta[k.strip()] = v.strip()
        pages = int(meta.get("Pages", "0") or 0)
        orig_title = meta.get("Title", "")
        orig_author = meta.get("Author", "")
        sdr = os.path.join(out, rel[:-len(".pdf")] + ".sdr")
        os.makedirs(sdr, exist_ok=True)
        body = ["-- custom metadata for " + fname, "return {",
                '    ["custom_props"] = {',
                '        ["authors"] = %s,' % q(authors),
                '        ["title"] = %s,' % q(title),
                "    },",
                '    ["doc_props"] = {']
        if orig_author:
            body.append('        ["authors"] = %s,' % q(orig_author))
        body.append('        ["pages"] = %d,' % pages)
        if orig_title:
            body.append('        ["title"] = %s,' % q(orig_title))
        body += ["    },", "}", ""]
        with open(os.path.join(sdr, "custom_metadata.lua"), "w", encoding="utf-8") as fh:
            fh.write("\n".join(body))
        print("ok", rel)


if __name__ == "__main__":
    main()
