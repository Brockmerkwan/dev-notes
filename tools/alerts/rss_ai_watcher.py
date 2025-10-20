#!/usr/bin/env python3
import os,time,json,subprocess,feedparser,requests,yaml
CONF=os.getenv("RSS_CONF","/app/rss.yaml")
MIN=float(os.getenv("MIN_SCORE","0.4"));MAX=int(os.getenv("MAX_SEND","8"))
BATCH=os.getenv("BATCH_MODE","1")=="1";AI_TIMEOUT=int(os.getenv("AI_TIMEOUT","10"))
def log(x):print(time.strftime("%F %T"),x,flush=True)
def conf(p): 
  try:return yaml.safe_load(open(p)) or {}
  except: return {}
def ntfy(t,b,tp): 
  try:requests.post(f"https://ntfy.sh/{tp}",data=b.encode(),headers={"Title":t})
  except:pass
def score(t,s,kws):t=t.lower();s=s.lower();return min(1,sum(1 for k in kws if k in t or k in s)/3)
cfg=conf(CONF);feeds=cfg.get("feeds",["https://hnrss.org/frontpage"]);tp=cfg.get("topic","brock-live-feed")
kws=cfg.get("keywords",["devops","automation","macos","homebrew","ollama","llm","docker"])
picked=[]
for f in feeds:
  log(f"[rss] {f}");fp=feedparser.parse(f)
  for e in fp.entries[:20]:
    title=e.get("title","");link=e.get("link","");s=e.get("summary","")
    sc=score(title,s,kws)
    if sc>=MIN:picked.append(f"• {title}\n{link}")
    if len(picked)>=MAX:break
body="\n\n".join(picked)[:4000] or "no matches"
ntfy(f"AI Watcher: {len(picked)} picks",body,tp)
log(f"sent={len(picked)}")
