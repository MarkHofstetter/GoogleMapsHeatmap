package GoogleHeatmap;
use Moose;

# generate a density map (aka heatmap) overlay layer for Google Maps

# debug - if set to a value larger than 0 the package emits various debugging information
has 'debug'         => (isa => 'Str', is => 'rw');
has 'cache'         => (isa => 'Object', is => 'rw');
has 'logfile'       => (isa => 'Str', is => 'rw');
has 'return_points' => (isa => 'CodeRef', is => 'rw'); 
has 'zoom_scale'    => (isa => 'HashRef', is => 'rw'); 
has 'palette'       => (isa => 'Str', is => 'rw');

__PACKAGE__->meta->make_immutable;

use USNaviguide_Google_Tiles;
use Image::Magick;
use Storable;

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
      # $image->Draw(fill=>rgb("$density->[$i][$j], 0, 0") , primitive=>'rectangle', points=>"$i,$j $bin,$bin");
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
    # $image->Draw(fill=>"rgb($rgb)" , primitive=>'circle', points=>"$xc,$yc $xlc,$ylc");
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
   ## $image->Set("pixel[$ix,$iy]"=>'red');
   ## $image->Set("pixel[$ix,$iy]"=>'green');
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

Geo::Maps::Heatmap::Google - generate a density map (aka heatmap) overlay layer for Google Maps

=head1 VERSION

version 0.5

=head1 REQUIRES

L<Storable>

L<CHI>

L<Image::Magick>

L<USNaviguide_Google_Tiles>

L<Moose>


=head1 METHODS

=head2 calc_hm_tile

 calc_hm_tile();

=head2 create_hm_tile

 create_hm_tile();

=head2 create_tile

 create_tile();


=head1 ATTRIBUTES

has 'debug'         => (isa => 'Str', is => 'rw');
has 'cache'         => (isa => 'Object', is => 'rw');
has 'logfile'       => (isa => 'Str', is => 'rw');
has 'return_points' => (isa => 'CodeRef', is => 'rw');
has 'zoom_scale'    => (isa => 'HashRef', is => 'rw');
has 'palette'       => (isa => 'Str', is => 'rw');

=head2 new

  my $ghm = CPAN::Uploader->new();

This method returns a new uploader.  You probably don't need to worry about
this method.

Valid arguments are the same as those to C<upload_file>.

=head2 read_config_file

  my $config = CPAN::Uploader->read_config_file( $filename );

This reads the config file and returns a hashref of its contents that can be
used as configuration for CPAN::Uploader.

If no filename is given, it looks for F<.pause> in the user's home directory
(from the env var C<HOME>, or the current directory if C<HOME> isn't set).

=head2 log

  $uploader->log($message);

This method logs the given string.  The default behavior is to print it to the
screen.  The message should not end in a newline, as one will be added as
needed.

=head2 log_debug

This method behaves like C<L</log>>, but only logs the message if the
CPAN::Uploader is in debug mode.

=head1 ORIGIN

This code is mostly derived from C<cpan-upload-http> by Brad Fitzpatrick, which
in turn was based on C<cpan-upload> by Neil Bowers.  I (I<rjbs>) didn't want to
have to use a C<system> call to run either of those, so I refactored the code
into this module.

=head1 AUTHOR

Mark Hofstetter <hofstettm@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Mark Hofstetter

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

=head1 REQUIRES

L<Storable> 

L<CHI> 

L<Image::Magick> 

L<USNaviguide_Google_Tiles> 

L<Moose> 


=head1 METHODS

=head2 calc_hm_tile

 calc_hm_tile();

=head2 create_hm_tile

 create_hm_tile();

=head2 create_tile

 create_tile();


=cut

