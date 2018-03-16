#!/usr/bin/perl

system ("ulimit -t 1800");

$ENV{"PATH"} = "/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:";
##system ("/usr/local/bin/intruso_chatt.sh");
($agente = $0) =~ s,.*/,,;
#print "agente: $agente\n";
$debug=$DEBUG=0;
$PANIC=0;             #Nao mande mensagem de 'panic' em /var/log/messages
##$REINICIA="/usr/local/bin/reinicia.sh";
#$REINICIA="/sbin/shutdown -t10 -rf now ";
$REINICIA="/sbin/init 6";
$arq_ifconfig="/tmp/${agente}_ifconfig_enviado";
$arq_ifconfig_mx="/tmp/${agente}_ifconfig_enviado_mx";
#
$dia1=24*60*60;	#Um  dia em segundos.
$hora1=60*60;	#uma hora
##$retorno=test_file_time($arq_ifconfig, $dia1); print "retorno: $retorno\n"; exit();
##print "arq_ifconfig=$arq_ifconfig, arq_ifconfig_mx=$arq_ifconfig_mx, agente=$agente\n";
##/var/spool/cron/root ou /var/spool/cron/crontabs/root (maquinas com debian)
$CRON_ROOT="/var/spool/cron/root";
if(-d "/var/spool/cron/crontabs")	#Maquinas com debian?
{
 $CRON_ROOT="/var/spool/cron/crontabs/root";
}

$LOG_FILE=$agente . ".log";
$LOGS="/var/log";
$PRIMARY_DNS="201.36.98.30";
##$RC_LOCAL="/etc/rc.d/rc.local";
$RC_LOCAL="/etc/rc.local";
$DEF_INTERFACES="/etc/sysconfig/network-scripts/";	#Default
##$DEF_INTERFACES="/etc/network/interfaces"; #Debian
##$INTERFACES=`cat /proc/net/dev|grep eth|awk '{print $1}'`;
#$REBOOT="/sbin/reboot";
$REBOOT="/sbin/init 6";
$FIND=`which find`;
$EMAIL_FROM="palves1945\@gmail.com";		#"info\@wb.com.br";
$SENDER= "palves1945\@gmail.com";		#"info\@wb.com.br"; 
$RECIPIENT= "palves1945\@gmail.com";		#"info_servidor\@wb.com.br";

require 'getopts.pl';
Getopts ('Dhl:s:i:S:F:P:U:r:');  # Get the command line arguments
$debug=$DEBUG=$opt_D if $opt_D;
$opt_U=15 if ! $opt_U;
if ($opt_h or ! $opt_s)
{
 #print "Help  ...\n";
 usage();
 exit;
}
if($opt_l){ $RC_LOCAL=$opt_l; }

$MailProg0 = "/usr/sbin/sendmail";
##$MailProg = "$MailProg0 -t -odq  ";
$MailProg = "$MailProg0 -t -f ";
# -t -f info@wb.com.br
 
$HOST=`hostname |cut -d\. -f1`; chomp($HOST);
$DOMINIO=`domainname`; chomp($DOMINIO);
$usuario=$ENV{LOGNAME} . '@' . ${DOMINIO};
print "usuario: $usuario\n" if $opt_D;
#exit(); 
$DATA_DIA=`date +%d%H%M`; chomp($DATA_DIA);

$INTERFACE="eth0";
$INTERFACE=$opt_i if $opt_i;
$PING="arping -I $INTERFACE " ;
#$ping_hosts = shift(@ARGV);
if($opt_s =~ /^gateway$/)
{
 $rota_default=`route -n|egrep "^0.0.0.0" |awk '{print \$2}' `;
 print "opt_s = $opt_s = $rota_default" if $opt_D;
 $opt_s = $rota_default;
}
$ping_hosts = $opt_s;
@ping_hosts_v=split(" ",$ping_hosts);
print "Hosts: $ping_hosts, first hosts: " . $ping_hosts_v[0] . 
	", segundo: " . $ping_hosts_v[1] . "\n" if $opt_D; 
#exit();
$proxy_assumindo="";
$host_assumindo="";
$tempo_check0="180";	#3 miniutos se PRIOR host
$tempo_check2="360";	#10 minutos se NOT PRIOR host
$SLEEP_INITIAL="300";	##"1800";	#Check after $SLEEP_INITIAL segs.
$SLEEP_INITIAL=$opt_S if($opt_S);

$LOG="/var/log";	#Log ....
$LOOP_MAX=20;
$on_reboot="/usr/local/bin/mail.reboot.sh";
system("history -c");
########################
#http://www.geekuprising.com/get_your_ip_address_with_perl
use IO::Socket;
###$hostname="collispuro.net"; #change this to your hostname
$hostname2=`hostname`; chomp($hostname2);  ##print "hostname: $hostname\n";
$ip_h=gethostbyname("$hostname2"); 	#print "hostname2: $hostname2, ip_h: $ip_h\n"; sleep 1;
if(!length($ip_h))
{
 print "Erro no nome do HOST: $hostname2 ?\n"; 
 print "Sender: $SENDER,Recipient: $RECIPIENT\n";
 send_email($SENDER,$RECIPIENT,"$HOST: hostname $hostname2 nao existe/esta errado","$agente - $HOST: hostname $hostname2 nao existe/esta errado"); 
 exit();
}
my($meu_endereco)=inet_ntoa((gethostbyname($hostname2))[4]);
##print "$meu_endereco\n"; sleep 4;
#########################################
sub test_file_time
{ 
 #Testa se $file_test e' mais antigo que $diff_acesso_file . Retorno '1=true' ou '0=false'.
 #Se $file_test nao existe, o arq. e' criado.
 $opt_Deb=$opt_D;
 ($file_test,$diff_acesso_file)=(@_);
 $agora=time();
 if( -f $file_test )
 {
  ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($file_test);
   $diferenca=$agora - $ctime;
   print "File: $file_test, acessado em: $atime, agora: $agora\n" if $opt_Deb;
   print "File: $file_test foi acessado há $diferenca segs.\n" if $opt_Deb;
   if($diferenca > $diff_acesso_file )
   {
     print "Prossegue com o programa\n" if $opt_Deb;
     return(1);
   }
   else
   {
     print "Tempo de criacao do arquivo: $diferenca < $diff_acesso_file ==> saindo ...\n" if $opt_Deb;
     return(0);
     ##exit();
   }
 }
 else
 {
  system("touch $file_test");
  print  "File: $file_test não existe. Continuando ...\n" if $opt_Deb;
  return(1);
  #exit;
 }
}
##############################################

sub send_email
{
  ($sender,$destinatario,$assunto,$body)=(@_);
  #system("echo \"send_email2:enviado_email_fsck, sender: $sender, destinatario: $destinatario\"  >> /tmp/restart.if.no.net.txt");
  # Test MailProg program
  if ( ! -e $MailProg0 ) {
    print ("ERROR: MailProg program $MailProg0 not found\n");
    return(0);
  }
  print "Enviando msg. de EMAIL_FROM: $EMAIL_FROM, RECIPIENT: $RECIPIENT / sender: $sender para destinatario: $destinatario\n" if $opt_D;
  open (MAILTHIS, "|$MailProg $EMAIL_FROM");
  #open (MAILTHIS, "|$MailProg ");
  print MAILTHIS "Reply-to: $sender\n";
  print MAILTHIS "Return-path: $sender\n";
  print MAILTHIS "From: $sender\n";
  print MAILTHIS "To: $destinatario\nSubject: $assunto \n\n";
  print MAILTHIS "$body\n";
  close(MAILTHIS);
  #$body = "Subject: $assunto\n\n" ;	##. $body;
  #system("echo \\\"$body\\\" |smtpsend.pl -to=$RECIPIENT -from=$SENDER -server=localhost");
  return(1);
}

