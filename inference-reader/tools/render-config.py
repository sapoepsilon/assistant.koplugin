#!/usr/bin/env python3
"""render-config.py [--placeholder] [--key-from-pi] <out.lua>

Builds assistant.koplugin/configuration.lua for the Inference-reader setup:
  prompts/system_prompt.configuration.lua   (INFERENCE_SYSTEM_PROMPT local)
  + provider_settings (proxycli-lan / proxycli-tailscale, from env)
  + prompts/features.configuration.lua      (features = {...})

Environment (all optional except the key):
  PROXY_API_KEY       API key for the proxy (never printed)
  PROXY_API_KEY_FILE  file whose first line is the key (alternative to PROXY_API_KEY)
  PROXY_LAN_URL       default http://192.168.50.31:8317/v1
  PROXY_TS_URL        default = PROXY_LAN_URL (placeholder until the proxy is on Tailscale)
  PROXY_MODEL         default hermes-default

--key-from-pi  fall back to the key in ~/.pi/agent/extensions/proxycli.ts
--placeholder  write "__PROXY_API_KEY__" instead of a key (configuration.example.lua)

The key is never printed; the output file is created with mode 0600. Only the key
*source* (env/file/pi/placeholder) is reported.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
KIT = os.path.dirname(HERE)
PLACEHOLDER = "__PROXY_API_KEY__"


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def resolve_key(args):
    if "--placeholder" in args:
        return PLACEHOLDER, "placeholder"
    k = os.environ.get("PROXY_API_KEY", "").strip()
    if k:
        return k, "env"
    f = os.environ.get("PROXY_API_KEY_FILE", "").strip()
    if f:
        with open(os.path.expanduser(f)) as fh:
            k = fh.readline().strip()
        if k:
            return k, "file"
    if "--key-from-pi" in args:
        p = os.path.expanduser("~/.pi/agent/extensions/proxycli.ts")
        if os.path.exists(p):
            with open(p) as fh:
                m = re.search(r'API_KEY = .*?"([A-Za-z0-9_\-]+)"', fh.read())
            if m:
                return m.group(1), "pi"
    raise SystemExit("render-config: no API key (set PROXY_API_KEY, PROXY_API_KEY_FILE "
                     "or pass --key-from-pi); nothing written")


def main():
    args = [a for a in sys.argv[1:] if a.startswith("--")]
    pos = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(pos) != 1:
        raise SystemExit(__doc__)
    out = pos[0]
    key, source = resolve_key(args)
    lan = os.environ.get("PROXY_LAN_URL") or "http://192.168.50.31:8317/v1"
    ts = os.environ.get("PROXY_TS_URL") or lan
    model = os.environ.get("PROXY_MODEL") or "hermes-default"

    with open(os.path.join(KIT, "prompts", "system_prompt.configuration.lua")) as fh:
        sysp = fh.read()
    with open(os.path.join(KIT, "prompts", "features.configuration.lua")) as fh:
        feat = fh.read().rstrip("\n")

    providers = f"""local CONFIGURATION = {{
    provider_settings = {{
        openai_proxycli_lan = {{
            display_name = "proxycli-lan",
            default = true,
            visible = true,
            model = {lua_str(model)},
            base_url = {lua_str(lan)},
            api_key = {lua_str(key)}, -- injected at deploy time (tools/render-config.py)
        }},
        openai_proxycli_tailscale = {{
            display_name = "proxycli-tailscale",
            visible = true,
            model = {lua_str(model)},
            base_url = {lua_str(ts)}, -- set PROXY_TS_URL once the proxy has a Tailscale address
            api_key = {lua_str(key)}, -- injected at deploy time (tools/render-config.py)
        }},
    }},
"""
    res = sysp + "\n" + providers + feat + "\n}\nreturn CONFIGURATION\n"
    if os.path.exists(out):
        os.remove(out)
    fd = os.open(out, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w") as fh:
        fh.write(res)
    print(f"render-config: wrote {out} (key source: {source}, model: {model})")


if __name__ == "__main__":
    main()
