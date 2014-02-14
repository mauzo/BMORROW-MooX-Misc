package MooX::MakerRole::IgnoreUndef;

use Moo::Role;

around _generate_simple_has => sub {
    my ($orig, $self, @args)    = @_;
    my ($me, $name, $spec)      = @args;

    $$spec{ignore_undef} or return $self->$orig(@args);
    qq{ defined $me\->{"\Q$name\E"} };
};

1;