###########
#mkdir "/var/qmail/queue/filter",0755 if ! -d "/var/qmail/queue/filter";
if(! -d "/etc/configwb")
{
 mkdir "/etc/configwb",0755;
 system "echo \"$agente: info\@wb.com.br\" >> /etc/configwb/mail.conf";
 system "echo \"default: info\@wb.com.br\" >> /etc/configwb/mail.conf";
}
if(! -e "/etc/configwb/mail.conf")
{
 mkdir "/etc/configwb",0755;
 system "echo \"$agente: info\@wb.com.br\" >> /etc/configwb/mail.conf";
 system "echo \"default: info\@wb.com.br\" >> /etc/configwb/mail.conf";
}

$RECIPIENT=`grep $agente: /etc/configwb/mail.conf 2>/dev/null |grep -v "^#" 2>/dev/null | head -1`;
#if(substr($RECIPIENT,0,-1) < 3){
#if(substr($RECIPIENT,0,40) < 3){
if(length($RECIPIENT) < 3){
 #$RECIPIENT="somebody\@dot.com";
 $RECIPIENT=`grep default: /etc/configwb/mail.conf 2>/dev/null |grep -v "^#" |  head -1`;
}
if(length($RECIPIENT) < 3){
 $RECIPIENT="$agente: info_servidor\@wb.com.br";
}
$RECIPIENT =~ /:(.*)/; $RECIPIENT=$1;
$RECIPIENT =~  s/^\s*(.*?)\s*$/$1/;    #trim white space
chomp($RECIPIENT);
$SENDER=$RECIPIENT;
#print "RECIPIENT: $RECIPIENT .\n";
#chomp($RECIPIENT);
#print "RECIPIENT: $RECIPIENT .\n";
##############
###### Teste se /etc/resolv.conf existe e se tem a frase:
#nameserver 127.0.0.1
#ou,
#nameserver 201.36.98.30
if(! -f "/etc/resolv.conf" or -z "/etc/resolv.conf")
{
 if(-f "/etc/resolv.conf_DEFAULT")
 {
  system("cp -f /etc/resolv.conf_DEFAULT /etc/resolv.conf");
 }
 else
 {
  system ("echo \"nameserver $PRIMARY_DNS\" >> /etc/resolv.conf");
 }
 send_email($SENDER,$RECIPIENT,"$HOST: Faltando /etc/resolv.conf","$agente - $HOST: Faltando /etc/resolv.conf ou arq. vazio"); 
}
else
{
 $nr_nameserver=`grep nameserver /etc/resolv.conf|wc -l`;
 if($nr_nameserver < 1)
 {
  send_email($SENDER,$RECIPIENT,"$HOST: Faltando nameserver em /etc/resolv.conf","$agente - $HOST: Faltando nameserver em /etc/resolv.conf ou arq. vazio"); 
  #system("chattr -ia /etc/resolv.conf");
  system ("echo \"nameserver $PRIMARY_DNS\" >> /etc/resolv.conf");
 }
 #Aparentemente OK
 if(! -f "/etc/resolv.conf_DEFAULT")
 {
  system("cp -f /etc/resolv.conf /etc/resolv.conf_DEFAULT");
 }
}
##########################
# Verifica se rc.systinit faz fsck -y:
#[root@capri2 sysconfig]# distname.sh
#Mandrake
#[root@capri2 sysconfig]# grep -2 ^Fsck /etc/rc.d/rc.sysinit |grep 'fsck -y'
#        fsck -y $*
#/etc/release -> /etc/mandriva-release
################## Em /etc/rc.d/rc.sysinit:
#if [ -f /fsckoptions ]; then
#        fsckoptions=`cat /fsckoptions`
#fi
# *********** Entao colocamos '-y' em /fsckoptions
#system("echo -n ' -p -a ' >> /fsckoptions");
#system ("rm -f /fsckoptions");

#-/**********************
if(! -f "/fsckoptions")
{
 system("echo -n ' -p -a ' >> /fsckoptions");
}
elsif(-f "/fsckoptions")
{
 $nr_y_fsckoptions=`egrep -- '-a|-p' /fsckoptions |wc -l`;
 if($nr_y_fsckoptions < 1)
 {
  system("echo -n ' -p -a ' >> /fsckoptions");
  send_email($SENDER,$RECIPIENT,"$HOST: Colocado ' -p -a ' em /fsckoptions",
	"$HOST: Colocado ' -a ' em /fsckoptions\n");
 }
}
#-elsif(-f "/etc/mandriva-release" or -f "/etc/mandrakelinux-release" or -f "/etc/mandrake-release")
#-{
#- system("echo arq./etc/mandriva-release  >> /tmp/restart.if.no.net.txt");
#- $nr_y_fsck=`grep -2 ^Fsck /etc/rc.d/rc.sysinit |grep 'fsck -a'|wc -l`;
#- if($nr_y_fsck < 1)
#- {
#-   $trecho=`grep -3 ^Fsck /etc/rc.d/rc.sysinit`;
#-   send_email($SENDER,$RECIPIENT,"$HOST: Colocar 'fsck -a' em /etc/rc.sysinit",
#-	"$HOST: Colocar 'fsck -a' em /etc/rc.sysinit em 'Fsck()'.
#-Trecho de /etc/rc.sysinit para alterar:
#-------------------------------------
#-$trecho
#-------------------------------------
#-");
#-   system("echo \"enviado_email_fsck, sender: $SENDER, recipient: $RECIPIENT\"  >> /tmp/restart.if.no.net.txt");
#- }
#-}
#-else
#-{
#- system("echo NADA_DE_arq./etc/mandriva-release  >> /tmp/restart.if.no.net.txt");
#-}
#-******************/

####################### Examine $CRON_ROOT=/var/spool/cron/root ou /var/spool/cron/crontabs(debian) e /etc/rc.d/rc.local
if(! -x $on_reboot)
{
 print "$on_reboot nao existe\n" if $opt_D;
 $assunto="$HOST - $agente: $on_reboot nao existe";
 $body="$HOST - $agente: $on_reboot nao existe\n";
 send_email($SENDER,$RECIPIENT,$assunto,$body);
}
$on_reboot_nr=`grep $on_reboot $RC_LOCAL |grep -v "^#"|wc -l`;
print "on_reboot_nr: $on_reboot_nr \n" if $opt_D;
if($on_reboot_nr < 1)
{
 print "$on_reboot nao existe em $RC_LOCAL \n" if $opt_D;
 ##system("chattr -ia /etc/rc.d/rc.local");
 system("echo \"$on_reboot\" >> $RC_LOCAL ");
 $assunto="$HOST - $agente: Colocando $on_reboot em $RC_LOCAL \n";
 $body="$HOST - $agente: Colocando $on_reboot em $RC_LOCAL ";
 send_email($SENDER,$RECIPIENT,$assunto,$body);
}

