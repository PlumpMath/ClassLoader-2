package ClassLoader;

# -----------------------------------------------------------------------------

=head1 NAME

ClassLoader - Load classes automatically

=head1 SYNOPSIS

    use ClassLoader;
    
    my $obj = My::Class->new; # loads My/Class.pm

=head1 DESCRIPTION

(I<This module is documented in German>)

=head2 Zweck

Muede, C<use>-Anweisungen fuer das Laden von Perl-Klassen zu schreiben?

Dieses Modul reduziert das Laden aller Klassen auf eine Anweisung:

    use ClassLoader;

Danach wird jede Klasse automatisch mit ihrem ersten
Methodenaufruf geladen. Dies geschieht bei I<jeder> Methode,
gleichgueltig, ob Klassen- oder Objektmethode.

=head2 Vorteile

=over 2

=item *

Man muss keine C<use>-Aufrufe mehr schreiben

=item *

Es werden nur die Klassen geladen, die das Programm tatsaechlich
benoetigt

=item *

Die Startzeit des Programms verkuerzt sich

=item *

Das Programm benoetigt unter Umstaenden weniger Speicher, da keine
ueberfluessigen Module geladen werden

=back

=head2 Was ist ein Klassen-Modul?

Unter einem Klassen-Modul verstehen wir eine pm-Datei, die
gmaess Perl-Konventionen eine Klasse definiert, d.h. die

=over 4

=item 1

ein Package mit dem Namen der Klasse deklariert,

=item 2

unter dem Namen des Package gemaess den Perl-Konventionen im
Dateisystem abgelegt ist,

=item 3

ihre Basisklassen (sofern vorhanden) selbstaendig laedt.

=back

=head2 Beispiel

Eine Klasse My::Class wird in einer Datei mit dem Pfad My/Class.pm
definiert und irgendwo unter C<@INC> installiert. Sie hat den Inhalt:

    package My::Class;
    use base qw/<BASECLASSES>/;
    
    <METHODS>
    
    1;

Das Laden der Basisklassen-Module geschieht hier mittels
C<use base>. Es ist genauso moeglich, die Basisklassen-Module per
C<use> zu laden und C<@ISA> zuzuweisen, was aber umstaendlicher ist.

Eine pm-Datei, die diesen Konventionen genuegt, ist ein
Klassen-Modul und wird von ClassLoader automatisch beim ersten
Methodenzugriff geladen.

=head2 Wie funktioniert das?

ClassLoader installiert sich als Basisklasse von UNIVERSAL und
definiert eine Methode AUTOLOAD, bei der saemtliche
Methodenaufrufe ankommen, die vom Perl-Interpreter nicht aufgeloest
werden koennen. Die AUTOLOAD-Methode laedt das benoetigte
Klassen-Modul und ruft die betreffende Methode auf. Existiert das
Klassen-Modul nicht oder enthaelt es die gerufene Methode nicht, wird
eine Exception ausgeloest.

Die AUTOLOAD-Methode, die ClassLoader definiert, ist recht einfach
(Fehlerbehandlung hier vereinfacht):

    sub AUTOLOAD {
        my $this = shift;
        # @_: Methodenargumente
    
        my ($class,$sub) = our $AUTOLOAD =~ /^(.*)::(\w+)$/;
        return if $sub !~ /[^A-Z]/;
    
        eval "use $class";
        if ($@) {
            die "Modul kann nicht geladen werden\n";
        }
    
        unless ($this->can($sub)) {
            die "Methode existiert nicht\n";
        }
    
        return $this->$sub(@_);
    }

Lediglich der erste Methodenaufruf einer (noch nicht geladenen)
Klasse laeuft ueber diese AUTOLOAD-Methode. Alle folgenden
Methodenaufrufe der Klasse finden I<direkt> statt, also ohne
Overhead! Methodenaufrufe einer explizit geladenen Klasse laufen
von vornherein nicht ueber die AUTOLOAD-Methode.

=head2 Was passiert im Fehlerfall?

Schlaegt das Laden des Moduls fehl oder existiert die Methode
nicht, wird eine Exception ausgeloest.

Damit der Ort des Fehlers einfach lokalisiert werden kann, enthaelt
der Exception-Text ausfuehrliche Informationen ueber den Kontext des
Fehlers, einschliesslich Stacktrace.

