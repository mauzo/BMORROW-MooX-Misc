package MooX::MethodAttributes::Role;

use warnings;
use strict;

use Moo::Role;
use Sub::Identify ();

my $remap = "MooX::MethodAttributes/remap";

sub MODIFY_CODE_ATTRIBUTES {
    my ($class, $ref, @attrs) = @_;
    my $method  = Sub::Identify::sub_name($ref);
    my $hints   = (caller 1)[10];

    for (@attrs) {
        my ($att, $arg) = /^(\w+)(?:\(([^)]*)\))?$/ or next;
        $$hints{"$remap/$att"} and $att = $$hints{"$remap/$att"};
        MooX::MethodAttributes->register_attribute(
            $class, $method, $att, $arg);
    }
    return;
}

1;
