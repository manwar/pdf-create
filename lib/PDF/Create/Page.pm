package PDF::Create::Page;

our $VERSION = '1.19';

=encoding utf8

=head1 NAME

PDF::Create::Page - PDF pages tree for PDF::Create

=head1 VERSION

Version 1.19

=cut

use 5.006;
use strict; use warnings;

use Carp;
use FileHandle;
use Data::Dumper;
use POSIX qw(setlocale LC_NUMERIC);
use Scalar::Util qw(weaken);

our $DEBUG = 0;

my $font_widths = &init_widths;
# Global variable for text function
my $ptext       = '';

=head1 DESCRIPTION

B<FOR INTERNAL USE ONLY>

=cut

sub new {
    my ($this) = @_;

    my $class = ref($this) || $this;
    my $self  = {};
    bless $self, $class;
    $self->{'Kids'}    = [];
    $self->{'Content'} = [];

    return $self;
}

=head1 METHODS

=head2 add($id, $name)

Adds a page to the PDF document.

=cut

sub add {
    my ($self, $id, $name) = @_;

    my $page = PDF::Create::Page->new();
    $page->{'pdf'}    = $self->{'pdf'};
    weaken $page->{pdf};
    $page->{'Parent'} = $self;
    weaken $page->{Parent};
    $page->{'id'}     = $id;
    $page->{'name'}   = $name;
    push @{$self->{'Kids'}}, $page;

    return $page;
}

=head2 count()

Returns page count.

=cut

sub count {
    my ($self) = @_;

    my $c = 0;
    $c++ unless scalar @{$self->{'Kids'}};
    foreach my $page (@{$self->{'Kids'}}) {
        $c += $page->count;
    }

    return $c;
}

=head2 kids()

Returns ref to a list of page ids.

=cut

sub kids {
    my ($self) = @_;

    my $t = [];
    map { push @$t, $_->{'id'} } @{$self->{'Kids'}};

    return $t;
}

=head2 list()

Returns page list.

=cut

sub list {
    my ($self) = @_;

    my @l;
    foreach my $e (@{$self->{'Kids'}}) {
        my @t = $e->list;
        push @l, $e;
        push @l, @t if scalar @t;
    }

    return @l;
}

=head2 new_page()

Return new page.

=cut

sub new_page {
    my ($self, @params) = @_;

    return $self->{'pdf'}->new_page('Parent' => $self, @params);
}

#
#
# Drawing functions

=head2 moveto($x, $y)

Moves the current point to (x, y), omitting any connecting line segment.


=cut

sub moveto {
    my ($self, $x, $y) = @_;

    $self->{'pdf'}->page_stream($self);
    $self->{'pdf'}->add("$x $y m");
}

=head2 lineto($x, $y)

Appends a straight line segment from the current point to (x, y).

=cut

sub lineto {
    my ($self, $x, $y) = @_;

    $self->{'pdf'}->page_stream($self);
    $self->{'pdf'}->add("$x $y l");
}

=head2 curveto($x1, $y1, $x2, $y2, $x3, $y3)

Appends a Bezier  curve  to the path. The curve extends from the current point to
(x3 ,y3) using (x1 ,y1) and (x2 ,y2) as the Bezier control points.The new current
point is (x3 ,y3).

=cut

sub curveto {
    my ($self, $x1, $y1, $x2, $y2, $x3, $y3) = @_;

    $self->{'pdf'}->page_stream($self);
    $self->{'pdf'}->add("$x1 $y1 $x2 $y2 $x3 $y3 c");
}

=head2 rectangle($x, $y, $w, $h)

Adds a rectangle to the current path.

=cut

sub rectangle {
    my ($self, $x, $y, $w, $h) = @_;

    $self->{'pdf'}->page_stream($self);
    $self->{'pdf'}->add("$x $y $w $h re");
}

=head2 closepath()

Closes the current subpath by appending a straight line segment from the current
point to the starting point of the subpath.

=cut

sub closepath {
    my ($self) = @_;

    $self->{'pdf'}->page_stream($self);
    $self->{'pdf'}->add("h");
}

=head2 newpath()

Ends the path without filling or stroking it.

=cut

sub newpath {
    my ($self) = @_;

    $self->{'pdf'}->page_stream($self);
    $self->{'pdf'}->add("n");
}

