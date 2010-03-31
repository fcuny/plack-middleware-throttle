package Plack::Middleware::Throttle::Limiter;

use Moose;
extends 'Plack::Middleware::Throttle';

sub request_done {
    my ( $self, $env ) = @_;
    my $key = $self->cache_key($env);

    $self->backend->incr($key);

    my $request_done = $self->backend->get($key);

    if ( !$request_done ) {
        $self->backend->set( $key, 1 );
    }

    $request_done;
}

1;
