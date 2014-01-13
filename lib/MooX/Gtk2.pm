package MooX::Gtk2;

use warnings;
use strict;

use Moo::Role;

use Scalar::Util ();

with "MooX::MethodAttributes::Role";

sub BUILD { }

after BUILD => sub {
    my ($self) = @_;
    my $class = Scalar::Util::blessed($self);

    my $signals = MooX::MethodAttributes
        ->methods_with_attr($class, "Signal");
    for my $method (keys %$signals) {
        for (@{$$signals{$method}}) {
            $_ //= "";
            my ($att, $sig) = /(?:(\w+)::)?(\w*)/ or next;
            $att ||= "widget";
            unless ($sig) {
                $sig = $method;
                $sig =~ s/^_//;
                $sig =~ s/_/-/g;
            }
            $self->$att->signal_connect($sig,
                sub { $self->$method(@_) });
        }
    }
};

1;
