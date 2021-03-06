#!/bin/bash
#Pre-setup
clear
echo '1.Apache or 2.Nginx'
echo
read -p 'Enter a Number:' num
if [ $num = 1 ]
  then
    ser=apache
elif [ $num = 2 ]
    then
      ser=nginx
  else
    clear
    echo 'Error invalid number.'
    sleep 2s
    ./openssl.sh
 fi
echo
read -p 'Email address:' email
echo
read -p 'Domain:' domain
clear

#Installing requirments
declare -A osInfo;
osInfo[/etc/redhat-release]=yum
osInfo[/etc/arch-release]=pacman
osInfo[/etc/gentoo-release]=emerge
osInfo[/etc/SuSE-release]=zypp
osInfo[/etc/debian_version]=apt
for f in ${!osInfo[@]}
do
    if [[ -f $f ]];then
      pman=${osInfo[$f]}

    fi
done
command -v $pman >> pg.txt
if [ -s pg.txt ]
  then
    rm -fr pg.txt
    clear
  else
    rm -fr pg.txt
    clear
    echo 'Failed to identify your package Manager'
    echo 'Please enter it below'
    echo
    read -p 'Package Manager:' pman
fi
echo 'Installing certbot'
sudo $pman install certbot python3-certbot-$ser
if [ -f /usr/bin/certbot ]
  then
    clear
  else
    echo
    echo 'Failed to install cerbot'
    echo "Try to install certbot and phython3-cerbot-$ser manually"
    echo
    exit
fi

#Port Forward
sudo netstat -anp | grep $ser | awk 'NR==1{print $4}' | grep -Eo '[0-9]{1,4}' | tail -1  >> port.txt
port=$(<port.txt)
if [ -s port.txt ]
  then
    rm -fr port.txt
    clear
    echo "Port forward $port to 80 on your router."
    echo 'Must be done to pass the cert test.'
    echo
    read -p 'Press Enter to continue'
  else
    rm -fr port.txt
    clear
    echo "Failed to fined which port $ser is running on"
    echo
    echo "Make sure $ser is running"
    echo "Try changing the port it is running on."
    exit
fi

#Get Certs
if [ $num = 1 ]
then
  sudo certonly --apache --noninteractive --agree-tos --email $email -d $domain
else
  sudo certbot --nginx --agree-tos --redirect --hsts --staple-ocsp --email $email -d $domain
fi
if sudo [ -e /etc/letsencrypt/live/$domain/cert.pem ]
  then
    clear
    echo
    echo 'Certificate successfully created'
    echo
    sleep 1s
  else
    echo
    echo 'Failed to create certificate.'
    echo
    exit
fi
echo 'Please enter a directory path where you want to save your certificate'
echo '(Jellyfin must have access to this directory)'
echo
echo 'Example /home/%username$/openssl'
read -p 'Directory:' path

#Patch for Jellyfin
clear
sudo openssl pkcs12 -export -out jellyfin.pfx -inkey /etc/letsencrypt/live/$domain/privkey.pem -in /etc/letsencrypt/live/$domain/cert.pem -passout pass:
mkdir $path
sudo mv jellyfin.pfx $path
sudo chown jellyfin:jellyfin $path/jellyfin.pfx
if sudo [ -e $path/jellyfin.pfx ]
  then
    clear
    echo
    echo 'Jellyfin cert patch successfully'
    echo
  else
    echo
    echo 'Failed to patch certificate for Jellyfin.'
    exit
fi

#Automated renewal
echo "0 0 * * *  root  certbot renew --quiet --no-self-upgrade --post-hook 'systemctl reload $ser'" | sudo tee -a /etc/cron.d/renew_certbot
echo "0 0 * * * sudo openssl pkcs12 -export -out /etc/letsencrypt/live/$domain/jellyfin.pfx -inkey /etc/letsencrypt/live/$domain/privkey.pem -in /etc/letsencrypt/live/$Domain/cert.pem -passout pass:" | sudo tee -a /etc/cron.d/renew_certbot
echo "0 0 * * * cp /etc/letsencrypt/live/$domain/jellyfin.pfx $path/jellyfin.pfx" | sudo tee -a /etc/cron.d/renew_certbot
echo "0 0 * * * sudo chown jellyfin:jellyfin $path/jellyfin.pfx" | sudo tee -a /etc/cron.d/renew_certbot
echo "0 0 * * *  sudo systemctl restart jellyfin.service" | sudo tee -a /etc/cron.d/renew_certbot
if [ -f  /etc/cron.d/renew_certbot ]
  then
    clear
  else
    echo
    echo 'Failed to create automated certificate renewal'
    echo
    read -p 'Press Enter if you wish to leave it and continue'
    clear
fi

#Reboot
echo
echo '1. Add the jellyfin.pfx file to your SSL cert path in jellyfin,'
echo   'also finish all other requirments in jelyfin Network https'
echo
echo '2. Port forwarding LAN 8096 to WAN 80 and LAN 8920 to WAN 443'
echo
echo '3. Restart Jellyfin'
echo
exit
