sub smtp {

$now = strftime("%a, %B %d %Y %T GMT", gmtime(time));

open (HTAB, "$thpdir/lib/smtptab");
my @keys = qw(
	state
	Command
	regex	
	newstate
	continue
	response
	assignment
);
$cnt = 0;

while (<HTAB>) {
 unless ( /^$|^#/ ) {
	chomp;
	my $key;
 	$cnt++;
	$strcnt = sprintf (qq(%0.2d), $cnt);
	@_ = split(/\t/, $_, 7);

 	foreach $key (@keys){
		$rules{"$strcnt$key"} = shift @_;
	}
 }
}

foreach $k (sort keys %rules) {
    print "$k => $rules{$k}\n";
}

close HTAB;

%smtp = (
	start	=>	"220 $hostname.$domain ESMTP Sendmail 8.11.2/8.11.2; $now\x0d\x0a",
	helo	=>	"250 $hostname.$domain Hello $dom [$saddr], pleased to meet you\x0d\x0a",
	err501	=>	"501 5.0.0 Invalid domain name\x0d\x0a",
	ehlo	=>	qq (250 $hostname.$domain Hello $dom [$saddr], pleased to meet you
250-ENHANCEDSTATUSCODES
250-8BITMIME
250-SIZE
250-DSN
250-ONEX
250-ETRN
250-XUSR
250-AUTH GSSAPI
250 HELP
),
	err503	=>	"503 5.0.0 $hostname.$domain Duplicate HELO/EHLO\x0d\x0a",
	mail	=>	"250 2.1.0 $rpath... Sender ok\x0d\x0a",
	already	=>	"503 5.5.0 Sender already specified\x0d\x0a",
	bogs	=>	"500 5.5.1 Command unrecognized: \"$cmd\"\x0d\x0a",
	err553	=>	"553 5.1.0 ... prescan: token too long\x0d\x0a",
	norp	=>	"503 5.0.0 Need MAIL command\x0d\x0a",
	nofp	=>	"503 5.0.0 Need RCPT (recipient)\x0d\x0a",
	lrcpt	=>	"250 2.1.5 $lrcpt... Recipient ok\x0d\x0a",
	rrcpt	=>	"250 2.1.5 $rrcpt... Recipient ok (will queue)\x0d\x0a",
	data	=>	"354 Enter mail, end with \".\" on a line by itself\x0d\x0a",
	eof	=>	"250 2.0.0 $qid Message accepted for delivery\x0d\x0a",
	help	=>	qq (214-2.0.0 This is sendmail version 8.11.2
214-2.0.0 Topics:
214-2.0.0       HELO    EHLO    MAIL    RCPT    DATA
214-2.0.0       RSET    NOOP    QUIT    HELP    VRFY
214-2.0.0       EXPN    VERB    ETRN    DSN     AUTH
214-2.0.0       STARTTLS
214-2.0.0 For more info use "HELP <topic>".
214-2.0.0 To report bugs in the implementation send email to
214-2.0.0       sendmail-bugs@sendmail.org.
214-2.0.0 For local information send email to Postmaster at your site.
214 2.0.0 End of HELP info\x0d\x0a),
	ehlohlp	=>	qq (214-2.0.0 EHLO <hostname>
214-2.0.0       Introduce yourself, and request extended SMTP mode.
214-2.0.0 Possible replies include:
214-2.0.0       SEND            Send as mail                    [RFC821]
214-2.0.0       SOML            Send as mail or terminal        [RFC821]
214-2.0.0       SAML            Send as mail and terminal       [RFC821]
214-2.0.0       EXPN            Expand the mailing list         [RFC821]
214-2.0.0       HELP            Supply helpful information      [RFC821]
214-2.0.0       TURN            Turn the operation around       [RFC821]
214-2.0.0       8BITMIME        Use 8-bit data                  [RFC1652]
214-2.0.0       SIZE            Message size declaration        [RFC1870]
214-2.0.0       VERB            Verbose                         [Allman]
214-2.0.0       ONEX            One message transaction only    [Allman]
214-2.0.0       CHUNKING        Chunking                        [RFC1830]
214-2.0.0       BINARYMIME      Binary MIME                     [RFC1830]
214-2.0.0       PIPELINING      Command Pipelining              [RFC1854]
214-2.0.0       DSN             Delivery Status Notification    [RFC1891]
214-2.0.0       ETRN            Remote Message Queue Starting   [RFC1985]
214-2.0.0       STARTTLS        Secure SMTP                     [RFC2487]
214-2.0.0       AUTH            Authentication                  [RFC2554]
214-2.0.0       XUSR            Initial (user) submission       [Allman]
214-2.0.0       ENHANCEDSTATUSCODES     Enhanced status codes   [RFC2034]
214 2.0.0 End of HELP info\x0d\x0a),
	quit	=>	qq (221 2.0.0 $hostname.$domain closing connection\x0d\x0a)
);
	
  $login = 0;
  print STDERR $smtphash{start};
  while (my $commands = <STDIN>) {
    open(LOG, ">>$sesslog");
    print LOG $commands;
    select LOG;
    $|=1;
    chomp $commands;
    $commands =~ s/\r//;
    @commands=split /\s+/,($commands);

    if ($commands[0] =~ /user/i && $commands[1] =~ /[[:alnum:]]+/){
	if ($login == 1) {
	  print STDERR $ftphash{already};
	} else {
	  $ftpuser = $commands[1];
	  $ftphash{user} =~ s/anon/$ftpuser/;
	  $ftphash{pass} =~ s/anon/$ftpuser/;
	  print STDERR $ftphash{user};
	}

    } elsif ($commands[0] =~ /pass/i && $commands[1] =~ /[[:print:]]+/) {
	if ($login == 1) {
          print STDERR $ftphash{already};
        } else { 
	  if ($ftpuser) {
	    $login = 1;
	    print STDERR $ftphash{pass};
	  }
	}

    } elsif ($commands[0] =~ /list|retr|stor/i) {
        if ($login == 1) {
	  $commands[0] =~ tr/A-Z/a-z/;
          print STDERR $ftphash{$commands[0]};
	  sleep 1;
	  print STDERR $ftphash{compl};
	} else {
	  print STDERR $ftphash{nologin};
        }

   } elsif ($commands[0] =~ /help|pasv|port|pwd|syst|rnfr|rnto|mkd|cwd|cdup|type/i) {
        if ($login == 1) {
	  $commands[0] =~ tr/A-Z/a-z/;
          print STDERR $ftphash{$commands[0]};
	} else {
	  print STDERR $ftphash{nologin};
        }

    } elsif ("$commands" =~ /\bsite help\b/i) {
        if ($login == 1) {
	  $commands =~ tr/A-Z/a-z/;
          print STDERR $ftphash{"$commands"};
	} else {
	  print STDERR $ftphash{nologin};
        }

   } elsif ($commands[0] =~ /exit\b|quit\b/i) {
	print STDERR $ftphash{quit};
        return;

    } else {
	if ($login == 1) {
	  print STDERR "500 @commands: command not understood.\x0d\x0a";
	} else {
	print STDERR $ftphash{nologin};
	}
    }
    close LOG;
  }
}