#######################
##chdir "/etc/sysconfig/network-scripts/";
#chdir $DEF_INTERFACES;
#$DEVICE_0=`ls ifcfg-eth*|head -1|cut -d- -f 2`; 
#print " DEVICE_0 ...\n";
#$DEVICE_0=`cat /proc/net/dev|grep eth|awk '{print $1}'|sort|head -1|cut -d: -f1`;
#$DEVICE_0=`cat /proc/net/dev|egrep -i eth|awk '{print $1}'`;
$DEVICE_0=`cat /proc/net/dev|egrep eth.:|cut -d: -f1|sort|head -1`;
chomp($DEVICE_0);
$DEVICE_0 =~  s/^\s*(.*?)\s*$/$1/;    #trim white space

#print  " DEVICE_0: $DEVICE_0 ...\n"; 
print "Device: $DEVICE_0\n" if $opt_D;

$SLEEP=240;	#900		#900
$SLEEP=$opt_P if($opt_P);
$SLEEPF=120;	#300		#Use this if some machine failed
$SLEEPF=$opt_F if($opt_F);
$SLEEP15=15;
$nos="3";    
$more2="2";	#No more than $more2 $agente running in the system
$nr_entrada=getppid();

$FIRST_HOST=$ping_hosts_v[0];
print "FIRST_HOST: $FIRST_HOST\n" if $opt_D;
#echo "Argumentos $*"
#Dirty entry in dmesg:
#eth0: RealTek RTL8139 Fast Ethernet at 0xb000, IRQ 10, 00:50:bf:0e:89:58.
#eth0: Transmit timeout, status 0d 2000 media 08.
#eth0: Tx queue start entry 316468  dirty entry 316464.
#eth0:  Tx descriptor 0 is 10082236. (queue head)
#eth0:  Tx descriptor 1 is 10082236.eth0:  Tx descriptor 2 is 1008024e.
#eth0:  Tx descriptor 3 is 0008024e.
#eth0: MII #32 registers are: 1000 782d 0000 0000 05e1 0000 0000 0000.  
##renice +19 -u $USER >/dev/null
 
sub usage
{
 print "
Usage: $agente -S <sleep segs no inicio> -F <sleep segs apos pingar maquinas>
	-P(pause) segs
	-D(ebug) -h(help) -s '<pinga maq. 1> <pinga maq. 2> ...'
	-U <uptime max.>
	-r(test services) 'clamd radiusd named'
	-l <arg. rc.local> : default: /etc/rc.d/rc.local 
                             No ubuntu/debian: /etc/rc.local
                             
Ex.:
$agente -D -S 1 -F 1 -P 1 -s 'cotton  orion2' -r 'named httpd'

";

}
if($opt_h)
{
  usage();
  exit();
}
else
{
 if ( $opt_D )
 {
  $DEBUG=$opt_D;
  print  "Debugging DEBUG=$DEBUG\n";
 }
}

#sub envia_mail
#{
#	#echo "Nao consigo ver $loop"
#	#envia_fax "Nao consigo ver $1";
#	system ("mail suporte\@$DOMINIO  -s \"Nao consigo ver $FIRST_HOST \" \"
#        Agente: $agente
#        Nao consigo ver $1
#\"
#");
#}
sub reinicia_maq
{
 ($MENSS)=(@_);

 system("echo \"reinicia_maq1_$$ \" >> $LOGS/$LOG_FILE");
 system("(killall pppoe; killall pppoe-server;killall pppd)&");
 system ("$REINICIA &") if !$opt_D;
 #
 #$UPTIME_NOW= `uptime`; #chomp($UPTIME_NOW);
 $MENSS .= `ifconfig -a`; $MENSS .= `uptime`;  $MENSS .= `ps axw`;
 #system("echo \"$DATA_DIA: uptime now = $UPTIME_NOW \" >> $LOGS/$LOG_FILE");
 system("echo \"$DATA_DIA: $MENSS \" >> $LOGS/$LOG_FILE");
 #
 sleep($SLEEP15);
 system("echo \"reinicia_maq2_$$ \"  >> $LOGS/$LOG_FILE");
 system("(killall cppop;killall exim;killall sendmail;killall httpd;killall syslogd)&");
 system("echo  \"reinicia_maq3_$$ \" >> $LOGS/$LOG_FILE");
 sleep($SLEEP15);
 #system ("$REBOOT &") if !$opt_D;
 system("echo \"reinicia_maq4_$$\"  >> $LOGS/$LOG_FILE");
 #system ("$REINICIA &") if !$opt_D;
 system("echo \"reinicia_maq5_$$ \" >> $LOGS/$LOG_FILE");
 #system ("$REBOOT &") if !$opt_D;
 system("echo \"reinicia_maq6_$$\" >> $LOGS/$LOG_FILE");
 #system ("$REBOOT ") if !$opt_D;
 system("echo \"reinicia_maq7_$$\" >> $LOGS/$LOG_FILE");
 sleep($SLEEP15);
 system ("$REINICIA &") if !$opt_D;
}

sub pinga
{
 ($maquina)=(@_);
 $completo=1; $pingos_dados=1;	# -i=wait 3 segs -c=counter nrs of pings
 while( 1 )
 {
   print  "Pingo: tentativa nr $pingos_dados em $maquina ate' <= $nos ...\n" if $opt_D;
   #Redirect Host(New nexthop:
   #64 bytes from localhost.localdomain (127.0.0.1): icmp_req=1 ttl=64 time=0.025 ms  --- em debian
   #$no_ping=`ping -w 10 -i 2 -c 3 $maquina  2>/dev/null|grep -v "Unreachable"|grep icmp_seq|wc -l`;
   $no_ping=`ping -w 10 -i 2 -c 3 $maquina  2>/dev/null|grep -v "Unreachable"|grep icmp_|wc -l`;
   chomp($no_ping);
   #no_ping=`$PING -c 3 $maquina  2>/dev/null|grep icmp_seq|wc -l`;
   if($no_ping > 0 )      #Tem que pelo menos um(1) voltar.
   {
    print  "Pingos retornados $no_ping.\n" if $opt_D;
    return ($no_ping);	#break;	#completo=0
   }
   $pingos_dados++;
   sleep($SLEEP15);
   print  "Tentativas de pingos dados: $pingos_dados\n" if $opt_D;
   if( $pingos_dados > $nos )
   {
     print "Tentativas de pingos dados $pingos_dados > $nos ... Desistindo.\n" 
	if $opt_D;
     return(0);		#break;	#completo=0
   }
 }
}

sub test_run
{
 #ps -C cmdloop &>/dev/null && echo "cmdloop is already running" && exit 0
 $am_i_running_more=`ps ax|grep $agente|grep -v grep|grep -v /var/lib/vz/|wc -l`;
 #/var/lib/vz/ excluir openvz running process   -- /var/lib/vz/root/102/dev/pts/0
 #$am_i_running_more=`ps -C $agente|grep $agente|grep -v grep|wc -l`;
 if($am_i_running_more > $more2)
 {
  $no_ex1="$agente rodando $am_i_running_more >  $more2 ";
  print "Exiting: $no_ex1\n" if $opt_D;
  exit();
 }
 else
 {
  print "Continuando pois so estamos rodando $am_i_running_more  $agente que e' <= $more2  \n" if $opt_D;
 }
}

