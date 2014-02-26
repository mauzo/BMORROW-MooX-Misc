package MooX::Role::WeakClosure;

use warnings;
use strict;

use Moo::Role;
use Scalar::Util    ();

sub weak_closure {
    my ($self, $sub, $dtor) = @_;
    Scalar::Util::weaken($self);
    $dtor ||= $sub;
    my $cv;
    $cv = sub {
        $self
            ? $sub->($self, @_)
            : $dtor->($cv, @_);
    };
}

sub weak_method {
    my ($self, $method, $dtor, $args) = @_;
    Scalar::Util::weaken($self);
    $dtor ||= sub {};
    my $cv;
    $cv = sub { 
        $self ? $self->$method($args ? @$args : @_) 
            : $dtor->($cv, $args ? @$args : @_);
    };
}

1;
