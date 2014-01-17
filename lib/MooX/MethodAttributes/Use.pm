package MooX::MethodAttributes::Use;

use warnings;
use strict;

use Moo::Role;

my $Me  = "MooX::MethodAttributes";

sub MODIFY_CODE_ATTRIBUTES {
    my ($class, $method, @attrs) = @_;
    my $hints   = (caller 1)[10];

    my @parsed = 
        grep @$_, 
        map [/^ (\w+) (?: \((.*)\) )? $/x], 
        @attrs;
    my @mapped = $Me->map_attrs_for_scope($hints, @parsed);
    $Me->register_method_attrs($method, @mapped);
    return;
}

1;