sub test_if
{
 ## Teste erro na i/f eth0
 #          RX packets:11157941 errors:0 dropped:0 overruns:0 frame:0
 #          TX packets:10787895 errors:0 dropped:0 overruns:0 carrier:0
 $RX=`ifconfig eth0|grep RX`;
 $RX =~ /RX\s+packets:(.*?)\s*errors:(.*?)\s*dropped:(.*?)\s*overruns:(.*?)/i;
 $RX_packets=$1; $RX_errors=$2; $RX_dropped=$3; $RX_overruns=$4;
 print "RX: $RX_packets, $RX_errors, $RX_dropped, $RX_overruns \n" if $DEBUG;
 $TX_E=1000000; $RX_E=1000000;
 if($RX_errors > 0){
   $RX_E=$RX_packets / ($RX_errors + $RX_dropped + $RX_overruns );
  }
 $TX=`ifconfig eth0|grep TX`;
 $TX =~ /TX\s+packets:(.*?)\s*errors:(.*?)\s*dropped:(.*?)\s*overruns:(.*?)/i;
 $TX_packets=$1; $TX_errors=$2; $TX_dropped=$3; $TX_overruns=$4;
 print "TX: $TX_packets, $TX_errors, $TX_dropped, $TX_overruns\n" if $DEBUG;
 if($TX_errors > 0)
 {
  $TX_E=$TX_packets / ($TX_errors + $TX_dropped + $TX_overruns );
 }

 if(($RX_errors > 0 or $TX_errors > 0 ) and 
	($RX_E < 400 or $TX_E < 400) )
 {
  $RX_E = sprintf("%.2f", $RX_E);
  $TX_E = sprintf("%.2f", $TX_E);
  $assunto="$HOST: $DATA i/f com erros altos";
  $body= "$HOST: $agente - $DATA i/f com erros altos\nRX: $RX\nTX: $TX\n";
  $body .= "RX_E: $RX_E, TX_E: $TX_E\n";
  send_email($SENDER,$RECIPIENT,$assunto,$body);
 }
}

system ("touch /tmp/${agente}.$DATA_DIA");
$UPTIME_NOW= `uptime`; chomp($UPTIME_NOW);
system("echo \"$DATA_DIA: uptime now = $UPTIME_NOW \" >> $LOGS/$LOG_FILE");
#print "find /tmp/${agente}.* -atime +1 -exec rm -vf {} \; ....\n";
#system ("find /tmp/${agente}.* -atime +1 -exec rm -vf {} \;");
system ("find /tmp -name ${agente}.log -amin +300 -exec rm -f {} \\;");
#exit();

# Erro do shell no perl ? $FALHA_LIM=`$#`;
#$FALHA_LIM=2;		#Limite = nr. opt_s ?
$FALHA_LIM=$#ping_hosts_v;
$FALHA_LIM++;
print "Limit de falhas: $FALHA_LIM\n" if $opt_D;

#echo "Limite de falhas: $#"
#exit
sleep( $SLEEP_INITIAL);
print "Em ação ...\n" if $opt_D;

#$kill_defunct=`ps ax|grep '<defunct>'|grep -v grep|cut -d\   -f1`;
###[ "x$kill_defunct" != "x"  ] && kill -9 $kill_defunct 2>/dev/null
#[ x$DEBUG != x ] &&  echo "Killing $kill_defunct ..."
#Retirei em 30-4-2005
#for i in $kill_defunct ; do
#  #[ x$DEBUG != x ] && echo "Killing $i ..."
#  kill -9 $i >/dev/null 2>/dev/null
#done

test_if();

$LOOP_CRT=0;
sleep(300);  #2017-10-02 - wait 5 min. to start