=head2 stroke()

Strokes the path.

=cut

sub stroke {
    my ($self) = @_;

    $self->{'pdf'}->page_stream($self);
    $self->{'pdf'}->add("S");
}

=head2 closestroke()

Closes and strokes the path.

=cut

sub closestroke {
    my ($self) = @_;

    $self->{'pdf'}->page_stream($self);
    $self->{'pdf'}->add("s");
}

=head2 fill()

Fills the path using the non-zero winding number rule.

=cut

sub fill {
    my ($self) = @_;

    $self->{'pdf'}->page_stream($self);
    $self->{'pdf'}->add("f");
}

=head2 fill2()

Fills the path using the even-odd rule.

=cut

sub fill2 {
    my ($self) = @_;

    $self->{'pdf'}->page_stream($self);
    $self->{'pdf'}->add("f*");
}

=head2 line($x1, $y1, $x2, $y2)

Draw a  line between ($x1, $y1) and ($x2, $y2). Combined moveto / lineto / stroke
command.

=cut

sub line {
    my ($self, $x1, $y1, $x2, $y2) = @_;

    $self->{'pdf'}->page_stream($self);
    $self->{'pdf'}->add("$x1 $y1 m $x2 $y2 l S");
}

=head2 set_width($w)

Set the width of subsequent lines to C<w> points.

=cut

sub set_width {
    my ($self, $w) = @_;

    $self->{'pdf'}->page_stream($self);
    $self->{'pdf'}->add("$w w");
}

#
#
# Color functions

=head2 setgray($value)

Sets the color space to DeviceGray and sets the gray tint to use for filling paths.

=cut

sub setgray {
    my ($self, $val) = @_;

    $self->{'pdf'}->page_stream($self);
    $self->{'pdf'}->add("$val g");
}

=head2 setgraystroke($value)

Sets the color space to DeviceGray and sets the gray tint to use for stroking paths.

=cut

sub setgraystroke {
    my ($self, $val) = @_;

    $self->{'pdf'}->page_stream($self);
    $self->{'pdf'}->add("$val G");
}

=head2 setrgbcolor($r, $g, $b)

Sets the fill colors used for normal text or filled objects.

=cut

sub setrgbcolor {
    my ($self, $r, $g, $b) = @_;

    $self->{'pdf'}->page_stream($self);
    $self->{'pdf'}->add("$r $g $b rg");
}

=head2 setrgbcolorstroke($r, $g, $b)

Set the color  of the subsequent drawing operations. Valid r, g, and b values are
each between 0.0 and 1.0, inclusive.

Each color ranges from 0.0 to 1.0, i.e., darkest red (0.0) to brightest red(1.0).
The same holds for green and blue.  These three colors mix  additively to produce
the colors between black (0.0, 0.0, 0.0) and white (1.0, 1.0, 1.0).

PDF distinguishes between  the stroke  and  fill operations and provides separate
color settings for each.

=cut

sub setrgbcolorstroke {
    my ($self, $r, $g, $b) = @_;

    croak "Error setting colors, need three values" if !defined $b;
    $self->{'pdf'}->page_stream($self);
    $self->{'pdf'}->add("$r $g $b RG");
}

#
#
# Text functions

=head2 text(%params)

=cut

