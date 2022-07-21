#!/usr/bin/perl

use warnings;
use strict;
use Net::SMTP;
use Error qw(:try);

## TODO : pasar como parámetros en la línea de comandos

my $SMTP_server = 'a.mx.zettai.net';
my $to = 'victor@bit-man.com.ar';

#my $SMTP_server = 'mx.develooper.com';
#my $to = 'cafe-pm@pm.org';
my $subject = "CaFe Perl v0.3";
my $file = "non_existent_file";

my $from = '"Víctor A. Rodríguez" <victor@bit-man.com.ar>';
my $SMTP_port = 25;
my $thisMachine = "OL24-195.fibertel.com.ar";

my $contentType = "text/plain";
my $charSet = "iso-8859-1";

my @message;
my $errorText = "";
my $debug = 1;

#######################################################################
sub getMsg($$) {
    my $file = shift;
    my $msg = shift;

    use Fatal qw(:void open close);

    try {
        open (my $FH, $file);
        while ( <$FH> ) {
            push @$msg, $_;
        };
        close $FH;
    }
    catch Error with {
        my $error = shift;
        $errorText = $error->{-text};
    }
    otherwise {
        $errorText = "Uncaught exception in getMSg()";
    };
    
    return ($errorText eq "");
};

sub sendMail($$$$$) {
     my $from = shift;
     my $to = shift;
     my $subject = shift;
     my $msg = shift;
     my $debug = shift;

     use Fatal qw(:void Net::SMTP::mail Net::SMTP::to
                  Net::SMTP::data Net::Cmd::datasend Net::Cmd::dataend
                  Net::SMTP::quit);

     try {
         my $smtp = Net::SMTP->new( $SMTP_server,  Port => $SMTP_port,
                                    Hello => $thisMachine, Debug => $debug );
         throw Error::Simple( "No puedo mandar e-mail: $!" ) unless $smtp;

         $smtp->mail( $from );
         $smtp->to( $to );

         ## TODO : enviar como adjunto, para evitar problemas con encoding y
         ##        reducir el tamaño
         $smtp->data();
         $smtp->datasend("From: $from\n");
         $smtp->datasend("To: $to\n");
         $smtp->datasend("Subject: $subject\n");
         $smtp->datasend("Content-Type: $contentType; charset: $charSet\n");
         $smtp->datasend("\n");
         foreach( @$msg ) {
             $smtp->datasend("$_");
         };
         $smtp->dataend();

         $smtp->quit;
    }
    catch Error with {
        my $error = shift;
        $errorText = $error->{-text};
    }
    otherwise {
        $errorText = "Uncaught exception in sendMail()";
    };
    
    return ($errorText eq "");
};

sub doError() {
    print STDERR "\n"
                 . "-" x 60
                 . "\nError fatal !!!!\n    $errorText\n";
};

# main
################################################################################

use Fatal qw(:void getMsg sendMail);

try {
    print "Getting message...\n" if $debug;
    getMsg( $file, \@message );
    print "Sending mail...\n" if $debug;
    sendMail( $from, $to, $subject, \@message, $debug);
}
catch Error with {
    doError();
    exit;
};

