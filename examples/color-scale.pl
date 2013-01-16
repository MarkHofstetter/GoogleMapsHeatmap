use strict;
use warnings;

use Image::Magick;
use Data::Dumper;
use Storable;

my $logo=Image::Magick->New();
$logo->Read('colors.png');

my @palette;

for (my $i = 0;$i <= 500; $i++) {
  my @pixels = $logo->GetPixel(x=>1,y=>$i); 
  @pixels = map { int($_*100) } @pixels;
  push @palette, \@pixels;
}
print Dumper \@palette;
Storable::nstore(\@palette, 'paletlte.store');
