package Plack::Middleware::Throttle::Interval;

use Moose;
extends 'Plack::Middleware::Throttle';

has min => (is => 'rw', isa => 'Int', default => 0, lazy => 1);

sub allowed {
    my ($self, $key) = @_;

    my $t1 = time();
    my $t0 = $self->backend->get($key);
    $self->backend->set($key, $t1);

    if (!$t0 || ($t1 - $t0) > $self->min) {
        return 1;
    }else{
        return 0;
    }
}

sub cache_key {
    my ( $self, $env ) = @_;
    $self->client_identifier($env);
}

sub reset_time {
    time + 1;
}

1;
