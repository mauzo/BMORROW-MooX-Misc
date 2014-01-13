package MooX::MethodAttributes::Role;

use warnings;
use strict;

use Moo::Role;
use Sub::Identify ();

sub MODIFY_CODE_ATTRIBUTES {
    my ($class, $ref, @attrs) = @_;
    my $method = Sub::Identify::sub_name($ref);
    for (@attrs) {
        my ($att, $arg) = /^(\w+)(?:\(([^)]*)\))?$/ or next;
        #warn "GOT [$att][$arg] FOR [$class]->[$method]";
        MooX::MethodAttributes->register_attribute(
            $class, $method, $att, $arg);
    }
    return;
}

1;
