#!/usr/bin/env python3
import os, sys, time, json, subprocess
from urllib.parse import urlparse
import feedparser, requests, yaml

CONF = os.getenv("RSS_CONF", "/app/rss.yaml")
MIN_SCORE = float(os.getenv("MIN_SCORE", "0.4"))
MAX_SEND = int(os.getenv("MAX_SEND", "8"))
AI_TIMEOUT = int(os.getenv("AI_TIMEOUT", "10"))
BATCH_MODE = os.getenv("BATCH_MODE", "1") == "1"

def log(msg):
    ts = time.strftime("%Y-%m-%d %H:%M:%S")
    print(f"{ts} | {msg}", flush=True)

def load_conf(path):
    try:
        with open(path, "r") as f:
            return yaml.safe_load(f) or {}
    except Exception as e:
        log(f"[rss] conf load err: {e}")
        return {}

def ntfy(title, body, topic):
    try:
        r = requests.post(
            f"https://ntfy.sh/{topic}",
            data=body.encode("utf-8"),
            headers={"Title": title, "Priority": "5"},
            timeout=10
        )
        log(f"[rss] ntfy status {r.status_code}")
    except Exception as e:
        log(f"[rss] ntfy err: {e}")

def ollama_json(model, prompt, host):
    try:
        env = os.environ.copy()
        if host:
            env["OLLAMA_HOST"] = host
        res = subprocess.run(
            ["ollama", "run", model, prompt],
            capture_output=True, text=True, timeout=AI_TIMEOUT, env=env
        )
        out = res.stdout.strip()
        cand = out.splitlines()[-1] if out else "{}"
        return json.loads(cand)
    except subprocess.TimeoutExpired:
        log("[rss] ollama timeout")
        return {}
    except FileNotFoundError:
        log("[rss] ollama err: [Errno 2] No such file or directory: 'ollama'")
        return {}
    except Exception as e:
        log(f"[rss] ollama err: {e}")
        return {}

PROMPT = """You are a filter for DevOps/macOS/automation news. Return compact JSON:
{"score":0..1,"title":"...", "one_liner":"...", "reason":"..."}
Evaluate ONLY this item:
Title: {title}
Link: {link}
Summary: {summary}
Keywords: devops, automation, macOS, homebrew, ollama, llm, github actions, docker, swift
"""

def quick_score(title, summary, keywords):
    t = (title or "").lower(); s = (summary or "").lower()
    hits = sum(1 for k in keywords if k.lower() in t or k.lower() in s)
    return min(1.0, hits/3.0)

def summarize_for_batch(items):
    lines = []
    for it in items:
        host = urlparse(it['link']).netloc
        lines.append(f"• {it['title']} – {it['one_liner']} ({host})\n{it['link']}")
    body = "\n\n".join(lines)
    if len(body) > 4000:
        body = body[:3800] + "\n…(truncated)"
    return "AI Watcher: {} picks".format(len(items)), body

def main():
    cfg = load_conf(CONF)
    feeds = cfg.get("feeds", ["https://hnrss.org/frontpage"])
    topic = cfg.get("topic", "brock-live-feed")
    model = cfg.get("model", "llama3.1:latest")
    keywords = cfg.get("keywords", ["devops","automation","macos","homebrew","ollama","llm","github actions","docker","swift"])
    ollama_host = os.getenv("OLLAMA_HOST", cfg.get("ollama_host", ""))

    sent = 0
    picked = []

    for feed in feeds:
        log(f"[rss] feed: {feed}")
        try:
            fp = feedparser.parse(feed)
        except Exception as e:
            log(f"[rss] feed err: {e}")
            continue

        for entry in fp.entries[:20]:
            if sent >= MAX_SEND and not BATCH_MODE:
                log("[rss] push cap reached")
                break
            title = entry.get("title","").strip()
            link = entry.get("link","").strip()
            summ = (entry.get("summary") or entry.get("description") or "").strip()

            js = {}
            if model:
                js = ollama_json(model, PROMPT.format(title=title, link=link, summary=summ), ollama_host)
            score = js.get("score")
            if score is None:
                score = quick_score(title, summ, keywords)

            log(f"[rss] score: {score} | {title}")

            if score >= MIN_SCORE:
                item = {
                    "title": (js.get("title") or title),
                    "one_liner": js.get("one_liner") or (summ[:140] + ("…" if len(summ)>140 else "")),
                    "reason": js.get("reason",""),
                    "link": link
                }
                if BATCH_MODE:
                    picked.append(item)
                else:
                    ntfy(item["title"], f"{item['one_liner']}\n{item['link']}", topic)
                    sent += 1

        if not BATCH_MODE and sent >= MAX_SEND:
            log("[rss] ai cap reached on feed")

    if BATCH_MODE and picked:
        picked = picked[:MAX_SEND]
        title, body = summarize_for_batch(picked)
        ntfy(title, body, topic)
        sent = len(picked)

    print(f"sent={sent}")

if __name__ == "__main__":
    main()