sub text {
    my ($self, %params) = @_;

    PDF::Create::debug( 2, "text(%params):" );

    if (defined $params{'start'}) { $ptext = "BT "; }

    # Text Rise (Super/Subscript)
    if (defined $params{'Ts'})    { $ptext .= " $params{'Ts'} Ts "; }
    # Rendering Mode
    if (defined $params{'Tr'})    { $ptext .= " $params{'Tr'} Tr "; }
    # Text Leading
    if (defined $params{'TL'})    { $ptext .= " $params{'TL'} TL "; }
    # Character spacing
    if (defined $params{'Tc'})    { $ptext .= " $params{'Tc'} Tc "; }
    # Word Spacing
    if (defined $params{'Tw'})    { $ptext .= " $params{'Tw'} Tw "; }
    # Horizontal Scaling
    if (defined $params{'Tz'})    { $ptext .= " $params{'Tz'} Tz "; }

    # Moveto and rotateOA
    my $pi = atan2(1, 1) * 4;
    my $piover180 = $pi / 180;
    if (defined $params{'rot'}) {
        my ($r, $x, $y) = split( /\s+/, $params{'rot'}, 3 );
        $x = 0 unless ($x > 0);
        $y = 0 unless ($y > 0);
        my $cos = cos($r * $piover180);
        my $sin = sin($r * $piover180);
        $ptext .= sprintf(" %.5f %.5f -%.5f %.5f %s %s Tm ", $cos, $sin, $sin, $cos, $x, $y);
    }

    # Font size
    if (defined $params{'Tf'}) { $ptext .= "/F$params{'Tf'} Tf "; }
    # Moveto
    if (defined $params{'Td'}) { $ptext .= " $params{'Td'} Td "; }
    # Moveto and set TL
    if (defined $params{'TD'}) { $ptext .= " $params{'TD'} TD "; }
    # New line
    if (defined $params{'T*'}) { $ptext .= " T* "; }

    if (defined $params{'text'}) {
        $params{'text'} =~ s|([()])|\\$1|g;
        $ptext .= "($params{'text'}) Tj ";
    }

    if (defined $params{'end'}) {
        $ptext .= " ET";
        $self->{'pdf'}->page_stream($self);
        $self->{'pdf'}->add("$ptext");
    }

    PDF::Create::debug( 3, "text(): $ptext" );

    1;
}

=head2 string($font, $size, $x, $y, $text $alignment)

Add text to the current page using the font object at the given size and position.
The point (x, y) is the bottom left corner of the rectangle containing the text.

The optional alignment can be 'r' for right-alignment and 'c' for centered.

Example :

    my $f1 = $pdf->font(
       'Subtype'  => 'Type1',
       'Encoding' => 'WinAnsiEncoding',
       'BaseFont' => 'Helvetica'
    );

    $page->string($f1, 20, 306, 396, "some text");

=cut

sub string {
    my ($self, $font, $size, $x, $y, $string, $align,
        $char_spacing, $word_spacing) = @_;

    $align = 'L' unless defined $align;

    if (uc($align) eq "R") {
        $x -= $size * $self->string_width($font, $string);
    } elsif (uc($align) eq "C") {
        $x -= $size * $self->string_width($font, $string) / 2;
    }

    if (defined $char_spacing && $char_spacing =~ m/[0-9]+\.?[0-9]*/) {
        $char_spacing = sprintf("%s Tc", $char_spacing);
    }
    else {
        $char_spacing = '';
    }

    if (defined $word_spacing && $word_spacing =~ m/[0-9]+\.?[0-9]*/) {
        $word_spacing = sprintf("%s Tw", $word_spacing);
    }
    else {
        $word_spacing = '';
    }

    $self->{'pdf'}->page_stream($self);
    $self->{'pdf'}->uses_font($self, $font);
    $string =~ s|([()])|\\$1|g;
    $self->{'pdf'}->add("BT /F$font $size Tf $char_spacing $word_spacing $x $y Td ($string) Tj ET");
}

=head2 string_underline($font, $size, $x, $y, $text, $alignment)

Draw a line for underlining.The parameters are the same as for the string function
but only the line is drawn. To draw an underlined string you must call both,string
and string_underline. To change the color of  your text  use the C<setrgbcolor()>.
It  returns the length of the string. So its return value can be used directly for
the bounding box of an annotation.

Example :

    $page->string($f1, 20, 306, 396, "some underlined text");

    $page->string_underline($f1, 20, 306, 396, "some underlined text");

=cut

sub string_underline {
    my ($self, $font, $size, $x, $y, $string, $align) = @_;

    my $len1 = $self->string_width($font, $string) * $size;
    my $len2 = $len1 / 2;
    if (uc($align) eq "R") {
        $self->line($x - $len1, $y - 1, $x, $y - 1);
    } elsif (uc($align) eq "C") {
        $self->line($x - $len2, $y - 1, $x + $len2, $y - 1);
    } else {
        $self->line($x, $y - 1, $x + $len1, $y - 1);
    }

    return $len1;
}

=head2 stringl($font, $size, $x, $y $text)

Same as C<string()>.

=cut

