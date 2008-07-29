use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'TRD::Velocity',
    license             => 'perl',
    dist_author         => 'Takuya Ichikawa <trd.ichi@gmail.com>',
    dist_version_from   => 'lib/TRD/Velocity.pm',
    requires => {
        'Test::More' => 0,
        'version'    => 0,
    },
    add_to_cleanup      => [ 'TRD-Velocity-*' ],
);

$builder->create_build_script();
