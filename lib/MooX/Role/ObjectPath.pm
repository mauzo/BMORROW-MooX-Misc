package MooX::Role::ObjectPath;

use Moo::Role;
use Carp ();
use Regexp::Common;

sub _resolve_object_path {
    my ($self, $path) = @_;

    $path .= ".";
    while ($path =~ s/
        ^ (\w+) 
        $RE{balanced}{-parens => "()"}?
        \.
    //x) {
        my ($meth, $arg) = ($1, $2);
        $arg and $arg =~ s/^\(//, $arg =~ s/\)$//;
        $self = $self->$meth($arg // ())
            or return;
    }

    $path and Carp::croak("Bad object path element '$path'");
    $self;
}

1;
