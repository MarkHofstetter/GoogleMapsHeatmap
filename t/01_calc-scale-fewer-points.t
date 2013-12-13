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
my ($x, $y, $zoomlevel) = split(/\ /, $tile);
  
my $ghm = Geo::Heatmap->new();
## $ghm->debug(1);
$ghm->palette('www/palette.store');
$ghm->cache($dummy_cache);
$ghm->bin(16);
$ghm->blur(8);

$ghm->return_points( \&get_points_from_storable );  

my $max = $ghm->max_points_per_tile_bin($x, $y, $zoomlevel);

# print "$x:$y:$zoomlevel:$max\n";
ok( $max > 50, 'finding max points per tile is works');

$ghm->scale(0.3);

$ghm->zoom_scale( {
  $zoomlevel => $max,
} );

my $image = $ghm->tile($tile);
ok( length($image) > 20000, 'blurred image created and has correct size');

&{$ghm->return_points};

##open FH, '>pic_fewer_point.png';
##binmode(FH);
##print FH $image;
##close FH;

done_testing();


sub get_points_from_storable {
  my $r = shift;
  my $points = Storable::retrieve( 't/test-tile-coord-point.store');
  my $fewer_points = {};
  foreach my $point (keys %$points) {
     my @list = List::Util::shuffle( @{$points->{$point}} );
     @list = splice(@list, 0, (scalar @list) * 0.05);
    # printf "%s %s\n", $point, scalar @list;
     $fewer_points->{$point} = \@list;
  }
  return $fewer_points->{sprintf ("%s_%s_%s_%s", $r->{LATN}, $r->{LNGW}, $r->{LATS}, $r->{LNGE})} if $r->{LATN};
}

