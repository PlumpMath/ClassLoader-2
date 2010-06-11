use strict;
use warnings;
use utf8;

use Test::More tests=>5;

use_ok 'ClassLoader';

use lib 't/ClassLoader';

eval { InexistentClass->new };
like $@,qr/CLASSLOADER-00001/,'Klassen-Modul existiert nicht';

my $obj = MyClass1->new;
is ref($obj),'MyClass1','Klassen-Modul erfolgreich geladen';

eval { MyClass1->xxx };
like $@,qr/CLASSLOADER-00002/,'Methode fehlt in zuvor geladener Klasse';

eval { MyClass2->xxx };
like $@,qr/CLASSLOADER-00002/,'Methode fehlt in gerade geladener Klasse';

# eof
