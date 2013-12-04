#!/usr/bin/env perl

use strict;
use FCGI;
use DBI;
use CHI;
use FindBin qw/$Bin/;
use lib "$Bin/../lib";

use Geo::Heatmap;

##my $cache = CHI->new( driver  => 'Memcached::libmemcached',
##     servers    => [ "127.0.0.1:11211" ],
##     namespace  => 'crimemap',
##);

## my $cache = CHI->new( driver => 'File',
##         root_dir => '/tmp/crimemap'
##     );

my $cache = CHI->new( driver => 'Null',);

our $dbh = DBI->connect("dbi:Pg:dbname=kriminalfall", 'kf', 'kf', {AutoCommit => 0});

my $request = FCGI::Request();

while ($request->Accept() >= 0) {
  my $env = $request->GetEnvironment();
  my $p = $env->{'QUERY_STRING'};
  
  my ($tile) = ($p =~ /tile=(.+)/);
  $tile =~ s/\+/ /g;
  
  # package needs a CHI Object for caching 
  #               a Function Reference to get LatLOng within a Google Tile
  #               maximum number of points per zoom level
 
  my $ghm = Geo::Heatmap->new();
#  $ghm->logfile('/tmp/cm.log');
#  $ghm->debug(15);
  $ghm->palette('palette.store');
  $ghm->scale(100);
  my $zoom = 1000;
  $zoom = $zoom**0.5;
  my $step = $zoom / 17;
  my $zoom_scale = {};
#  for (my $i = 1; $i <= 18; $i++) {
#    $zoom_scale->{$i} = $zoom**2;
#    printf "%s %s\n", $i, $zoom;
#    $zoom -= $step;
#  }

  $ghm->zoom_scale( {
    1 => 10,
    2 => 10,
    3 => 10,
    4 => 10,
    5 => 10,
    6 => 10,
    7 => 10,
    8 => 10,
    9 => 10,
    10 => 10,
    11 => 10,
    12 => 8,
    13 => 4,
    14 => 4,
    15 => 4,
    16 => 4,
    17 => 2,
    18 => 0,
  } );
 
    
#  $ghm->zoom_scale( $zoom_scale ); 

  $ghm->cache($cache);
  $ghm->return_points( \&get_points );
  my $image = $ghm->tile($tile);
  
  my $length = length($image);
  
  print "Content-type: image/png\n";
  print "Content-length: $length \n\n";
  binmode STDOUT;
  print $image;
                                       
}

sub get_points {
  my $r = shift;

  my $sth = $dbh->prepare( qq/
  select ST_AsEWKT(coord) from 
    (select coalesce(s.geom, o.geom) coord
      from posts p join orte o on p.ort_id = o.id
      left join strassen s on p.strassen_id  = s.id
        where post_ort like 'web%') g 
        where coord &&
              ST_SetSRID(ST_MakeBox2D(ST_Point($r->{LATN}, $r->{LNGW}),
                                      ST_Point($r->{LATS}, $r->{LNGE})
                        ),4326)
              /);

  $sth->execute();

  my @p;
  while (my @r = $sth->fetchrow) {
    my ($x, $y) = ($r[0] =~/POINT\((.+?) (.+?)\)/);
    push (@p, [$x ,$y]);
  }
  $sth->finish;
  return \@p;
}