sub stringl {
    my ($self, $font, $size, $x, $y, $string) = @_;

    $self->{'pdf'}->page_stream($self);
    $self->{'pdf'}->uses_font($self, $font);
    $string =~ s|([()])|\\$1|g;
    $self->{'pdf'}->add("BT /F$font $size Tf $x $y Td ($string) Tj ET");
}

=head2 stringr($font, $size, $x, $y, $text)

Same as C<string()> but right aligned (alignment 'r').

=cut

sub stringr {
    my ($self, $font, $size, $x, $y, $string) = @_;

    $self->{'pdf'}->page_stream($self);
    $self->{'pdf'}->uses_font($self, $font);
    $x -= $size * $self->string_width($font, $string);
    $string =~ s|([()])|\\$1|g;
    $self->{'pdf'}->add(" BT /F$font $size Tf $x $y Td ($string) Tj ET");
}

=head2 stringc($font, $size, $x, $y, $text)

Same as C<string()> but centered (alignment 'c').

=cut

sub stringc {
    my ($self, $font, $size, $x, $y, $string) = @_;

    $self->{'pdf'}->page_stream($self);
    $self->{'pdf'}->uses_font($self, $font);
    $x -= $size * $self->string_width($font, $string) / 2;
    $string =~ s|([()])|\\$1|g;
    $self->{'pdf'}->add(" BT /F$font $size Tf $x $y Td ($string) Tj ET");
}

=head2 string_width($font, $text)

Return the size of the text using the given font in default user space units.This
does not contain the size of the font yet, to get the length you must multiply by
the font size.

=cut

sub string_width {
    my ($self, $font, $string) = @_;

    croak 'No string given' unless defined $string;

    my $fname = $self->{'pdf'}{'fonts'}{$font}{'BaseFont'}[1];
    croak('Unknown font: ' . $fname) unless defined $$font_widths{$fname}[ ord "M" ];

    my $w = 0;
    for my $c ( split '', $string ) {
        $w += $$font_widths{$fname}[ ord $c ];
    }

    return $w / 1000;
}

=head2 printnl($text, $font, $size, $x, $y)

Similar to  C<string()> but parses the string for newline and prints each part on
a separate line. Lines spacing is the same as the font-size.Returns the number of
lines.

Note the different parameter sequence.The first call should specify all parameters,
font is  the absolute minimum, a warning will be given for the missing y position
and 800  will  be assumed. All subsequent invocations can omit all but the string
parameters.

ATTENTION:There is no provision for changing pages.If you run out of space on the
current page this will draw the string(s) outside the page and it will be invisble.

=cut

sub printnl {
    my ($self, $s, $font, $size, $x, $y) = @_;

    $self->{'current_font'} = $font if defined $font;
    croak 'No font found !' if !defined $self->{'current_font'};

    # set up current_x/y used in stringml
    $self->{'current_y'} = $y if defined $y;
    carp 'No starting position given, using 800' if !defined $self->{'current_y'};
    $self->{'current_y'}    = 800   if !defined $self->{'current_y'};
    $self->{'current_x'}    = $x    if defined $x;
    $self->{'current_x'}    = 20    if !defined $self->{'current_x'};
    $self->{'current_size'} = $size if defined $size;
    $self->{'current_size'} = 12    if !defined $self->{'current_size'};

    # print the line(s)
    my $n = 0;
    for my $line ( split '\n', $s ) {
        $n++;
        $self->string($self->{'current_font'}, $self->{'current_size'}, $self->{'current_x'}, $self->{'current_y'}, $line);
        $self->{'current_y'} = $self->{'current_y'} - $self->{'current_size'};
    }

    return $n;
}

=head2 image(%params)

Inserts an image. Parameters can be:

    +----------------+----------------------------------------------------------+
    | Key            | Description                                              |
    +----------------+----------------------------------------------------------+
    |                |                                                          |
    | image          | Image id returned by PDF::image (required).              |
    |                |                                                          |
    | xpos, ypos     | Position of image (required).                            |
    |                |                                                          |
    | xalign, yalign | Alignment of image.0 is left/bottom, 1 is centered and 2 |
    |                | is right, top.                                           |
    |                |                                                          |
    | xscale, yscale | Scaling of image. 1.0 is original size.                  |
    |                |                                                          |
    | rotate         | Rotation of image.0 is no rotation,2*pi is 360° rotation.|
    |                |                                                          |
    | xskew, yskew   | Skew of image.                                           |
    |                |                                                          |
    +----------------+----------------------------------------------------------+

