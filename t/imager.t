use strict;
use warnings;
use Imager;

my $filename = 't/target_pic.png';

my $img = Imager->new;
$img->read(file=>$filename, type=>'png') or die "Cannot read: ", $img->errstr;


my $imgi = Imager->new;
my $new = $imgi->combine(src => [ $img, $img, $img ]);

# $new->write(file => "foo.png") or die "Cannot write: ",$img->errstr;
