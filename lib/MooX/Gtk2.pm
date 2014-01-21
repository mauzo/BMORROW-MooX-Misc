package MooX::Gtk2;

use warnings;
use strict;

use Moo::Role;
use MooX::AccessorMaker     qw/apply_accessor_maker_roles/;
use MooX::CaptainHook       qw/on_application/;

use MooX::MethodAttributes
    provide => [qw/ Signal Action /];

use Carp                    ();
use Hash::Util::FieldHash   ();
use Scalar::Util            ();

use namespace::clean;

with qw/ 
    MooX::Role::ObjectPath
    MooX::WeakClosure 
    MooX::NoGlobalDestruction 
/;

on_application {
    my ($to, $from) = @{$_[0]};
    apply_accessor_maker_roles $to, "MooX::Gtk2::AccessorMaker";
};

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

package MooX::Gtk2::AccessorMaker;

use Moo::Role;

around generate_method => sub {
    my ($orig, $self, @args) = @_;
    my ($into, $name, $spec) = @args;

    my $pspec = $$spec{gtk_prop} or return $self->$orig(@args);
    my ($path, $prop) = $pspec =~ /^(.*)::([\w-]+)$/
        or Carp::croak("Bad property spec '$pspec'");

    $$spec{trigger} = 1;

    # this call will update $spec
    my $methods = $self->$orig(@args);

    my $reader  = $$spec{reader} // $$spec{accessor};
    my $writer  = $$spec{writer} // $$spec{accessor};

    $reader && $writer or Carp::croak("Attribute '$name' is not rw");

    s/^\+//, s/^_// for $name;

    my $trigger = "_trigger_$name";
    my $mod     = \&Class::Method::Modifiers::install_modifier;

    Hash::Util::FieldHash::fieldhash my %obj;

    $into->can($trigger)
        or $mod->($into, "fresh", $trigger, sub {});

    $mod->($into, "after", $trigger, sub {
        my ($self, $value) = @_;
        my $obj = $obj{$self} or return;

        $value eq $obj->get_property($prop) and return;
        $obj->set_property($prop, $value);
    });

    $mod->($into, "after", "BUILD", sub {
        my ($self) = @_;

        my $obj = $obj{$self} = $self->_resolve_object_path($path);
        Scalar::Util::weaken $obj{$self};

        $obj->signal_connect("notify::$prop", 
            $self->weak_closure(sub {
                my ($self) = @_;
                my $value = $obj{$self}->get_property($prop);
                $value eq $self->$reader and return;
                $self->$writer($value);
            }));
        $obj->set_property($prop, $self->$reader);
    });

    return $methods;
};

1;