Example jpeg image:

    # include a jpeg image with scaling to 20% size
    my $jpg = $pdf->image("image.jpg");

    $page->image(
        'image'  => $jpg,
        'xscale' => 0.2,
        'yscale' => 0.2,
        'xpos'   => 350,
        'ypos'   => 400
    );

=cut

sub image {
    my ($self, %params) = @_;

    # Switch to the 'C' locale, we need printf floats with a '.', not a ','
    my $savedLocale = setlocale(LC_NUMERIC);
    setlocale(LC_NUMERIC,'C');

    my $img    = $params{'image'} || "1.2";
    my $image  = $img->{num};
    my $xpos   = $params{'xpos'} || 0;
    my $ypos   = $params{'ypos'} || 0;
    my $xalign = $params{'xalign'} || 0;
    my $yalign = $params{'yalign'} || 0;
    my $xscale = $params{'xscale'} || 1;
    my $yscale = $params{'yscale'} || 1;
    my $rotate = $params{'rotate'} || 0;
    my $xskew  = $params{'xskew'} || 0;
    my $yskew  = $params{'yskew'} || 0;

    $xscale *= $img->{width};
    $yscale *= $img->{height};

    if ($xalign == 1) {
        $xpos -= $xscale / 2;
    } elsif ($xalign == 2) {
        $xpos -= $xscale;
    }

    if ($yalign == 1) {
        $ypos -= $yscale / 2;
    } elsif ($yalign == 2) {
        $ypos -= $yscale;
    }

    $self->{'pdf'}->page_stream($self);
    $self->{'pdf'}->uses_xobject( $self, $image );
    $self->{'pdf'}->add("q\n");

    # TODO: image: Merge position with rotate
    $self->{'pdf'}->add("1 0 0 1 $xpos $ypos cm\n")
        if ($xpos || $ypos);

    if ($rotate) {
        my $sinth = sin($rotate);
        my $costh = cos($rotate);
        $self->{'pdf'}->add("$costh $sinth -$sinth $costh 0 0 cm\n");
    }
    if ($xscale || $yscale) {
        $self->{'pdf'}->add("$xscale 0 0 $yscale 0 0 cm\n");
    }
    if ($xskew || $yskew) {
        my $tana = sin($xskew) / cos($xskew);
        my $tanb = sin($yskew) / cos($xskew);
        $self->{'pdf'}->add("1 $tana $tanb 1 0 0 cm\n");
    }
    $self->{'pdf'}->add("/Image$image Do\n");
    $self->{'pdf'}->add("Q\n");

    # Switch to the 'C' locale, we need printf floats with a '.', not a ','
    setlocale(LC_NUMERIC,$savedLocale);
}

