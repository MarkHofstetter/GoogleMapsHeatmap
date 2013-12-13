#!/usr/local/bin/perl

use Test::Most;
use CHI;
use Geo::Heatmap;
use Data::Dumper;
use Storable;
use List::Util;

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

 0 => 692,
1 => 659,
10 => 121,
11 => 121,
2 => 313,
3 => 228,
4 => 163,
5 => 145,
6 => 133,
7 => 122,
8 => 121,
9 => 121,
  12 => 0,
  13 => 0,
  14 => 0,
  15 => 0,
  16 => 0,
  17 => 0,
  18 => 0,
} );

my $image = $ghm->tile($tile);
ok( length($image) > 80000, 'blurred image created and has correct size');

&{$ghm->return_points};

open FH, '>pic_fewer_point.png';
binmode(FH);
print FH $image;
close FH;

done_testing();


sub get_points_from_storable {
  my $r = shift;
  my $points = Storable::retrieve( 't/test-tile-coord-point.store');
  printf "%s\n", ref $points;
  my $fewer_points = {};
  foreach my $point (keys %$points) {
     my @list = List::Util::shuffle( @{$points->{$point}} );
     @list = splice(@list, 0, (scalar @list) * 0.05);
     printf "%s %s\n", $point, scalar @list;
     $fewer_points->{$point} = \@list;
  }
  return $fewer_points->{sprintf ("%s_%s_%s_%s", $r->{LATN}, $r->{LNGW}, $r->{LATS}, $r->{LNGE})};
}

