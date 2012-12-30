#!/usr/local/bin/perl

use strict;
use CHI;
use GoogleHeatmap;
use Data::Dumper;
use DBI;
use Storable;

our $dbh = DBI->connect("dbi:Pg:dbname=gisdb", 'gisdb', 'gisdb', {AutoCommit => 0});


my $cache = CHI->new( driver  => 'Memcached::libmemcached',
    servers => [ "127.0.0.1:11211" ],
);

our $points = {};

my $dummy_cache = CHI->new(driver => 'Null');

my $p = "tile=555+355+10";
$p = "tile=276+177+9";

my ($tile) = ($p =~ /tile=(.+)/);
$tile =~ s/\+/ /g;
  
my $ghm = GoogleHeatmap->new();
$ghm->debug(1);
$ghm->cache($dummy_cache);
$ghm->return_points( \&get_points );  

my $image = $ghm->create_hm_tile($tile);

open FH, '>pic.png';
binmode(FH);
print FH $image;
close FH;

Storable::nstore( $points, 'test-tile-coord-point.store');

sub get_points {
  my $r = shift;
  my ($latn, $lngw, $lats, $lnge) = ($r->{LATN}, $r->{LNGW}, $r->{LATS}, $r->{LNGE});

  my $sth = $dbh->prepare( qq(select ST_AsEWKT(geom) from geodata
                         where geom &&
              ST_SetSRID(ST_MakeBox2D(ST_Point($r->{LATN}, $r->{LNGW}),
                                      ST_Point($r->{LATS}, $r->{LNGE})
                        ),4326)) 
              );

  $sth->execute();
  
  my @p;
  while (my @r = $sth->fetchrow) {
    my ($x, $y) = ($r[0] =~/POINT\((.+?) (.+?)\)/);
    push (@p, [$x ,$y]);
  }
  $sth->finish;
  $points->{sprintf ("%s_%s_%s_%s", $r->{LATN}, $r->{LNGW}, $r->{LATS}, $r->{LNGE})} = \@p;
  return \@p;
}

  

__END__
select ST_AsEWKT(geom) from geodata where geom && ST_SetSRID(ST_MakeBox2D(ST_Point(48.2226, 16.34765),                     
ST_Point(48.16631, 16.4352)),4326);
           st_asewkt            
--------------------------------
 SRID=4326;POINT(48.213 16.375)
(1 row)


