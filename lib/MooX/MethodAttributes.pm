package MooX::MethodAttributes;

use warnings;
use strict;

use Role::Tiny  ();

my %Attrs;

sub import {
    Role::Tiny->apply_roles_to_package(scalar caller,
        "MooX::MethodAttributes::Role");
}

sub register_attribute {
    my ($self, $class, $method, $att, $arg) = @_;
    push @{$Attrs{$class}{$method}}, [$att, $arg];
}

sub all_method_attrs {
    my ($self, $class) = @_;
    return $Attrs{$class};
}

sub attrs_for_method {
    my ($self, $class, $method) = @_;
    return $Attrs{$class}{$method};
}

sub methods_with_attr {
    my ($self, $class, $attr) = @_;
    my $all = $Attrs{$class};
    my %rv;
    for my $method (keys %$all) {
        my @attrs = grep $$_[0] eq $attr, @{$$all{$method}};
        @attrs and push @{$rv{$method}}, map $$_[1], @attrs;
    }
    return \%rv;
}

1;
