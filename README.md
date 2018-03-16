# perl-restart-server
Restart server if
- network is off
- uptime is too high


Creating respository to host perl program.
echo "# perl-restart-server" >> README.md
git init
git add README.md
git commit -m "first commit"
git remote add origin https://github.com/pedroalvesfilho/perl-restart-server.git
git push -u origin master



Run to get help:
restart.if.no.net.pl -h

Usage: restart.if.no.net.pl -S <sleep segs no inicio> -F <sleep segs apos pingar maquinas>
	-P(pause) segs
	-D(ebug) -h(help) -s '<pinga maq. 1> <pinga maq. 2> ...'
	-U <uptime max.>
	-r(test services) 'clamd radiusd named'
	-l <arg. rc.local> : default: /etc/rc.d/rc.local 
                             No ubuntu/debian: /etc/rc.local
                             
Ex.:
restart.if.no.net.pl -D -S 1 -F 1 -P 1 -s 'server1  server2' -r 'named httpd'
