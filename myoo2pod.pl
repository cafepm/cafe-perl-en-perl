#!/usr/bin/perl -w

=head1	NAME

oo2pod - POD generation from an OpenOffice.org document

=head1	SYNOPSIS

Usage : oo2pod <oofilename>

=head1	DESCRIPTION

This demo script exports the content of a given OpenOffice.org file
to POD on the standard output. In the present form, it's quite limited
and not flexible, in order to remain easily readable. It should be
considered as an example of text extraction using OpenOffice::OODoc
and not as the 'definitive' oo2pod filter.

Before extraction, some transformations are done in the document
in order to make it more convenient for a POD presentation. Some
pieces of metadata (title, subject, description), if defined, are
reported in the beginning of the POD. The footnotes are removed from
the content and reported in a special section at the end.

This script needs Text::Wrapper (that is not necessarily required
by the OpenOffice::OODoc installation). To implement more sophisicated
presentation rules, you could use Text::Format instead.

=cut

##
## La idea es poder editar un documento con OpenOffice.org, para que 
## maneje todas las tareas concernientes y uno pueda simplementa dedicarse 
## a edición y estilos, sin tener en cuenta el formato final.
## El problema es que el oo2pod que viene en en OpenOffice::OODoc si bien
## genera un POD es muy básico y sin estilo. Basándonos en este módulo y
## en las convenciones de Pod::OOoWriter es que se genera este oo2pod
##

use warnings;
use strict;
use OpenOffice::OODoc;
use Text::Wrapper;

#-----------------------------------------------------------------------------
my $meta;	# will be the metadata object
my $doc;	# will be the document content object
my $style = { "Heading 1" => "head1",
              "Heading 2" => "head2",
              "Heading 3" => "head3",
              "Heading 4" => "head4",
            };

my $codeSection = 'Preformatted Text';
my $debug = 0;
my $tabEquivalence = 4;    ## Tab equivalence into spaces
#-----------------------------------------------------------------------------
# text output utilities (using Text::Wrapper)

my $wrapper;

sub	BEGIN {	# wrappers initialisation

	$wrapper = Text::Wrapper->new(
			    columns		=> 76
               );
};


#-----------------------------------------------------------------------------

# initialise the OOo file object
my $ooarchive	= ooFile($ARGV[0])
	or die "No regular OpenOffice.org file\n";

# extract the metadata
$meta	= ooMeta(archive => $ooarchive)
	or warn "This file has not standard OOo properties. Looks strange.\n";

# extract the content
$doc	= ooDocument(archive => $ooarchive, member => 'content')
	or die "No standard OOo content ! I give up !\n";

# attempt to use some metadata to begin the output
if ($meta)
	{
	my $title = $meta->title;
	if ($title)
		{
		header_output(1, "NAME");
		print $wrapper->wrap($title) . "\n";
		}
	my $subject = $meta->subject;
	if ($subject)
		{
		header_output(1, "SUBJECT");
		print $wrapper->wrap($subject) . "\n";
		}
	my $description = $meta->description;
	if ($description)
		{
		header_output(1, "DESCRIPTION");
		print $wrapper->wrap($description) . "\n";
		}
	# we could dump other metadata here...
	}

# the strange 2 next lines prevent the getText() method of
# OpenOffice::OODoc::Text (see the corresponding man page) from using
# its default tags for spans and footnotes
delete $doc->{'delimiters'}->{'text:span'};
delete $doc->{'delimiters'}->{'text:footnote-body'};

# here we select the tab as field separator for table field output
# (the default is ";" as for CSV output)
$doc->{'field_separator'} = "\t";

# in the next sequence, we will extract all the footnotes, store them for
# later processing and remove them from the content
my @notes = $doc->getFootnoteList;
$doc->removeElement($_) for @notes;

# get the full list of text objects (without the previously removed footnotes)
###my @content = $doc->getTextElementList;

# if the first text element is not a header, we create a leading
# header here, using the title or an arbitrary name
###header_output(1, $meta->title || "INTRODUCTION")
###	unless ($content[0]->isHeader);


##
## TODO : falta implementar 
##      =begin formatname
##      =end formatname
##      =for formatname text...
##
##      =encoding
##
##      Formating codes
##

my $expandedTabs = " " x $tabEquivalence;
# Begins POD output
print "=pod\n\n";

foreach my $element ( $doc->getTextElementList ) {
    ## ppStyle : Paragraph Style
    my $ppStyle = $style->{ $doc->textStyle( $element ) }; 
    
    if ( $ppStyle ) {
        headerOutput( $doc, $element, $ppStyle );
    } else {
        contentOutput( $doc, $element );
    };
};

# all the document body is processed

if (@notes)
	{
	# OK, we have some footnotes in store
	# create a special section
	header_output(1, "NOTES");
	my $count = 0;
	while (@notes)
		{
		$count++;
		my $element = shift @notes;
		my $text = "[$count] " . $doc->getText($element);
		print	$wrapper->wrap($text); ## . "\n";
		}
	}

# end of POD output
print "=cut\n\n";

exit;

#-----------------------------------------------------------------------------
sub convetTabs($) {
    $_[0] =~ s/\t/$expandedTabs/g;
    return $_[0];
};

sub	headerOutput($$$) {
    my ( $doc, $element, $ppStyle ) = @_;
    print "=" . $ppStyle . " " . $doc->getText( $element ) . "\n";
};

# output the content according to the type of text object
sub	contentOutput($$) {
    my ( $doc, $element ) = @_;

    ## Lists : numbered and unnumbered
    
    ## TODO : ordered and unordered are seen as ordered !!!
    ##        OjO porque están todas como ordered (en el content.xml) aunque no 
    ##        se vean así (ver si no se trata de un problema de versión del
    ##        OpenOffice)
    
	$element->isItemList && do {
        print "=over ". $element->level ."\n\n";

        my $nItem = 1;     ## List item counter.
        print "=item ". ( $element->isOrderedList ? $nItem++ : "*" ) .
              " " . $wrapper->wrap( $doc->getText( $_ ) ) . "\n"
            foreach( $doc->getItemElementList( $element )  );

        print "=back\n\n";
        return;
	};

    ### TODO : buscar una forma de que los textos en bold se vean reflejados
    
    ### TODO : detectar los links y poner L<> alrededor

    ### getStyle(element) --> Obsolete. See textStyle.
    ###
    ### textStyle --> the returned value is a literal style identifier or the 
    ###               value of the element's 'text:style-name' attribute.

    ## Code handling
    my $styleName = $doc->textStyle( $element );

    ($styleName eq $codeSection) && do {
        print " " . convetTabs( $doc->getText( $element ) ) . "\n";
        return;
    };

    my $style = $doc->styleProperties( $styleName ) || "NADA";
    print "*** DEBUG Name: '$styleName'  element: '$style'  \n"
        if $debug;
    
    ## TODO : Convertir a ISO-8859-1 con inputTextConversion()
    print $wrapper->wrap(  $doc->getText( $element ) ) . "\n";
}

#-----------------------------------------------------------------------------

