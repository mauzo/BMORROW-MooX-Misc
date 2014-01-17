package MooX::MethodAttributes::Use;

use warnings;
use strict;

use Moo::Role;
use Sub::Identify ();

my $Me  = "MooX::MethodAttributes";

sub MODIFY_CODE_ATTRIBUTES {
    my ($class, $ref, @attrs) = @_;
    my $method  = Sub::Identify::sub_name($ref);
    my $hints   = (caller 1)[10];

    my @parsed = 
        grep @$_, 
        map [/^ (\w+) (?: \((.*)\) )? $/x], 
        @attrs;
    my @mapped = $Me->map_attrs_for_scope($hints, @parsed);
    $Me->register_method_attrs($class, $method, @mapped);
    return;
}

1;
