use strict;
use warnings;

use Module::Build;

my $builder = Module::Build->new(
    module_name=>'ClassLoader',
    license=>'perl',
    dist_author=>'Frank Seitz <fs[at]fseitz.de>',
    dist_abstract=>'~',
    recursive_test_files=>1,
    build_requires=>{
        'Test::More'=>0,
    },
    add_to_cleanup=>[],
);

$builder->create_build_script();

# eof
