package ClassLoader;

# -----------------------------------------------------------------------------

=encoding utf8

=head1 NAME

ClassLoader - Load classes automatically

=head1 SYNOPSIS

    use ClassLoader;
    
    my $obj = My::Class->new; # loads My/Class.pm

=head1 DESCRIPTION

(I<This module is documented in German>)

=head2 Zweck

Müde, C<use>-Anweisungen für das Laden von Perl-Klassen zu schreiben?

Dieses Modul reduziert das Laden aller Klassen auf eine
einzige Anweisung:

    use ClassLoader;

Danach wird jede Klasse automatisch mit ihrem ersten
Methodenaufruf geladen. Dies geschieht bei I<jeder> Methode,
gleichgültig, ob Klassen- oder Objektmethode.

=head2 Vorteile

=over 2

=item *

Man muss keine C<use>-Aufrufe mehr schreiben

=item *

Es werden nur die Klassen geladen, die das Programm tatsächlich
benötigt

=item *

Die Startzeit des Programms verkürzt sich

=item *

Das Programm benötigt unter Umständen weniger Speicher, da keine
überflüssigen Module geladen werden

=back

=head2 Was ist ein Klassen-Modul?

Unter einem Klassen-Modul verstehen wir eine pm-Datei, die
gmäß Perl-Konventionen eine Klasse definiert, d.h. die

=over 4

=item 1

ein Package mit dem Namen der Klasse deklariert,

=item 2

unter dem Namen des Package gemäß den Perl-Konventionen im
Dateisystem abgelegt ist,

=item 3

ihre Basisklassen (sofern vorhanden) selbständig lädt.

=back

=head2 Beispiel

Eine Klasse My::Class wird in einer Datei mit dem Pfad My/Class.pm
definiert und irgendwo unter C<@INC> installiert. Sie hat den Inhalt:

    package My::Class;
    use base qw/<BASECLASSES>/;
    
    <METHODS>
    
    1;

Das Laden der Basisklassen-Module geschieht hier mittels
C<use base>. Es ist genauso möglich, die Basisklassen-Module per
C<use> zu laden und C<@ISA> zuzuweisen, was aber umständlicher ist.

Eine pm-Datei, die diesen Konventionen genügt, ist ein
Klassen-Modul und wird von ClassLoader automatisch beim ersten
Methodenzugriff geladen.

=head2 Wie funktioniert das?

ClassLoader installiert sich als Basisklasse von UNIVERSAL und
definiert eine Methode AUTOLOAD, bei der sämtliche
Methodenaufrufe ankommen, die vom Perl-Interpreter nicht aufgelöst
werden können. Die AUTOLOAD-Methode lädt das benötigte
Klassen-Modul und ruft die betreffende Methode auf. Existiert das
Klassen-Modul nicht oder enthält es die gerufene Methode nicht, wird
eine Exception ausgelöst.

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
Klasse läuft über diese AUTOLOAD-Methode. Alle folgenden
Methodenaufrufe der Klasse finden I<direkt> statt, also ohne
Overhead! Methodenaufrufe einer explizit geladenen Klasse laufen
von vornherein nicht über die AUTOLOAD-Methode.

=head2 Was passiert im Fehlerfall?

Schlägt das Laden des Moduls fehl oder existiert die Methode
nicht, wird eine Exception ausgelöst.

Damit der Ort des Fehlers einfach lokalisiert werden kann, enthält
der Exception-Text ausführliche Informationen über den Kontext des
Fehlers, einschließlich Stacktrace.

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
der Klasse angesprochen. Alle späteren Methoden-Aufrufe der Klasse
werden über die Klasse selbst aufgelöst. Wenn die Klasse eine
AUTOLOAD-Methode besitzt, funktioniert diese genau so wie ohne
ClassLoader.

=cut

# -----------------------------------------------------------------------------

use strict;
use warnings;
use utf8;

our $VERSION = 1.000060;

unshift @UNIVERSAL::ISA,'ClassLoader';

# -----------------------------------------------------------------------------

=head1 METHODS

=head2 AUTOLOAD() - Lade Klassen-Modul

    $this->AUTOLOAD;

Lade Klassen-Modul und führe den Methodenaufruf durch.
Die Argumente und der Returnwert entsprechen denen der gerufenen Methode.
Schlägt das Laden des Moduls fehl, löst die Methode eine Exception aus
(siehe oben).

Die AUTOLOAD-Methode implementiert die Funktionalität des
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
lautet als die Klasse heißt. Solche Module müssen explizit per
use geladen werden.

=item *

Sind mehrere Klassen in einer Moduldatei definiert, kann das
automatische Laden logischerweise nur über eine dieser Klassen
erfolgen. Am besten lädt man solche Module auch explizit.

=item *

Über Aufruf der Methode import() ist es nicht möglich, ein
Modul automatisch zu laden, da Perl bei Nichtexistenz von
import() AUTOLOAD() nicht aufruft, sondern den Aufruf
ignoriert. Man kann durch $class->import() also nicht
das Laden eines Klassen-Moduls auslösen.

=item *

Module, die nicht objektorientiert, sondern Funktionssammlungen
sind, werden von ClassLoader nicht behandelt. Diese müssen
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
