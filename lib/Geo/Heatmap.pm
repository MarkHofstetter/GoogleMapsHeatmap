package Geo::Heatmap;
use Moose;
use Geo::Heatmap::USNaviguide_Google_Tiles;
use Image::Magick;
use Storable;

has 'debug'         => (isa => 'Str', is => 'rw');
has 'cache'         => (isa => 'Object', is => 'rw');
has 'logfile'       => (isa => 'Str', is => 'rw');
has 'return_points' => (isa => 'CodeRef', is => 'rw'); 
has 'zoom_scale'    => (isa => 'HashRef', is => 'rw'); 
has 'palette'       => (isa => 'Str', is => 'rw');

__PACKAGE__->meta->make_immutable;

our $VERSION = '0.08';

sub tile {
  my ($self, $tile, $debug) = @_;
  $debug |= 0;

  my ($x, $y, $z) = split(/\s+/, $tile);

  my $e;
  my $image = Image::Magick->new(magick=>'png');
  my %ubblob;
  my $k = 0;
  my $stitch;
  my $wi;
  my $line;

  my $mca = sprintf("blur_%s_%s_%s", $x, $y, $z);
  my $ubblob = $self->cache->get($mca);
  return $ubblob if defined $ubblob;

  for (my $i = -1; $i <= 1; $i++) {
    my $li = Image::Magick->new();
    for (my $j = -1; $j <= 1; $j++) {
      $ubblob{$i}{$j} = $self->calc_hm_tile([$x+$j, $y+$i, $z], $debug);
      $li->BlobToImage($ubblob{$i}{$j});
    }
    $line = $li->Append(stack => 'false');
    push @$image, ($line);
  }
 
  $wi = $image->Append(stack => 'true');
  $wi->GaussianBlur(geometry=>'768x768', radius=>"6", sigma=>"4");
  $wi->Crop(geometry=>'255x255+256+256');
  if ($debug > 1) {
    print "Debugging stitch\n";
    $wi->Write($mca.".png");
  }
  
  $ubblob =  $wi->ImageToBlob();
  $self->cache->set($mca, $ubblob);
  return $ubblob;
}

sub calc_hm_tile {
  my ($self, $coord, $debug) = @_;

  my ($x, $y, $z) = @$coord;

  my $mca = sprintf("raw_%s_%s_%s", $x, $y, $z);
  my $ubblob = $self->cache->get($mca);
  return $ubblob if defined $ubblob;  
  my $zoom_scale = $self->zoom_scale;

  my $value = &Google_Tile_Factors($z, 0) ;
  my %r = Google_Tile_Calc($value, $y, $x);

  my $image = Image::Magick->new(magick=>'png');
  $image->Set(size=>'256x256');
  $image->ReadImage('xc:white');
  my $rp = $self->return_points();
  my $ps = &$rp(\%r);;
  my $palette = Storable::retrieve($self->palette);
  $palette->[-1] = [100, 100, 100];
  my @density;
  my $bin = 8;
  foreach my $p (@$ps) {
    my @d = Google_Coord_to_Pix($value, $p->[0], $p->[1]);
    my $ix = $d[1] - $r{PXW};
    my $iy = $d[0] - $r{PYN};
    $density[int($ix/$bin)][int($iy/$bin)] ++;
    printf "%s %s %s %s\n", $ix, $iy, $ix % $bin, $iy % $bin if $debug >5;
  }
  
  my $maxval = ($bin)**2;
  # $zoom_scale->{$z} |= 0;
  my $defscale = $zoom_scale->{$z} > 0 ? $zoom_scale->{$z} : $maxval;
  $defscale *= 1.1;
  my $scale = 500/log($defscale);
  my $max = 256/$bin - 1;
  my $dmax = 0;
  
  for (my $i = 0; $i <= $max; $i++) {
    for (my $j = 0; $j <= $max; $j++) {
      my $xc  = $i*$bin;
      my $yc  = $j*$bin;
      my $xlc = $xc+$bin;
      my $ylc = $yc+$bin;
      my $d = $density[$i][$j] ? $density[$i][$j] : 1;
      $dmax = $d > $dmax ? $d : $dmax;
      my $color_index = int(500-log($d)*$scale);
      $color_index = 5 if $color_index < 1;
      $color_index = -1 if $d < 2;
      my $color = $palette->[$color_index];
      my $rgb = sprintf "%s%%, %s%%, %s%%", $color->[0], $color->[1], $color->[2];
      $image->Draw(fill=>"rgb($rgb)" , primitive=>'rectangle', points=>"$xc,$yc $xlc,$ylc");
      printf "[%s][%s] %s %s\n", $i, $j, $d, $color_index if $debug > 0;
    }
  }
  
  if ($self->logfile) {
    open (LOG, ">>");
    printf LOG  "densitylog:  x y z pointcount: %s %s %s %s\n", $x, $y, $z, $dmax;
    close LOG;
  }
  
  ($ubblob) = $image->ImageToBlob();
  $self->cache->set($mca, $ubblob);
  return $ubblob;
}


