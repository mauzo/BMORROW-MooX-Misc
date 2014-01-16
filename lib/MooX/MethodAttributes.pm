package MooX::MethodAttributes;

use 5.010;
use warnings;
use strict;

use Carp;
use Module::Runtime qw/require_module/;
use Role::Tiny ();

my $Me = "MooX::MethodAttributes";

my %MAttrs;
my %CAttrs;

sub import {
    my ($self, %args) = @_;
    my $class = caller;

    Role::Tiny->apply_roles_to_package($class, "$Me\::Use");

    $args{strict} and $^H{"$Me/strict"} = 1;
    
    if (my $reg = $args{provide}) {
        $self->register_class_attributes($class, @$reg);
    }

    $self->import_mapped_attrs(%args);
}

sub register_class_attributes {
    my ($self, $class, @attrs) = @_;
    @{$CAttrs{$class}}{@attrs} = ();
}

sub attrs_for_class {
    my ($self, $class) = @_;
    keys %{$CAttrs{$class}};
}

sub require_attrs_for_class {
    my ($self, $class) = @_;

    my @atts = $self->attrs_for_class($class);

    unless (@atts) {
        require_module $class;
        @atts = $self->attrs_for_class($class)
            or croak "$class doesn't define any method attributes";
    }

    return @atts;
}

sub import_mapped_attrs {
    my ($self, %args) = @_;

    my $map     = $args{map} // {};
    my %apply   = %$map;
    my %skip    = reverse %apply;

    for my $use (@{$args{use}}) {
        for my $short ($self->require_attrs_for_class($use)) {
            my $long = "$use/$short";
            $$map{$short} || $skip{$long} and next;
            $apply{$short} and croak "Method attribute " .
                "'$long' conflicts with '$apply{$short}'";
            $apply{$short} = $long;
        }
    }

    $^H{"$Me/map/$_"} = $apply{$_} for keys %apply;
}

sub register_method_attribute {
    my ($self, $class, $method, $att, $arg) = @_;
    push @{$MAttrs{$class}{$method}}, [$att, $arg];
}

sub all_method_attrs {
    my ($self, $class) = @_;
    return $MAttrs{$class};
}

sub attrs_for_method {
    my ($self, $class, $method) = @_;
    return $MAttrs{$class}{$method};
}

sub methods_with_attr {
    my ($self, $class, $attr, $nsp) = @_;
    $nsp //= caller;

    my $match = qr!^(?:\Q$attr\E|\Q$nsp/$attr\E)$!;

    my $all = $MAttrs{$class};
    my %rv;
    for my $method (keys %$all) {
        my @attrs = grep $$_[0] =~ $match, @{$$all{$method}};
        @attrs and push @{$rv{$method}}, map $$_[1], @attrs;
    }
    return \%rv;
}

1;
