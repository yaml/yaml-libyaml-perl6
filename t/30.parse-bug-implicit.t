use v6;

use Test;

use LibYAML;
use LibYAML::Parser;
use LibYAML::Loader::TestSuite;

my $DATA = $*PROGRAM;

my $loader = LibYAML::Loader::TestSuite.new;
my $parser = LibYAML::Parser.new(
    loader => $loader,
);

my $yaml1 = q:to/EOM/;
---
foo: bar
...
EOM

my $yaml2 = q:to/EOM/;
%YAML 1.1
---
foo: bar
...
EOM

my $yaml3 = q:to/EOM/;
%TAG !e! tag:example.com,2000:app/
---
foo: bar
...
EOM


my @yaml = ($yaml1, $yaml2, $yaml3);

plan @yaml.elems;

for 1 .. @yaml.elems -> $i {
    my $yaml = @yaml[ $i - 1 ];
    $loader.events = ();
    $parser.parse-string($yaml);

    my Str @events = $loader.events.Array;
    #dd @events;
    cmp-ok(@events[1], 'eq', '+DOC ---', "yaml$i - explicit document start");
    cmp-ok(@events[6], 'eq', '-DOC ...', "yaml$i - explicit document end");
}



done-testing;
