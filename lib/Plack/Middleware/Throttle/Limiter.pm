package Plack::Middleware::Throttle::Limiter;

use Moose;
extends 'Plack::Middleware::Throttle';

has _request_done => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
    clearer => '_clear_request_done'
);

sub allowed {
    my ( $self, $key ) = @_;

    $self->backend->incr($key);
    $self->request_done($key);
    ( $self->_request_done > $self->max ) ? return 0 : return 1;
}

sub request_done {
    my ( $self, $key ) = @_;
    $self->_request_done( $self->backend->get($key) || 0 );
}

sub add_headers {
    my ( $self, $res ) = @_;
    my $headers = $res->[1];
    Plack::Util::header_set( $headers, 'X-RateLimit-Limit', $self->max );
    Plack::Util::header_set( $headers, 'X-RateLimit-Remaining',
        ( $self->max - $self->_request_done ) );
    Plack::Util::header_set( $headers, 'X-RateLimit-Reset',
        $self->reset_time );
    $self->_clear_request_done;
    return $res;
}

1;
