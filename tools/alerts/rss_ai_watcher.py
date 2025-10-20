#!/usr/bin/env python3
import os, sys, json, hashlib, subprocess, re
from pathlib import Path
import feedparser, requests, yaml

CONF = Path(os.environ.get("RSS_CONF", str(Path.home()/".brock/rss.yaml")))
STATE_DIR = Path(os.environ.get("RSS_STATE", str(Path.home()/".local/share/brock/rss")))
STATE_DIR.mkdir(parents=True, exist_ok=True)
DEBUG = os.getenv("DEBUG") == "1"
MAX_AI  = int(os.getenv("RSS_MAX_AI", "8"))    # max AI-scored items per feed per run
MAX_PUSH= int(os.getenv("RSS_MAX_PUSH", "8"))  # max pushes across all feeds per run
LLM_TIMEOUT = int(os.getenv("RSS_LLM_TIMEOUT", "8"))  # seconds per item

def log(*a):
    if DEBUG: print("[rss]", *a, file=sys.stdout, flush=True)

def load_conf():
    with open(CONF, "r") as f:
        return yaml.safe_load(f)

def entry_id(e):
    raw = (e.get("id") or "") + "|" + (e.get("link") or "") + "|" + (e.get("title") or "")
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()

def seen_path(feed_url):
    h = hashlib.sha256(feed_url.encode("utf-8")).hexdigest()[:16]
    return STATE_DIR / f"seen_{h}.json"

def load_seen(p):
    if p.exists():
        try: return set(json.loads(p.read_text()))
        except: return set()
    return set()

def save_seen(p, s):
    p.write_text(json.dumps(sorted(list(s))))

PROMPT = """You are Brock Core OS.
Respond with ONLY a single JSON object on one line. No prose, no code fences.
Keys: score (0..1), title, one_liner (<=20 words), reason (<=15 words).
Consider: devops, automation, macOS, Homebrew, ollama, LLM, GitHub Actions, Docker, Swift.
Item:
TITLE: {title}
LINK: {link}
SUMMARY: {summary}
"""

# tolerant JSON finder
def extract_json_object(text):
    line0 = text.strip().splitlines()[0].strip()
    try: return json.loads(line0)
    except: pass
    st=[]
    for i,ch in enumerate(text):
        if ch=='{': st.append(i)
        elif ch=='}' and st:
            j=st.pop()
            if not st:
                chunk = text[j:i+1]
                try: return json.loads(chunk)
                except:
                    chunk2 = chunk.replace("True","true").replace("False","false").replace("None","null")
                    try: return json.loads(chunk2)
                    except: pass
    return None

def ollama_json(model, prompt):
    try:
        res = subprocess.run(
            ["ollama", "run", model],
            input=prompt.encode("utf-8"),
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            timeout=LLM_TIMEOUT
        )
        out = res.stdout.decode("utf-8", errors="ignore").strip()
        if DEBUG: log("ollama out:", (out[:200]+"..." if len(out)>200 else out).replace("\n"," "))
        js = extract_json_object(out)
        if isinstance(js, dict) and "score" in js:
            return js
    except subprocess.TimeoutExpired:
        log("ollama timeout")
    except Exception as e:
        log("ollama err:", str(e))
    return {"score":0.0,"title":"","one_liner":"N/A","reason":"AI error"}

# NO-AI keyword scorer
def score_noai(title, summary, kws):
    text = f"{title} {summary}".lower()
    hits = sum(1 for k in kws if re.search(r'\b'+re.escape(k.lower())+r'\b', text))
    score = min(1.0, hits / max(1, len(kws)) * 3.0)
    one = (title or "Relevant item")
    reason = f"{hits} keyword hit(s)"
    return {"score": score, "title": title, "one_liner": one[:200], "reason": reason[:120]}

# ASCII header sanitizer (HTTP/1.1 headers are ISO-8859-1)
def ascii_sanitize(s: str) -> str:
    if not s: return ""
    repl = {
        "\u2013":"-", "\u2014":"-", "\u2018":"'", "\u2019":"'", "\u201c":'"', "\u201d":'"',
        "\u00a0":" ", "\u2026":"...", "\u200b":""
    }
    for k,v in repl.items():
        s = s.replace(k,v)
    s = re.sub(r"[^\x20-\x7E]", "", s)  # drop non-ASCII
    return s

def notify_ntfy(topic, title, body, link=None, tags=None, priority=3):
    url = f"https://ntfy.sh/{topic}"
    h_title = ascii_sanitize((title or "RSS Item"))[:180]
    headers = {"Title": h_title, "Priority": str(priority)}
    if tags: headers["Tags"] = ",".join(tags)
    if link: headers["Click"] = link  # Click may be non-ASCII-safe but URL should be ASCII
    try:
        r = requests.post(url, data=body.encode("utf-8"), headers=headers, timeout=15)
        if DEBUG: log("ntfy status", r.status_code)
    except Exception as e:
        log("ntfy err:", str(e))

def main():
    cfg = load_conf()
    topic = cfg.get("topic")
    model = cfg.get("model", "llama3.1:latest")
    min_score = float(cfg.get("min_score", 0.6))
    kws = cfg.get("keywords", [])
    feeds = cfg.get("feeds", [])
    FORCE = os.getenv("RSS_FORCE") == "1"
    NOAI  = os.getenv("RSS_NOAI") == "1"

    if not topic or not feeds:
        print("config missing 'topic' or 'feeds'", file=sys.stderr); sys.exit(1)

    sent = 0
    for feed in feeds:
        log("feed:", feed)
        if sent >= MAX_PUSH:
            log("push cap reached"); break

        fp = seen_path(feed)
        seen = load_seen(fp)
        d = feedparser.parse(feed)
        new_seen = set(seen)

        ai_count = 0
        for e in d.entries[:30]:
            if sent >= MAX_PUSH: break
            eid = entry_id(e)
            if (not FORCE) and (eid in seen):
                continue

            title = (e.get("title") or "").strip()
            link  = (e.get("link") or "").strip()
            summ  = (e.get("summary") or e.get("description") or "").strip().replace("\n"," ")[:800]

            if NOAI:
                js = score_noai(title, summ, kws)
            else:
                if ai_count >= MAX_AI:
                    log("ai cap reached on feed"); break
                js = ollama_json(model, PROMPT.format(title=title, link=link, summary=summ))
                ai_count += 1

            score = float(js.get("score", 0.0))
            one   = (js.get("one_liner") or "").strip()[:200]
            reason= (js.get("reason") or "").strip()[:120]
            if DEBUG: log("score:", score, "|", title[:80])

            if score >= min_score:
                prio = 4 if score >= 0.8 else 3
                body = f"{one}\n\nReason: {reason}\nScore: {score:.2f}"
                notify_ntfy(topic, title or "RSS Item", body, link=link, tags=["rss","ai"], priority=prio)
                sent += 1

            new_seen.add(eid)

        if not FORCE:
            save_seen(fp, new_seen)

    print(f"sent={sent}")

if __name__ == "__main__":
    main()
