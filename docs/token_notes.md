# 🧠 Brock Core OS — Dashboard Token Guide

**Config file:** ~/.config/brock_core/core.env  
**Variable:** CORE_TOKEN=<uuid>

---

## 🔧 Refresh or Replace Token
TOKEN=$(uuidgen)
echo "CORE_TOKEN=$TOKEN" > ~/.config/brock_core/core.env
export CORE_TOKEN=$TOKEN
bash ~/Projects/devnotes/tools/core_dash.sh

Frontend auto-saves the token in browser localStorage (core_token).  
You only need to paste manually if:
- You clear browser data, or  
- The backend regenerates a new token.

---

## 🛠 Optional Auto-Fill Patch
Edit ~/Projects/devnotes/tools/core_dash_web.py  
Add this above the HTML output section:

    # Auto-fill token field in UI
    html = html.replace('<input id="tok"', f'<input id="tok" value="{CORE_TOKEN}"')

This pre-populates the token on every reload so you don’t have to paste it.