while ( 1 )
{
  $LOOP_CRT++;
  $DATA=`date`; chomp($DATA);
  print  "Inicio do loop. Testando ...\n" if $opt_D;
  $FALHA=0;
  test_run;
  ##################################### Maquina isolado (firewall erradamente configurado?)
  #ping: sendto: Operation not permitted
  #ping: sendto: Operation not permitted
  #ping: sendto: Operation not permitted
  #PING cotton.wb.com.br (200.160.244.13) from 200.160.244.9 : 56(84) bytes
  #of data.
  #3 packets transmitted, 0 packets received, 100% packet loss
  ###########################################################
  #User the first host to test for incorrect firewall conf.
  print "FIRST_HOST: $FIRST_HOST\n" if $opt_D;
  if ( $FIRST_HOST ne "" )
  {
   print "Testing $FIRST_HOST for ping, elimando  sendto: e  Operation not permitted\n" if $opt_D;
   $no_pingo=`ping -w 10 -i 2 -c 3 $FIRST_HOST  2>&1|grep -i "ping: sendto: Operation not permitted"|wc -l`;
   ##chomp($no_pingo); 
   if ( $no_pingo > 1 )
   {
  	system ("echo \"$DATA: No. of pings w/ sendto: Operation not permitted: $no_pingo\" >> $LOGS/$LOG_FILE");
  	#touch $LOG/restart.if.no.net.log
	print "Reiniciando o sistema ...\n" if $opt_D; sleep 5;
	#--$MENSS=" \"$HOST: \"$DATA: No. of pings w/ sendto \" |mail -s \"$HOST: \"$DATA: No. of pings w/ sendto \" $RECIPIENT";
	$assunto="$HOST: $DATA: No. of pings w/ sendto";
	$body= "$HOST: $DATA: No. of pings w/ sendto";
	##--system ("echo $MENSS");
 	send_email($SENDER,$RECIPIENT,$assunto,$body);
 	reinicia_maq("no pings w/ Operation not permitted > 1");
  	#system ("reinicia.sh &") if !$opt_D;
	#system ("reboot &") if !$opt_D;
   }
  }
  else
  {
   $test="";
   print  "No first host found\n" if $opt_D;
  }
  ###########################################################
  print "Teste se nao tem rede (network start/stop)\n" if $opt_D;
  #64 bytes from localhost.localdomain (127.0.0.1): icmp_req=1 ttl=64 time=0.025 ms  --- em debian
  ##$no_pingo=`ping -w 10 -i 2 -c 4 localhost  2>/dev/null|grep icmp_seq|wc -l`;
  $no_pingo=`ping -w 10 -i 2 -c 4 localhost  2>/dev/null|grep icmp_|wc -l`;
  chomp($no_pingo);
  print "no_pingo: $no_pingo to localhost\n" if $opt_D;
  if ( $no_pingo < 1 )
  {
  	system ("echo \"$DATA: No. of pings: $no_pingo\" >> $LOG/${agente}.log");
  	#touch $LOG/restart.if.no.net.log
	print "Reiniciando o sistema ...\n" if $opt_D; sleep 5;
	##$MENSS=" \"$HOST: \"$DATA:  No. of pings: $no_pingo \" |mail -s \"$HOST: \"$DATA: No. of pings: $no_pingo \" $RECIPIENT";
	#--system ("echo $MENSS");
	$assunto="$HOST: $DATA:  No. of pings: $no_pingo";
	$body= "$HOST: \"$DATA:  No. of pings: $no_pingo";
 	send_email($SENDER,$RECIPIENT,$assunto,$body);
	reinicia_maq();
  	#system ("reinicia.sh &") if !$opt_D;
	#system ("reboot &") if !$opt_D;
  }

  #: error fetching interface information: Device not found
  $if_err=`ifconfig |grep "Device not found"|wc -l`; chomp($if_err);
  print  "if_err: $if_err\n" if $opt_D; sleep 5;
  $a=`ifconfig |egrep -c "$DEVICE_0 "`; chomp($a);
  print  "a: $a for DEVICE_0: $DEVICE_0\n" if $opt_D; sleep 5;
  if ( $a < 1 or $if_err > 0)
  {
   system ("wall \"$agente: 1. I/F $DEVICE_0 out. Trying to load modules ...\"");
   system ("/sbin/insmod  8390");
   system ("/sbin/insmod  mii");
   system ("/sbin/insmod  8139too");
   system ("/etc/rc.d/init.d/network stop"); sleep (2);
   system ("/etc/rc.d/init.d/network start");
   system ("/usr/local/bin/iproute.${HOST}.sh");
   system ("touch /tmp/${agente}.start.$nr_entrada");
   sleep ($SLEEP15);
   $a=`ifconfig |egrep -c "$DEVICE_0 "`; chomp($a);
   if($a < 1)
   {
    ##touch $LOG/restart.if.no.net.log
    system ("wall \"$DATA: $agente - 2. I/F $DEVICE_0 out ... Reiniciando sistema ...\"");
    system ("echo \"$DATA: $agente - 3. I/F $DEVICE_0 out ... Reiniciando sistema ...\"  >> $LOG/${agente}.log");
    print "Reiniciando o sistema ...\n" if $opt_D; sleep 5;
    ##$MENSS=" \"$HOST: \"$DATA:  I/F $DEVICE_0 out \" |mail -s \"$HOST: \"$DATA: I/F $DEVICE_0 out \" $RECIPIENT";
    $assunto="$HOST: $DATA: I/F $DEVICE_0 out ";
    $body= "$HOST: $DATA:  I/F $DEVICE_0 out";
    send_email($SENDER,$RECIPIENT,$assunto,$body);
    #####system ("echo $MENSS");
    reinicia_maq();
    #system ("reinicia.sh &") if !$opt_D;
    #system ("reboot &") if !$opt_D;
   }
  }
  
  $a=`route -n |grep "^0.0.0.0" |wc -l`; chomp($a);
  print "Testando rota default: $a ... " if $opt_D;
  if( $a < 1 )
  {
   system("/etc/rc.d/init.d/network start; /usr/local/bin/iproute.${HOST}.sh");
   print "Falta rota de saida: $a ?\n" if $opt_D;
   sleep ($SLEEP15);
   $a=`route -n |grep "^0.0.0.0" |wc -l`; chomp($a);
   #Cuidado com: 0.0.0.0         0.0.0.0         0.0.0.0         U     0      0        0 eth0
   # Obtive rodando /etc/rc.d/init.d/network start
   #             0.0.0.0         0.0.0.0         0.0.0.0         U     0      0        0 eth0
   if( $a < 1)
   {
      #touch $LOG/restart.if.no.net.log
      system ("wall \"$DATA: $agente - 4. I/F $DEVICE_0 out/Rota default out ... Reiniciando sistema ...\"");
      system ("echo \"$DATA: $agente - 5. I/F $DEVICE_0 out/Rota default out ... Reiniciando sistema ...\"  >> $LOG/${agente}.log");
      print "Reiniciando o sistema ...\n" if $opt_D; sleep 5;
      ##$MENSS=" \"$HOST: \"$DATA: $agente - 5. I/F $DEVICE_0 out/Rota default out\" |mail -s \"$HOST: \"$DATA: $agente - 5. I/F $DEVICE_0 out/Rota default out\" $RECIPIENT";
      $assunto="$HOST: $DATA: $agente - 5. I/F $DEVICE_0 out/Rota default out";
      $body= "$HOST: $DATA: $agente - 5. I/F $DEVICE_0 out/Rota default out";
      send_email($SENDER,$RECIPIENT,$assunto,$body);
      ###system ("echo $MENSS");
      reinicia_maq();
      #system ("reinicia.sh & ") if !$opt_D;
      #system ("reboot &") if !$opt_D;
   }
  }
  elsif( $a > 1 )
  {
   system("ip route del 0/0; ip route del 0/0;/etc/rc.d/init.d/network start");
   system ("/usr/local/bin/iproute.${HOST}.sh");
   $assunto="$HOST: $DATA: $agente - Mais de uma Rota default 0/0";
   $body= "$HOST: $DATA: $agente - Mais de uma Rota default 0/0";
   send_email($SENDER,$RECIPIENT,$assunto,$body);
  }
  else { print " existe\n" if $opt_D; }
  $rota=`route -n |grep "^0.0.0.0" `;
  #Erro: 0.0.0.0         0.0.0.0         0.0.0.0         U     0      0        0 eth0
  #OK:   0.0.0.0     	   201.36.98.1     0.0.0.0 UG 0 0 0 eth0
  if($rota =~ /0.0.0.0(.*?)0.0.0.0(.*?)0.0.0.0/)
  {
   $assunto="$HOST: rota default errada: 0.0.0.0";
   $body="$HOST -- Rota default errada sendo corrigida:\n\n$rota\n\n";
   system ("/usr/local/bin/iproute.${HOST}.sh");
   send_email($SENDER,$RECIPIENT,$assunto,$body);
  }
  ####################### Inicia loop
  ##$LOOP_CRT=0;
  #@ARGV
  #for i in $* ;  do 
  print "Percorrendo os servidores: @ping_hosts_v\n" if $opt_D; 
  #while (@ARGV)
  $FALHA=0;
  foreach(@ping_hosts_v)
  {
   $i=$_;
   print  "Pingando $i\n" if $opt_D;
   $correto=pinga($i);
   print  "Retornando correto=$correto ao pingar $i .\n" if $opt_D;
   #$erro="erro de pinga";
   #if( $? = 0 )             #0: Nr de erros (logica invertida) problem with pinga ...
   if($correto > 0)
   {
    $FALHA=0;	#Introduzi em 21-9-2005
    next;
    #continue;
   }
   else
   {
    #$FALHA=$(($FALHA + 1 ));
    print "Falha ao pingar maquina $i : $FALHA\n" if $opt_D;
    $FALHA++;
    if( $FALHA >= $FALHA_LIM )
    {
     #touch $LOG/${agente}.log
     $MES_FALHAS="2. $DATA: $agente - Falhas: $FALHA falhas pingando maquina $i -- I/F $DEVICE_0 out ... Reiniciando sistema ...";
     #system ("wall \"1. $DATA: $agente - Falhas: $FALHA -- I/F $DEVICE_0 out ... Reiniciando sistema ...\"");
     system ("wall \"$MES_FALHAS \"");
     $MENSS = `ifconfig -a`; $MENSS .= `uptime`;
     $MENSS .= `iptables -L -t nat`;
     system ("ifconfig -a");
     system ("echo  \"3. $DATA: $agente - Falhas: $FALHA -- I/F $DEVICE_0 out ... Reiniciando sistema ...\"  >> $LOG/${agente}.log");
     system (" echo \"$MENSS\"  >> $LOGS/$LOG_FILE");
     print "Reiniciando o sistema ...\n" if $opt_D; sleep 5;
     ##$MENSS .=" \"$HOST: \"$DATA: $agente - 6. I/F $DEVICE_0 out \" |mail -s \"$HOST: \"$DATA: $agente - 6. I/F $DEVICE_0 out \" $RECIPIENT";
     #$assunto="$HOST: $DATA: $agente - 6. I/F $DEVICE_0 out";
     $assunto="$HOST:  $DATA: $agente - nr. falhas = $FALHA";
     #$body= "$HOST: nr. falhas = $FALHA\n$DATA $agente - 6. I/F $DEVICE_0 out";
     $body= "
$HOST: $agente $DATA
Nr. falhas pingando maquina $i = $FALHA >= $FALHA_LIM

----------

$MENSS

";
     send_email($SENDER,$RECIPIENT,$assunto,$body);
     ####system ("echo $MENSS");
     reinicia_maq();
     #system ("reinicia.sh &") if !$opt_D;
     #system ("reboot &") if !$opt_D;
    }
    print "Falha no host $i . Dormindo $SLEEPF\n" if $opt_D;
    sleep ($SLEEPF);
   }
   print "Fim do loop do host $i .\n" if $opt_D;
  }

  print "Saindo do loop do host $i .\n" if $opt_D;  
  $pop_before=`ps ax|grep pop-before-exim|grep -v grep |wc -l `; 
  #/var/lib/vz/ E openvz? que roda no servidor virtual confundindo?
  chomp($pop_before);
  #if ($pop_before < 1 and $HOST eq "web" )
  #{
  # system ("/usr/local/bin/pop-before-exim.pl &");
  #}
  
  if(-x "/usr/local/bin/check.service.sh")
  {
   @daemons2test=split(" ",$opt_r);
   foreach(@daemons2test)
   {
    system ("touch /tmp/${agente}.$_$nr_entrada");
    system ("echo 'Checando servico $_ ...' >> /tmp/${agente}.$_$nr_entrada");
    print "Checando serviço $_ ...\n" if $opt_D;
    system ("/usr/local/bin/check.service.sh $_ &");
    #system ("check.service.sh named test     &");
   }
  }
  else 
  {
   if($opt_r)
   {
    $MENS_SERV=" \"$HOST: \"$DATA: Não encontrei 'check.service.sh' \" |mail -s \"$HOST: \"$DATA: Não encontrei 'check.service.sh'  \" $RECIPIENT";
    $assunto="$HOST: $DATA: Não encontrei 'check.service.sh'";
    $body= "$HOST: $DATA: Não encontrei 'check.service.sh'";
    send_email($SENDER,$RECIPIENT,$assunto,$body);
    ##system ("echo $MENS_SERV");
   }
  }

  ##$LOOP_CRT++;
  print "Loop $LOOP_CRT\n" if $opt_D;
  if( $LOOP_CRT > $LOOP_MAX )
  {
    print "Loop max ($LOOP_MAX) alcançado. Exiting.\n" if $opt_D;
    exit();
  }

  print "Dormindo $SLEEP .\n" if $opt_D;  
  sleep ($SLEEP);
  
  ##############################Hard Disk error chek ###############################
  #dmesg |grep "quota structure"
  #VFS: Can't read quota structure for id 6084.
  #VFS: Can't read quota structure for id 6084.

  # Em 12-6-2006 na capricorn:
  #EXT3-fs error (device hde8) in ext3_delete_inode: Journal has aborted

  #result1=`dmesg|egrep -iv "hash table|max_pages|timed out"|egrep -i "inode|NETDEV WATCHDOG|quota structure"`
  print "Checando dmesg ...\n" if $opt_D;
  #$result1=`dmesg|egrep -iv "hash table|DriveStatusError|SeekComplete Error|ip_conntrack: table full, dropping packet|max_pages|timed out"|egrep -i "inode|NETDEV WATCHDOG|quota structure"`;
  #Em 12-6-2006:
  #$teste_str="dmesg\|tail -200\|egrep -i \"DriveStatusError\|SeekComplete Error\|ip_conntrack: table full, dropping packet\|max_pages\|timed out\" ";
  $teste_str="dmesg\|tail -200\|egrep -i \"DriveStatusError\|";
  $teste_str .= "SeekComplete Error\|";
  $teste_str .= "ip_conntrack: table full, dropping packet\|max_pages\|";
  $teste_str .= "timed out\" ";

  #$result1=`dmesg|tail -200|egrep -i "DriveStatusError|SeekComplete Error|ip_conntrack: table full, dropping packet|max_pages|timed out" `;
  $result1=`$teste_str`;

  print "teste_str: $teste_str\n" if $opt_D;

  $teste_str2 = "dmesg\|tail -200\|egrep -i \"Remounting filesystem read-only\|";
  $teste_str2 .= "EXT3-fs error\|Journal has aborted\" ";
  ####$teste_str2 .= "EXT3-fs: mounted\"";	#Teste
  $result2=`$teste_str2`;
  print "teste_str2: $teste_str2\n" if $opt_D;

	######|egrep -i "inode|NETDEV WATCHDOG|quota structure"`;
  #hdc: dma_intr: error=0x84 { DriveStatusError BadCRC }
  #hdc: dma_intr: status=0x51 { DriveReady SeekComplete Error }

  #Sem problemas: Inode cache hash table entries: 16384 (order: 5, 131072 bytes)
  $DMESG_ERROR=0;
  chomp($result1); $result1_len=length($result1);
  chomp($result2); $result2_len=length($result2);
  print "result2: $result2 - len: $result1_len\n" if $opt_D;
  print "result1: $result1\n - len: $result2_len" if $opt_D;
  if(
  ( (length($result1) > 1 or length($result2) > 1 ) and $LOOP_CRT < 2 ) or $opt_D)
  {
   print "Enviando msg: result1: $result1, result2: $result2\n" if $opt_D;
   $result1 =~ /id (.*)\.$/i; $inum=$1;
   #system ("mail.sh -t $RECIPIENT -s \"$HOST: Hard disk, I/F or quota error\" \"
   $assunto="$HOST: Hard disk, I/F or quota error";

   #dmesg|egrep -i "DriveStatusError|SeekComplete Error|ip_conntrack: table full, dropping packet|max_pages|timed out"
   $opt_DEBUG=0; $opt_DEBUG=1 if $opt_D;
   $body=<<EOF;

HOST: $HOST
---------------

Agente: $agente, pid: $nr_entrada
LOOP_CRT: $LOOP_CRT , opt_D: $opt_DEBUG (opt_D/Debug FLAG)

dmesg command gives following error:
  
$HOST: Hard disk or I/F error :
  
-------------------------------------------
Resultado da pesquisa de:

$teste_str

------------------------- resultado: ------------------
result1: 
$result1
-------------------------------------------------------
result2: 
$result2
-------------------------------------------------------


No exemplo simulado abaixo, caso exista erro de arquivo no HD, vai aparecer uma mensagem do tipo:
 
EXT3-fs error (device ide0(3,8)): ext3_readdir: directory #263441 contains a hole at offset 36864
EXT3-fs error (device ide0(3,8)): ext3_readdir: directory #263441 contains a hole at offset 40960
ide0(3,8) == major/minor numbers for /dev/hda?

 0 brw-rw----    1 root     disk       3,   8 Abr 11 11:25 /dev/hda8

Encontre o dir/arq. usando, por ex.:
find / -inum 263441


Substitua o inum acima (263441) pelo id do resultado mostrado (inum = $inum) :

find / -inum $inum

E isole o arq. do sistem renomeando para por exemplo:
mv var/spool/mail/joao var/spool/mail/joao.erro.no.hd

EOF

  $DMESG_ERROR=1;
  send_email($SENDER,$RECIPIENT,$assunto,$body);

  }

  #################### Out of Memory: Killed process ############
  print "Checando dmesg: Out of Memory: Killed process ...\n" if $opt_D;
  $result_mem=`dmesg|tail -200|egrep -i "Out of Memory: Killed process"`;
  chomp($result_mem); $result_mem =~  s/^\s*(.*?)\s*$/$1/;
  $result_mem_len = length($result_mem);

  # half-duplex based on auto-negotiated partner ability 0000.
  #eth1: Setting 100mbps full-duplex ba
  print "Checando dmesg: half-duplex ...\n" if $opt_D;
  $result_half_duplex=`dmesg|tail -200|egrep -i "half-duplex"`;
  chomp($result_half_duplex); $result_half_duplex =~ s/^\s*(.*?)\s*$/$1/;
  $result_half_duplex_len=length($result_half_duplex);
  
  #if( (length($result1) > 1 and $LOOP_CRT < 2 ) or $opt_D)
  if( ( (length($result_mem) > 3 or length($result_half_duplex) > 3) and $LOOP_CRT < 2 ) 
	or $opt_D
    )
  {
   #send_email($SENDER,$RECIPIENT,$assunto,$body);
   #system ("mail.sh -t $RECIPIENT -s \"$HOST: Out of Memory/half-duplex\" \"
$assunto="$HOST: Out of Memory/half-duplex";
$dmesg=`dmesg`;  $opt_DEBUG=0; $opt_DEBUG=1 if $opt_D;
$body=<<EOF;  
Agente: $agente, pid: $nr_entrada
LOOP_CRT: $LOOP_CRT , opt_D: $opt_DEBUG (opt_D/Debug FLAG)
  
$HOST: Out of Memory: Killed process / half-duplex
  
Resultados de:
result_mem='$result_mem', comprimento: $result_mem_len .
result_half_duplex='$result_half_duplex', comprimento: $result_half_duplex_len .
  
-------------------- Arquivo dmesg: ---------------------------
$dmesg
---------------------------------------------------------------
EOF
#\" ");
send_email($SENDER,$RECIPIENT,$assunto,$body);

#Do:
#  killall clamscan
#  qmail_start_stop.sh stop
#  qmail_start_stop.sh start
#  /etc/rc.d/init.d/xinetd stop
#  /etc/rc.d/init.d/xinetd start
#  /etc/rc.d/init.d/httpd stop
#  /etc/rc.d/init.d/httpd start
#
#\" ");

  #killall clamscan
  #qmail_start_stop.sh stop
  #qmail_start_stop.sh start
  #/etc/rc.d/init.d/xinetd stop
  #/etc/rc.d/init.d/xinetd start
  #/etc/rc.d/init.d/httpd stop
  #/etc/rc.d/init.d/httpd start
  #radiusd.hp.sh
  ##dmesg -c
    $DMESG_ERROR=1;
  }
  ##########################################################
  if ( $DMESG_ERROR > 0 )
  {
   ##system ("dmesg -c");
  }
  ############################pcmcia wireless
  print "Checando /etc/rc.d/rc3.d/S*pcmcia ...\n" if $opt_D;
  $spcmcia_nr=`ls /etc/rc.d/rc3.d/S*pcmcia 2>/dev/null |wc -l`;
  chomp($spcmcia_nr);
  if ($spcmcia_nr > 0 )
  {
    $pcmcia_nr=`lsmod |grep pcmcia_core|wc  -l`;
    chomp($pcmcia_nr);
    if( $pcmcia_nr < 1 )
    {
      #echo "Wireless ..."
      system ("/etc/rc.d/rc3.d/S*pcmcia start");
    }
  }
  print "Checando /var/log/messages  ...\n" if $opt_D;
  $MESSAGES=`grep -i10 panic /var/log/messages`;
  if(length($MESSAGES) > 10 and $PANIC)
  {
   $assunto="$HOST: panic - /var/log/messages";
   $body= "$HOST: panic - /var/log/messages\n\n$MESSAGES";
   send_email($SENDER,$RECIPIENT,$assunto,$body);  
  }
  
  print "Checando uptime ...\n" if $opt_D;
  $UPTIME=`uptime |sed -e "s/.*://g"|sed -e "s/,.*//g"`; 
  chomp($UPTIME); 
  print "Checando uptime = $UPTIME ...\n" if $opt_D;
  if($UPTIME > $opt_U)
  {
   ##$MENSS=" \"$HOST: UPTIME ALTO = $UPTIME\" |mail2.sh -s \"$HOST: UPTIME = $UPTIME\" -t $RECIPIENT";
   print "Enviando msg sobre uptime=$UPTIME: $MENSS ...\n" if $opt_D;
   $assunto="$HOST: UPTIME = $UPTIME";
   $body= "$HOST: UPTIME ALTO = $UPTIME";
   send_email($SENDER,$RECIPIENT,$assunto,$body);
   ##system ("echo $MENSS");
   reinicia_maq();
   #system ("reinicia.sh &") if !$opt_D;
   #system ("reboot &") if !$opt_D;
  }
  ########  Envia 'ifconfig' e 'route -n' para info_backup@wb.com.br todo dia.
  $envia_ifconfig=0;	#false
  $nova_config=0;
  $envia_ifconfig_mx=0;
  $DATA_ANO_MES_DIA=`/bin/date '+%Y-%m-%d %H:%M hs'`; chomp($DATA_ANO_MES_DIA);
  if(! -f $arq_ifconfig)
  {
   print "Criando $arq_ifconfig\n" if $opt_D;
   ##system("echo '$DATA_ANO_MES_DIA : criando $arq_ifconfig' >> /tmp/criando_ifconfig ");
   system ("touch $arq_ifconfig");
   $envia_ifconfig=1; $nova_config=1;
  }
  else
  {
    system("echo '$DATA_ANO_MES_DIA :  $arq_ifconfig ja existe' >> /tmp/criando_ifconfig ");
    $envia_ifconfig=test_file_time($arq_ifconfig,$dia1);
  }
  $RECIPIENT="info_backup\@wb.com.br";
  $envia_email_mx=0;
  if($envia_ifconfig)
  {
   print "Enviando email: envia_ifconfig=$envia_ifconfig, nova_config: $nova_config\n" if $opt_D;
   $MENSS2 .= `/sbin/ifconfig -a`;  
   $MENSS2 .= "\n======================== HD ==================\n";
   $MENSS2 .= `df`; 
   ##$MENSS2 .= "\n==================== xx ==========================\n";
   #
   # Cron:
   $MENSS2 .= "\n======================== cron ==================\n";
   $MENSS2 .= `cat $CRON_ROOT`;
   $MENSS2 .= "=================== uptime ; ps axw==============================\n";
   $MENSS2 .= `uptime`;  $MENSS2 .= `ps axw`;
   #
   $MENSS2 .= "=================== $RC_LOCAL = /etc/rc.local ou /etc/rc.d/rc.local ================\n\n";
   $MENSS2 .= `cat $RC_LOCAL`;   
   $MENSS2 .= "=================== /etc/sysctl.conf ================\n\n";
   $MENSS2 .= `cat /etc/sysctl.conf`;
   #
   $assunto="Backup: Configuracoes maquina $HOST em $DATA_ANO_MES_DIA";
   $body ="\n";
   #$body = "Config: $nova_config depois de $dia1 segs. (=1 dia), envia_ifconfig: $envia_ifconfig" . "\n";
   $body .= $assunto . "\n";
   $body .= "===================================================\n";
   $body .=  $MENSS2;
   $body .= "===================================================\n";
   send_email($SENDER,$RECIPIENT,$assunto,$body); 
   system ("touch $arq_ifconfig");
   $envia_email=1;
  } 
  $envia_ifconfig_mx=test_file_time($arq_ifconfig_mx,$hora1);
  if( ($envia_ifconfig  or $envia_ifconfig_mx) and -f "/etc/exim.conf")	#Examine as maquinas com /etc/exim.conf
  {
    $blacklist = "";
    $IP_MX=`egrep -20 "^remote_smtp:" /etc/exim.conf|egrep " interface " |egrep -v '#|if'|awk '{print \$3}'`;
    chomp($IP_MX);

    #/***** ******/
    ###system("wget -o /tmp/xxxx -O /tmp/$IP_MX http://www.mxtoolbox.com/SuperTool.aspx?action=blacklist%3a$IP_MX");
    #system("wget -o /tmp/xxxx -O /tmp/$IP_MX 'http://www.spamcop.net/w3m?action=checkblock&ip=$IP_MX' ");
    #$blacklist .= "\n================ SPAMCOP ============================\n";
    #$blacklist .="Teste em: wget -o /tmp/xxxx -O /tmp/$IP_MX 'http://www.spamcop.net/w3m?action=checkblock&ip=$IP_MX' \n";
    ##<p>173.38.153.35 listed in bl.spamcop.net (127.0.0.2)<br>
    ####$blacklist .=`cat /tmp/$IP_MX|egrep -2 $IP_MX`;
    #$blacklist .=`cat /tmp/$IP_MX|egrep -1 listed `;
    ##
    #system("wget -o /tmp/xxxx -O /tmp/$IP_MX 'http://www.barracudacentral.org/reputation?r=1&ip=$IP_MX'");
    #$blacklist .= "\n================  BARRACUDA ============================\n";
    #$blacklist .= "Teste em: wget -o /tmp/xxxx -O /tmp/$IP_MX 'http://www.barracudacentral.org/reputation?r=1&ip=$IP_MX' \n";
    #$blacklist .=`cat /tmp/$IP_MX | egrep -i reputation`;
    #$blacklist .= "\n============================================\n";
    #/*** ******/
    $blacklist0 = `/usr/local/bin/blcheck.sh $IP_MX | egrep -vi mismatch`; #filtra 'reply from unexpeced source... mismatch
    #;; reply from unexpected source: 201.36.98.30#53, expected 127.0.0.1#53 ;; Warning: ID mismatch: expected ID 10968, got 35396
    $blacklist .= $blacklist0;
    #Teste tambem o ip de saide do servidor -  'ifconfig eth0':
    $blacklist2 = "";
    #Retirei em 17-9-2012: $blacklist2 = `/usr/local/bin/blcheck.sh $meu_endereco | egrep -vi mismatch`;
    $blacklist .= $blacklist2;
    
    $blacklisted= "";
    ##if($blacklist0 =~ /127.0.(.*?)(.*?)/)
    if($blacklist0 =~ /127.0./mg)	#g: continuous lines
    {
     $blacklisted= "*** $IP_MX BLACKLISTED***";
     $RECIPIENT .=",info\@wb.com.br,info_home\@wb.com.br";
     $envia_email_mx=1;
    }
    if($blacklist2 =~ /127.0./mg)	#g:global match   s: single line   #m: Treat string as multiple lines
    {
     $blacklisted= "*** $meu_endereco BLACKLISTED***";
     $RECIPIENT .=",info\@wb.com.br,info_home\@wb.com.br";
     $envia_email_mx=2;
    }
    $assunto="$blacklisted Backup - Teste de MX em $HOST, IP usado: $IP_MX";
    ##$body="IP MX usado em $HOST: $IP_MX\nTeste em http://www.mxtoolbox.com/SuperTool.aspx?action=blacklist%3a$IP_MX";
    $body="$blacklisted IP MX usado em $HOST: $IP_MX\n";
    $body .="Testando o IP $IP_MX nas listas de spam usando o script '/usr/local/bin/blcheck.sh  $IP_MX':\n";
    $body .= "O IP $IP_MX nao tendo problemas, e' marcado '---' ao lado da lista\n";
    $body .= "O IP $P_MX tendo problemas, aparecera' um IP da rede 127.0.0.0/8 ao lado da lista.\n";
    $body .= "Um teste mais detalhado pode ser feito usando o link:\n";
    $body .= "http://www.mxtoolbox.com/SuperTool.aspx?action=mx%3a$IP_MX\n";
    $body .= "\n============================================\n";
    $body .= $blacklist;
    $body .= "\n============================================\n";
    $body .= "O IP definido para o smtp, no caso de se usar o exim, esta' no arquivo /etc/exim.conf\n";
    $body .= "Caso necessitar substituir, buscar pela linha:\n";
    $body .= "    interface = $IP_MX\n";
    $body .= "E substituir o IP por um cadastrado:\n";
    $IPS=`egrep -2 $IP_MX /etc/exim.conf|egrep -i interface|egrep -v if`;
    $body .= $IPS;
    $body .= "============================================\n";
    $body .= "O 'jogo da velha #' significa 'comentario'. Retirando o '#' a linha passa a valer.\n";
    $body .= "Use o editor 'vi /etc/exim.conf' ou 'vim /etc/exim.conf' ou 'pico /etc/exim.conf' ou 'joe /etc/exim.conf'\n";
    $body .= "para editar o arquivo, colocando ou retirando o # para mudar o ip usado no smtp.\n";
    $body .= "O editor 'joe' usa os comandos:\n";
    $body .= "^kx : salva o arquivo e sai, ^kq : quit, ^kf : procura um texto, ^L : procura seguinte\n";
    $body .= "============================================\n";
    # 
    #
    if($envia_email or $envia_email_mx){ send_email($SENDER,$RECIPIENT,$assunto,$body); }
    system ("touch $arq_ifconfig_mx");
  }
}