sub create_tile {
  my ($tile) = @_;
  my ($x, $y, $z) = split(/\s+/, $tile);
  my $value      = &Google_Tile_Factors($z, 0) ;
  my %r = Google_Tile_Calc($value, $y, $x);

  my $image = Image::Magick->new(magick=>'png');
  $image->Set(size=>'256x256');
  $image->ReadImage('xc:white');
  my $ps = get_points(\%r);

  foreach my $p (@$ps) {
    my @d = Google_Coord_to_Pix($value, $p->[0], $p->[1]);
    my $ix = $d[1] - $r{PXW};
    my $iy = $d[0] - $r{PYN};
    $image->Set("pixel[$ix,$iy]"=>"rgb(0, 0, 89)");
  }

  my $nw = sprintf("%s %s", $r{LATN}, $r{LNGW});
  my $se = sprintf("%s %s", $r{LATS}, $r{LNGE});
  my ($blob) =  $image->ImageToBlob();
  return $blob;
}


1;


__END__

=pod

=head1 NAME

Geo::Heatmap - generate a density map (aka heatmap) overlay layer for Google Maps

=head1 VERSION

version 0.08

=head1 REQUIRES

L<Moose>
L<Storable>
L<CHI>
L<Image::Magick>

=head1 METHODS

=head2 tile

 tile();

  return the tile image in png format


=head1 ATTRIBUTES

debug
cache
logfile
return_points
zoom_scale
palette

=head2 USAGE

Create a Heatmap layer for GoogleMaps

    my $ghm = Geo::Heatmap->new();
    $ghm->palette('palette.store');
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

    $ghm->cache($cache);
    $ghm->return_points( \&get_points );
    my $image = $ghm->tile($tile);


You need a color palette (one is included) to encode values to colors, in Storable Format as 
an arrayref of arrayrefs eg

    [50] = [34, 45, 56]

which means that a normalized value of 50 would lead to an RGB color of 34% red , 45% blue, 
56% green.

=over 4

=item zoom_scale

The maximum number of points for a given google zoom scale. You would be able to extract 
to values from the denisity log or derive them from your data in some cunning way

=item cache

You need some caching for the tiles otherwise the map would be quite slow. Use a CHI object 
with the cache you like

=item return_points

A function reference which expects a single hashref as a parameter which defines two LAT/LONG 
points to get all data points within this box:

      $r->{LATN}, $r->{LNGW}), $r->{LATS}, $r->{LNGE}

The function has to return an arrayref of arrayrefs of the points within the box

=item tile

Returns the rendered image

=back

=head1 AUTHOR

Mark Hofstetter <hofstettm@cpan.org>

Thanks to 
brian d foy
Marcel Gruenauer

=head1 TODO

* change to GoogleMaps API v3
* put more magic in calculation of zoom scales
* make more things configurable
* add even more tests
* Rewrite to use Imager http://search.cpan.org/~addi/Imager-0.43/Imager.pm
* ...


=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Mark Hofstetter

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

