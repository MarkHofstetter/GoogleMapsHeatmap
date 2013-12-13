#!/usr/local/bin/perl

use Test::Most;
use CHI;
use Geo::Heatmap;
use Data::Dumper;
use Storable;


my $dummy_cache = CHI->new(driver => 'Null');

my $p = "tile=276+177+9";

my ($tile) = ($p =~ /tile=(.+)/);
$tile =~ s/\+/ /g;
  
my $ghm = Geo::Heatmap->new();
## $ghm->debug(1);
$ghm->palette('www/palette.store');
$ghm->cache($dummy_cache);
$ghm->return_points( \&get_points_from_storable );  

$ghm->zoom_scale( {
  1 => 298983,
  2 => 177127,
  3 => 104949,
  4 => 90185,
  5 => 70338,
  6 => 37742,
  7 => 28157,
  8 => 12541,
  9 => 3662,
  10 => 1275,
  11 => 417,
  12 => 130,
  13 => 41,
  14 => 18,
  15 => 10,
  16 => 6,
  17 => 2,
  18 => 0,
} );

## my $image = $ghm->tile($tile);
## ok( length($image) > 80000, 'blurred image created and has correct size');

&{$ghm->return_points};

##open FH, '>pic_fewer_point.png';
##binmode(FH);
##print FH $image;
##close FH;

done_testing();


sub get_points_from_storable {
  my $r = shift;
  my $points = Storable::retrieve( 't/test-tile-coord-point.store');
  printf "%s\n", ref $points;
  print Dumper  $points;
  return $points->{sprintf ("%s_%s_%s_%s", $r->{LATN}, $r->{LNGW}, $r->{LATS}, $r->{LNGE})};
}

