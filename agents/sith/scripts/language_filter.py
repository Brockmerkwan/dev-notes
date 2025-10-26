#!/usr/bin/env python3
"""
language_filter.py — injects short Sith phrases into English text.
usage: python language_filter.py "Your text here"
"""
import json, random, sys, pathlib

glossary_path = pathlib.Path(__file__).parent.parent / "lore" / "glossary.json"
words = json.loads(open(glossary_path).read())
keys = list(words.keys())

def inject_sith(text, chance=0.2):
    out = []
    for word in text.split():
        if random.random() < chance:
            sith = random.choice(keys)
            out.append(f"{word} ({sith})")
        else:
            out.append(word)
    return " ".join(out)

if __name__ == "__main__":
    text = " ".join(sys.argv[1:]) or "The flame has awoken."
    print(inject_sith(text))
