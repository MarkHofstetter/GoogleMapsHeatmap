use strict;
use warnings;
use ExtUtils::MakeMaker 6.58;
my $from = 'lib/Geo/Heatmap.pm';
WriteMakefile(
    ABSTRACT_FROM      => $from,
    "AUTHOR"           => 'Mark Hofstetter <cpan@trust-box.at>',
    "BUILD_REQUIRES"   => { 'Test::Most' => '0' },
    CONFIGURE_REQUIRES => { 'ExtUtils::MakeMaker' => '6.58' },
    EXE_FILES          => [],
    LICENSE            => 'perl',
    MIN_PERL_VERSION   => '5.12.0',
    NAME               => 'Geo-Heatmap',
    PREREQ_PM          => {
        'Moose'         => '2.0604',
        'Image::Magick' => '6.77',
        'CHI'           => '0.56',
    },
    VERSION_FROM => $from,
    test         => { TESTS => 't/*.t' }
);