Aufbau des Exception-Texts:

    Exception:
        CLASSLOADER-<N>: <TEXT>
    Class:
        <CLASS>
    Method:
        <METHOD>()
    Error:
        <ERROR>
    Stack:
        <STACKTRACE>

=head2 Kann eine Klasse selbst eine AUTOLOAD-Methode haben?

Ja, denn die AUTOLOAD-Methode von ClassLoader wird I<vor> dem Laden
der Klasse angesprochen. Alle spaeteren Methoden-Aufrufe der Klasse
werden ueber die Klasse selbst aufgeloest. Wenn die Klasse eine
AUTOLOAD-Methode besitzt, funktioniert diese genau so wie ohne
ClassLoader.

=cut

# -----------------------------------------------------------------------------

use strict;
use warnings;
use utf8;

our $VERSION = 1.000059;

unshift @UNIVERSAL::ISA,'ClassLoader';

# -----------------------------------------------------------------------------

=head1 METHODS

=head2 AUTOLOAD() - Lade Klassen-Modul

    $this->AUTOLOAD;

Lade Klassen-Modul und fuehre den Methodenaufruf durch.
Die Argumente und der Returnwert entsprechen denen der gerufenen Methode.
Schlaegt das Laden des Moduls fehl, loest die Methode eine Exception aus
(siehe oben).

Die AUTOLOAD-Methode implementiert die Funktionalitaet des
Moduls. Sie wird nicht direkt, sondern vom Perl-Interpreter
gerufen, wenn eine Methode nicht gefunden wird.

=cut

# -----------------------------------------------------------------------------

my $die = sub {
    my ($class,$sub,$error,$msg) = @_;

    my @frames;
    my $i = 1; 
    while (my (undef,$file,$line,$sub) = caller $i++) {
        $file =~ s|.*/||;
        push @frames,[$file,$line,$sub];
    }

    $i = 0;
    my $stack = '';
    for my $frame (reverse @frames) {
        my ($file,$line,$sub) = @$frame;
        $sub .= "()" if $sub ne '(eval)';
        $stack .= sprintf "%s%s [%s:%s]\n",('  'x$i++),$sub,$file,$line;
    }
    chomp $stack;
    $stack .= " <== ERROR";
    $stack =~ s/^/    /gm;

    my $str = "Exception:\n    $msg\n";
    $str .= "Class:\n    $class\n";
    $str .= "Method:\n    $sub()\n";
    if ($error) {
        $str .= "Error:\n    $error\n";
    }
    $str .= "Stack:\n$stack\n";

    die $str;
};

sub AUTOLOAD {
    my $this = shift;
    # @_: Methodenargumente

    my ($class,$sub) = our $AUTOLOAD =~ /^(.*)::(\w+)$/;
    return if $sub !~ /[^A-Z]/;

    eval "use $class";
    if ($@) {
        $@ =~ s/ at .*//s;
        $die->($class,$sub,$@,
            q{CLASSLOADER-00001: Modul kann nicht geladen werden});
    }

    unless ($this->can($sub)) {
        $die->($class,$sub,undef,
            q{CLASSLOADER-00002: Methode existiert nicht});
    }

    return $this->$sub(@_);
}

# -----------------------------------------------------------------------------

=head1 CAVEATS

=over 2

=item *

Der Mechanismus funktioniert nicht, wenn der Modulpfad anders
lautet als die Klasse heisst. Solche Module muessen explizit per
use geladen werden.

=item *

Sind mehrere Klassen in einer Moduldatei definiert, kann das
automatische Laden logischerweise nur ueber eine dieser Klassen
erfolgen. Am besten laedt man solche Module auch explizit.

=item *

Ueber Aufruf der Methode import() ist es nicht moeglich, ein
Modul automatisch zu laden, da Perl bei Nichtexistenz von
import() AUTOLOAD() nicht aufruft, sondern den Aufruf
ignoriert. Man kann durch $class->import() also nicht
das Laden eines Klassen-Moduls ausloesen.

=item *

Module, die nicht objektorientiert, sondern Funktionssammlungen
sind, werden von ClassLoader nicht behandelt. Diese muessen
per use geladen werden.

=back

=head1 EXCEPTIONS

    CLASSLOADER-00001: Modul kann nicht geladen werden
    CLASSLOADER-00002: Methode existiert nicht

=head1 AUTHOR

Frank Seitz, http://www.fseitz.de/

=head1 COPYRIGHT

Copyright (C) Frank Seitz, 2008-2010

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;

# eof
