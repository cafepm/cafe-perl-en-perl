#!/usr/bin/perl

use warnings;
use strict;
use XML::Smart;
use Error qw(:try);

## TODO : usar el try_use()
## TODO : eliminar todos los literals


### FILE options
my $fileOut = 'survey.xml';

### MAIL options
my $SMTP_server = 'b.mx.zettai.net';
my $to = 'victor@bit-man.com.ar';
my $SMTP_port = 25;
my $thisMachine = "localhost.local";
my $from = "\"anonymous\" <nobody\@$thisMachine>";
my $contentType = "text/xml";


## Internal options (stay your fingers away !!!)
my $debug = 1;

my %wayToSend;
$wayToSend{'MAIL'} = ["Envio automático de la respuesta a través de e-mail "
                   . "(debe estar conectado a Internet)",
                     \&sendMail ];
$wayToSend{'FILE'} = ["Se genera un archivo que deberá ser enviado por Ud. "
                   . "de la manera que crea más conveniente (diskette, e-mail, etc.)",
                     \&storeFile ];

my $subject;
my $errorText = "";

#######################################################################
##
## Returns an XML::Smart with questions to be made
##
sub getSurvey() {
    
my $xml = <<DATA;
<?xml version="1.0" encoding="utf-8" ?>
<Survey  id="CaFePM.2005.Abr">
  <Questions nQuest="9">
	<Question id="utility">
	Te resulta interesante/útil la publicación CaFe Perl que sale todos los 
	principios de mes ??
	</Question>
	<Question id="gusta-mas">
	Qué es lo que más te gusta de CaFe Perl ??
	</Question>
	<Question id="gusta-menos">
	Y lo que menos te gusta ??
	</Question>
	<Question id="secciones">	
	Que secciones o temas te interesan que no están en CaFe Perl ??
	</Question>
	<Question id="colabora" type="choice" options="a,b,c,d,e,f,g">	
	Te interesaráa colaborar en CaFe Perl ??
	    (a) No me interesa
	    (b) Me gustaría colaborar
	        (c) Redactando artículos
	        (d) Buscando material para publicar
	        (e) En la presentación
	        (f) Codificando en Perl (obvio, no ??)
	        (g) En otra cosa : ______________
	</Question>
	<Question id="tech-presentation">	
	Te interesaría asistir a charlas técnicas de Perl ? Sobre que temas ?
	</Question>
	<Question id="activities">	
	Qué otras actividades te gustaría que el CaFe.pm desarrolle ?
	</Question>
	<Question id="meetings">	
	Qué es lo que más y menos te gusta de las meetings ?
	</Question>
	<Question id="something-else">	
	Algo que quisieras decir y no te preguntamos ??
	</Question>
  </Questions>
</Survey>
DATA

	return  XML::Smart->new( $xml );

};

##
##  Returns an XML::Smart object with the answer XML skeleton
##
sub getAnswerXML() {

my $xml = <<DATA;
<?xml version="1.0" encoding="utf-8" ?>
<Survey>
    <Answers nQuest="9">
    </Answers>
</Survey>
DATA

    return  XML::Smart->new( $xml );    
};

##
## Must I say a word about it ??
##
sub processSurvey($) {
    my $survey = shift;
    my $nQuest = $survey->{Survey}->{Questions}->{nQuest};
    my $xmlAnswer = getAnswerXML();
    my $n = 0;
    my $questions = $survey->{Survey}->{Questions}->{Question};

    foreach( @{ $questions } ) {
	    print "Pregunta ". ($n+1) .":  ". $_ ."\n";
	    
        ANSWER:
	    print "Respuesta : ";
	    my $answer =  <STDIN> ;
	    chomp $answer;

        unless ( ($_->{type} eq "freeText") || ($_->{type} eq "") ) {
            if ( ! validAnswer($_->{options}, $answer ) ) {
                print " **** Respuesta no válida\n";
                goto ANSWER;
            }
        };

        print "\n" . "-" x 80 . "\n\n";
        
	    ## Writes answer to XML tree
	    my $newAnswerNode = { 'id' => $_->{id},
	                          'content' => $answer 
	                        };

        push( @{ $xmlAnswer->{Survey}->{Answers}->{answer} }, $newAnswerNode );
        $n++;
	};

    ## HACK: Can't make it work inside sendMail, 
    ##       it returns an empty string :P
    $subject = $survey->{Survey}->{id};
    
    $xmlAnswer->{Survey}->{id} = $survey->{Survey}->{id};
    $xmlAnswer->{Survey}->{Answers}->{nQuest} = $n;
    return $xmlAnswer;
};

##
## Indicates whether the answer is a valid one or no
##
## The first parameter are the comma separated options
## taken as valid (eg. "name,address,phone") and the second one
## id the answer to be validated
##
sub validAnswer($$) {
    my ($options, $answer ) = @_;
    
    foreach ( split /,/, $options ) {
        return 1
            if ($answer eq $_ );
    };
    
    return 0;
};

##
## Makes the answers to the survey permanent, sending them
## to an e-mail account, storing to a file, etc.
## The MASTER configuratiorn for this one is stored in %wayToSend
##
sub storeIt($) {
    my $xmlAnswer = shift;

    print "Estas respuestas deben ser enviadas para su procesamiento,"
        . "pudiendo hacerse de las siguientes maneras :\n\n";
    print "$_ --> " . $wayToSend{$_}->[0] . "\n"
        foreach( keys %wayToSend );

    AGAIN:
    print "\nSu opción : ";
    my $thisAnswer =  <STDIN> ;
	chomp $thisAnswer;
	

	if ( ! validAnswer( join(",", keys %wayToSend ), $thisAnswer ) ) {
	    print " **** Respuesta no válida\n";
	    goto AGAIN;
	};

    ## Stores tha XML file according to the selected option
    ## Any sub must receive an object handler to XML::Smart
    
    &{ $wayToSend{$thisAnswer}->[1] }( $xmlAnswer );
};

## Way to send : FILE
sub storeFile($) {
    my $xml = shift;
    die "No puedo grabar el archivo '$fileOut'\n   $!"
        unless $xml->save($fileOut);
    print "Se grabó el archivo '$fileOut'\n"
};

## Way to send : MAIL
sub sendMail($) {
     use Net::SMTP;

     use Fatal qw(:void Net::SMTP::mail Net::SMTP::to
                  Net::SMTP::data Net::Cmd::datasend Net::Cmd::dataend
                  Net::SMTP::quit);

     my $xml = shift;
     my $msg = $xml->data;

     try {
         my $smtp = Net::SMTP->new( $SMTP_server,  Port => $SMTP_port,
                                    Hello => $thisMachine, Debug => $debug );
         throw Error::Simple( "No puedo mandar e-mail: $!" ) unless $smtp;

         $smtp->mail( $from );
         $smtp->to( $to );

         $smtp->data();
         $smtp->datasend("From: $from\n");
         $smtp->datasend("To: $to\n");
         $smtp->datasend("Subject: $subject\n");
         $smtp->datasend("Content-Type: $contentType\n");
         $smtp->datasend("\n");
         $smtp->datasend( $msg );
         $smtp->dataend();

         $smtp->quit;
    }
    catch Error with {
        my $error = shift;
        die $error->{-text};
    }
    otherwise {
        die "Excepci�n no especificada en sendMail()";
    };
};


## main
########################################################################

my $survey = getSurvey();
my $answer = processSurvey( $survey );
storeIt( $answer );


