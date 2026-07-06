from bs4 import BeautifulSoup
import re

with open('test.html', encoding='utf-16') as f:
    html = f.read()

soup = BeautifulSoup(html, 'html.parser')
imgs = soup.find_all('img')
found = 0
for img in imgs:
    src = img.get('src') or img.get('data-src') or ''
    if '/images/' in src and ('.png' in src or '.webp' in src):
        name = img.get('alt') or img.get('title') or ''
        print(name, '->', src)
        found += 1
        if found >= 20: break
