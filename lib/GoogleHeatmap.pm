package GoogleHeatmap;
use Moose;

has 'debug'         => (isa => 'Str', is => 'rw');
has 'cache'         => (isa => 'Object', is => 'rw');
has 'logfile'       => (isa => 'Str', is => 'rw');
has 'return_points' => (isa => 'CodeRef', is => 'rw'); 
has 'zoom_scale'    => (isa => 'HashRef', is => 'rw'); 
has 'palette'       => (isa => 'Str', is => 'rw');

__PACKAGE__->meta->make_immutable;

use USNaviguide_Google_Tiles;
use Image::Magick;
use CHI;
use Storable;

sub create_hm_tile {
  my ($self, $tile, $debug) = @_;
  $debug |= 0;

  my ($x, $y, $z) = split(/\s+/, $tile);

  ## ok to make blur work we need the tile + all 8 bordering tiles
  #  $image->GaussianBlur(geometry=>'255x255', radius=>"5", sigma=>"3");
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

