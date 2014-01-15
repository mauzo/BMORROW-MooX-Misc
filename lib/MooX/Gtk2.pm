package MooX::Gtk2;

use warnings;
use strict;

use Moo::Role;

use Scalar::Util ();

with qw/ MooX::MethodAttributes::Role MooX::WeakClosure 
    MooX::NoGlobalDestruction /;

sub BUILD { }

my $map_attr = sub {
    my ($class, $attr, $default, $connect) = @_;

    my $methods = MooX::MethodAttributes
        ->methods_with_attr($class, $attr, "MooX::Gtk2");

    for my $method (keys %$methods) {
        for (@{$$methods{$method}}) {
            $_ //= "";
            my ($att, $name) = /(?:(\w+)::)?(\w*)/ or next;
            $att //= $default;
            unless ($name) {
                $name = $method;
                $name =~ s/^_//;
                $name =~ s/_/-/g;
            }
            $connect->($att, $name, $method);
        }
    }
};

after BUILD => sub {
    my ($self)  = @_;
    my $class   = Scalar::Util::blessed($self);

    $map_attr->($class, "Signal", "widget", sub {
        my ($att, $sig, $method) = @_;
        $self->$att->signal_connect($sig,
            $self->weak_method($method));
    });
    $map_attr->($class, "Action", "actions", sub {
        my ($att, $name, $method) = @_;
        my $act = $self->$att->get_action($name);
        $act->signal_connect("activate",
            $self->weak_method($method));
    });
};

1;
