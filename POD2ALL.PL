#!/usr/bin/perl

use warnings;
use strict;

###############################################################################
sub usage() {
    return "usage:\n\n"
         . "    pod2all.pl pod_filename_minus_termination Cafe_Perl_version\n"
         . "               list_of_formats_to_produce\n\n"
         . "    e.g. : pod2all.pl Issue04 0.4 man txt\n"
         . "    generates Issue04.man and Issue04.txt\n";
}

# main
###############################################################################

die usage() unless ($ARGV[0] && $ARGV[1] && $ARGV[2]);

my $outFile = shift;
my $version = shift;

my $inFile = "$outFile.pod";

print "Input: '$inFile'\n" .
      "Output: '$outFile'\n\n";

#------------------------------------------------------------------------------
foreach ( @ARGV ) {
    lc $_;

    /html/ && do {
        print "---------- Generando HTML  ----------\n";
        use Pod::Html;
        print "Pod::Html v" . $Pod::Html::VERSION ."\n";
        pod2html( "--infile=$inFile",
                  "--outfile=$outFile.html",
                  "--index");
        next;
    };
    
    /man/ && do {
        print "----------  Generando MAN  ----------\n";
        use Pod::Man;
        print "Pod::Man v" . $Pod::Man::VERSION ."\n";
        my $manParser = Pod::Man->new ();
        $manParser->parse_from_file ( $inFile, "$outFile.man");
        next;
    };
    
    /txt/ && do {
        print "----------  Generando TXT  ----------\n";
        use Pod::Text;
        print "Pod::Text v" . $Pod::Text::VERSION ."\n";
        my $parser = Pod::Text->new (sentence => 0, width => 78);
        $parser->parse_from_file ($inFile, "$outFile.txt");
        next;
    };

    /pdf/ && do {
        print "----------  Generando PDF  ----------\n";
        use Pod::Pdf;
        print "Pod::Pdf v" . $Pod::Pdf::VERSION ."\n";

        pod2pdf( "--podfile=$inFile", 
                 '--title=Cafe Perl v' . $version,
                 '--title0=Periódico de la Comunidad',
                 '--title1=Perl de Capital Federal',
                 '--title2= ',
                 '--title3=http://cafe.pm.org/boletines/' );
        next;
    };
    
    print "Formato '$_' no reconocido\n";
};



