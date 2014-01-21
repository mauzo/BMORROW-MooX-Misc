package MooX::Gtk2;

use warnings;
use strict;

use Moo::Role;
use MooX::MethodAttributes
    provide => [qw/ Signal Action /];

use Carp            ();
use Scalar::Util    ();

use namespace::clean;

with qw/ 
    MooX::Role::ObjectPath
    MooX::WeakClosure 
    MooX::NoGlobalDestruction 
/;


sub BUILD { }

my $map_attr = sub {
    my ($self, $attr, $default, $connect) = @_;

    my $methods = MooX::MethodAttributes
        ->methods_with_attr($self, $attr);

    for my $method (keys %$methods) {
        for (@{$$methods{$method}}) {
            $_ //= "";
            my ($att, $name) = /^(?:(.*)::)?(\w*)$/ or next;
            $att //= $default;
            my $obj = $self->_resolve_object_path($att)
                or Carp::croak("Can't resolve '$att'");
            unless ($name) {
                $name = $method;
                $name =~ s/^_//;
                $name =~ s/_/-/g;
            }
            $connect->($obj, $name, $method);
        }
    }
};

after BUILD => sub {
    my ($self)  = @_;

    $self->$map_attr("Signal", "widget", sub {
        my ($att, $sig, $method) = @_;
        warn "SIGNAL [$self] [$att] [$sig] [$method]";
        $att->signal_connect($sig,
            $self->weak_method($method));
    });
    $self->$map_attr("Action", "actions", sub {
        my ($att, $name, $method) = @_;
        warn "ACTION [$self] [$att] [$name] [$method]";
        my $act = $att->get_action($name);
        $act->signal_connect("activate",
            $self->weak_method($method));
    });
};

1;
