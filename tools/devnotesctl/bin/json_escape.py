#!/usr/bin/env python3
import json,sys,io
data = sys.stdin.read() if len(sys.argv) == 1 else open(sys.argv[1],'r',encoding='utf-8').read()
print(json.dumps(data))