# Table with font widths for the supported fonts.
sub init_widths
{
    {  'Courier'               => [ 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599 ],
       'Courier-Bold'          => [ 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599 ],
       'Courier-BoldOblique'   => [ 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599 ],
       'Courier-Oblique'       => [ 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599,
                                    599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599, 599 ],
       'Helvetica'             => [ 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277,  277, 277, 277, 277, 277, 277, 277,
                                    277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277,  277, 277, 277, 277, 277, 354, 555,
                                    555, 888, 666, 220, 332, 332, 388, 583, 277, 332, 277,  277, 555, 555, 555, 555, 555, 555,
                                    555, 555, 555, 555, 277, 277, 583, 583, 583, 555, 1014, 666, 666, 721, 721, 666, 610, 777,
                                    721, 277, 499, 666, 555, 832, 721, 777, 666, 777, 721,  666, 610, 721, 666, 943, 666, 666,
                                    610, 277, 277, 277, 468, 555, 221, 555, 555, 499, 555,  555, 277, 555, 555, 221, 221, 499,
                                    221, 832, 555, 555, 555, 555, 332, 499, 277, 555, 499,  721, 499, 499, 499, 333, 259, 333,
                                    583, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277,  277, 277, 277, 277, 277, 277, 277,
                                    277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277,  277, 277, 277, 277, 277, 277, 332,
                                    555, 555, 166, 555, 555, 555, 555, 190, 332, 555, 332,  332, 499, 499, 277, 555, 555, 555,
                                    277, 277, 536, 349, 221, 332, 332, 555, 999, 999, 277,  610, 277, 332, 332, 332, 332, 332,
                                    332, 332, 332, 277, 332, 332, 277, 332, 332, 332, 999,  277, 277, 277, 277, 277, 277, 277,
                                    277, 277, 277, 277, 277, 277, 277, 277, 277, 999, 277,  369, 277, 277, 277, 277, 555, 777,
                                    999, 364, 277, 277, 277, 277, 277, 888, 277, 277, 277,  277, 277, 277, 221, 610, 943, 610,
                                    277, 277, 277, 277 ],
       'Helvetica-Bold'        => [ 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277,
                                    277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 332, 473, 555, 555, 888, 721, 277,
                                    332, 332, 388, 583, 277, 332, 277, 277, 555, 555, 555, 555, 555, 555, 555, 555, 555, 555, 332, 332,
                                    583, 583, 583, 610, 974, 721, 721, 721, 721, 666, 610, 777, 721, 277, 555, 721, 610, 832, 721, 777,
                                    666, 777, 721, 666, 610, 721, 666, 943, 666, 666, 610, 332, 277, 332, 583, 555, 277, 555, 610, 555,
                                    610, 555, 332, 610, 610, 277, 277, 555, 277, 888, 610, 610, 610, 610, 388, 555, 332, 610, 555, 777,
                                    555, 555, 499, 388, 279, 388, 583, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277,
                                    277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277,
                                    277, 332, 555, 555, 166, 555, 555, 555, 555, 237, 499, 555, 332, 332, 610, 610, 277, 555, 555, 555,
                                    277, 277, 555, 349, 277, 499, 499, 555, 999, 999, 277, 610, 277, 332, 332, 332, 332, 332, 332, 332,
                                    332, 277, 332, 332, 277, 332, 332, 332, 999, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277,
                                    277, 277, 277, 277, 277, 999, 277, 369, 277, 277, 277, 277, 610, 777, 999, 364, 277, 277, 277, 277,
                                    277, 888, 277, 277, 277, 277, 277, 277, 277, 610, 943, 610, 277, 277, 277, 277 ],
       'Helvetica-BoldOblique' => [ 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277,
                                    277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 332, 473, 555,
                                    555, 888, 721, 277, 332, 332, 388, 583, 277, 332, 277, 277, 555, 555, 555, 555, 555, 555,
                                    555, 555, 555, 555, 332, 332, 583, 583, 583, 610, 974, 721, 721, 721, 721, 666, 610, 777,
                                    721, 277, 555, 721, 610, 832, 721, 777, 666, 777, 721, 666, 610, 721, 666, 943, 666, 666,
                                    610, 332, 277, 332, 583, 555, 277, 555, 610, 555, 610, 555, 332, 610, 610, 277, 277, 555,
                                    277, 888, 610, 610, 610, 610, 388, 555, 332, 610, 555, 777, 555, 555, 499, 388, 279, 388,
                                    583, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277,
                                    277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 332,
                                    555, 555, 166, 555, 555, 555, 555, 237, 499, 555, 332, 332, 610, 610, 277, 555, 555, 555,
                                    277, 277, 555, 349, 277, 499, 499, 555, 999, 999, 277, 610, 277, 332, 332, 332, 332, 332,
                                    332, 332, 332, 277, 332, 332, 277, 332, 332, 332, 999, 277, 277, 277, 277, 277, 277, 277,
                                    277, 277, 277, 277, 277, 277, 277, 277, 277, 999, 277, 369, 277, 277, 277, 277, 610, 777,
                                    999, 364, 277, 277, 277, 277, 277, 888, 277, 277, 277, 277, 277, 277, 277, 610, 943, 610,
                                    277, 277, 277, 277 ],
       'Helvetica-Oblique'     => [ 277, 277, 277, 277, 277, 277, 277, 277, 277, 277,  277,
                                    277, 277, 277, 277, 277, 277, 277, 277, 277, 277,  277,
                                    277, 277, 277, 277, 277, 277, 277, 277, 277, 277,  277,
                                    277, 354, 555, 555, 888, 666, 221, 332, 332, 388,  583,
                                    277, 332, 277, 277, 555, 555, 555, 555, 555, 555,  555,
                                    555, 555, 555, 277, 277, 583, 583, 583, 555, 1014, 666,
                                    666, 721, 721, 666, 610, 777, 721, 277, 499, 666,  555,
                                    832, 721, 777, 666, 777, 721, 666, 610, 721, 666,  943,
                                    666, 666, 610, 277, 277, 277, 468, 555, 221, 555,  555,
                                    499, 555, 555, 277, 555, 555, 221, 221, 499, 221,  832,
                                    555, 555, 555, 555, 332, 499, 277, 555, 499, 721,  499,
                                    499, 499, 333, 259, 333, 583, 277, 277, 277, 277,  277,
                                    277, 277, 277, 277, 277, 277, 277, 277, 277, 277,  277,
                                    277, 277, 277, 277, 277, 277, 277, 277, 277, 277,  277,
                                    277, 277, 277, 277, 277, 277, 277, 332, 555, 555,  166,
                                    555, 555, 555, 555, 190, 332, 555, 332, 332, 499,  499,
                                    277, 555, 555, 555, 277, 277, 536, 349, 221, 332,  332,
                                    555, 999, 999, 277, 610, 277, 332, 332, 332, 332,  332,
                                    332, 332, 332, 277, 332, 332, 277, 332, 332, 332,  999,
                                    277, 277, 277, 277, 277, 277, 277, 277, 277, 277,  277,
                                    277, 277, 277, 277, 277, 999, 277, 369, 277, 277,  277,
                                    277, 555, 777, 999, 364, 277, 277, 277, 277, 277,  888,
                                    277, 277, 277, 277, 277, 277, 221, 610, 943, 610,  277,
                                    277, 277, 277 ],
       'Times-Bold'            => [ 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249,
                                    249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 332, 554, 499, 499, 999, 832, 332,
                                    332, 332, 499, 569, 249, 332, 249, 277, 499, 499, 499, 499, 499, 499, 499, 499, 499, 499, 332, 332,
                                    569, 569, 569, 499, 929, 721, 666, 721, 721, 666, 610, 777, 777, 388, 499, 777, 666, 943, 721, 777,
                                    610, 777, 721, 555, 666, 721, 721, 999, 721, 721, 666, 332, 277, 332, 580, 499, 332, 499, 555, 443,
                                    555, 443, 332, 499, 555, 277, 332, 555, 277, 832, 555, 499, 555, 555, 443, 388, 332, 555, 499, 721,
                                    499, 499, 443, 393, 219, 393, 519, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249,
                                    249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249,
                                    249, 332, 499, 499, 166, 499, 499, 499, 499, 277, 499, 499, 332, 332, 555, 555, 249, 499, 499, 499,
                                    249, 249, 539, 349, 332, 499, 499, 499, 999, 999, 249, 499, 249, 332, 332, 332, 332, 332, 332, 332,
                                    332, 249, 332, 332, 249, 332, 332, 332, 999, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249,
                                    249, 249, 249, 249, 249, 999, 249, 299, 249, 249, 249, 249, 666, 777, 999, 329, 249, 249, 249, 249,
                                    249, 721, 249, 249, 249, 277, 249, 249, 277, 499, 721, 555, 249, 249, 249, 249 ],
       'Times-BoldItalic'      => [ 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249,
                                    249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 388, 554, 499, 499, 832, 777, 332,
                                    332, 332, 499, 569, 249, 332, 249, 277, 499, 499, 499, 499, 499, 499, 499, 499, 499, 499, 332, 332,
                                    569, 569, 569, 499, 831, 666, 666, 666, 721, 666, 666, 721, 777, 388, 499, 666, 610, 888, 721, 721,
                                    610, 721, 666, 555, 610, 721, 666, 888, 666, 610, 610, 332, 277, 332, 569, 499, 332, 499, 499, 443,
                                    499, 443, 332, 499, 555, 277, 277, 499, 277, 777, 555, 499, 499, 499, 388, 388, 277, 555, 443, 666,
                                    499, 443, 388, 347, 219, 347, 569, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249,
                                    249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249,
                                    249, 388, 499, 499, 166, 499, 499, 499, 499, 277, 499, 499, 332, 332, 555, 555, 249, 499, 499, 499,
                                    249, 249, 499, 349, 332, 499, 499, 499, 999, 999, 249, 499, 249, 332, 332, 332, 332, 332, 332, 332,
                                    332, 249, 332, 332, 249, 332, 332, 332, 999, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249,
                                    249, 249, 249, 249, 249, 943, 249, 265, 249, 249, 249, 249, 610, 721, 943, 299, 249, 249, 249, 249,
                                    249, 721, 249, 249, 249, 277, 249, 249, 277, 499, 721, 499, 249, 249, 249, 249 ],
       'Times-Italic'          => [ 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249,
                                    249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 332, 419, 499, 499, 832, 777, 332,
                                    332, 332, 499, 674, 249, 332, 249, 277, 499, 499, 499, 499, 499, 499, 499, 499, 499, 499, 332, 332,
                                    674, 674, 674, 499, 919, 610, 610, 666, 721, 610, 610, 721, 721, 332, 443, 666, 555, 832, 666, 721,
                                    610, 721, 610, 499, 555, 721, 610, 832, 610, 555, 555, 388, 277, 388, 421, 499, 332, 499, 499, 443,
                                    499, 443, 277, 499, 499, 277, 277, 443, 277, 721, 499, 499, 499, 499, 388, 388, 277, 499, 443, 666,
                                    443, 443, 388, 399, 274, 399, 540, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249,
                                    249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249,
                                    249, 388, 499, 499, 166, 499, 499, 499, 499, 213, 555, 499, 332, 332, 499, 499, 249, 499, 499, 499,
                                    249, 249, 522, 349, 332, 555, 555, 499, 888, 999, 249, 499, 249, 332, 332, 332, 332, 332, 332, 332,
                                    332, 249, 332, 332, 249, 332, 332, 332, 888, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249,
                                    249, 249, 249, 249, 249, 888, 249, 275, 249, 249, 249, 249, 555, 721, 943, 309, 249, 249, 249, 249,
                                    249, 666, 249, 249, 249, 277, 249, 249, 277, 499, 666, 499, 249, 249, 249, 249 ],
       'Times-Roman'           => [ 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249,
                                    249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 332, 407, 499, 499, 832, 777, 332,
                                    332, 332, 499, 563, 249, 332, 249, 277, 499, 499, 499, 499, 499, 499, 499, 499, 499, 499, 277, 277,
                                    563, 563, 563, 443, 920, 721, 666, 666, 721, 610, 555, 721, 721, 332, 388, 721, 610, 888, 721, 721,
                                    555, 721, 666, 555, 610, 721, 721, 943, 721, 721, 610, 332, 277, 332, 468, 499, 332, 443, 499, 443,
                                    499, 443, 332, 499, 499, 277, 277, 499, 277, 777, 499, 499, 499, 499, 332, 388, 277, 499, 499, 721,
                                    499, 499, 443, 479, 199, 479, 540, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249,
                                    249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249,
                                    249, 332, 499, 499, 166, 499, 499, 499, 499, 179, 443, 499, 332, 332, 555, 555, 249, 499, 499, 499,
                                    249, 249, 452, 349, 332, 443, 443, 499, 999, 999, 249, 443, 249, 332, 332, 332, 332, 332, 332, 332,
                                    332, 249, 332, 332, 249, 332, 332, 332, 999, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249, 249,
                                    249, 249, 249, 249, 249, 888, 249, 275, 249, 249, 249, 249, 610, 721, 888, 309, 249, 249, 249, 249,
                                    249, 666, 249, 249, 249, 277, 249, 249, 277, 499, 721, 499, 249, 249, 249, 249 ],
    };
}

=head1 AUTHORS

Fabien Tassin

GIF and JPEG-support: Michael Gross (info@mdgrosse.net)

Maintenance since 2007: Markus Baertschi (markus@markus.org)

=head1 REPOSITORY

L<https://github.com/manwar/pdf-create>

=head1 COPYRIGHT

Copyright 1999-2001,Fabien Tassin.All rights reserved.It may be used and modified
freely, but I do  request that this copyright notice remain attached to the file.
You may modify this module as you wish,but if you redistribute a modified version,
please attach a note listing the modifications you have made.

Copyright 2007-, Markus Baertschi

Copyright 2010, Gary Lieberman

=head1 LICENSE

This is free software; you can redistribute it and / or modify it under the same
terms as Perl 5.6.0.

=cut

1;
