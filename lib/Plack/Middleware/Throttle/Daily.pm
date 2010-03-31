package Plack::Middleware::Throttle::Daily;

use Moose;
extends 'Plack::Middleware::Throttle::Limiter';

sub cache_key {
    my ( $self, $env ) = @_;
    $self->client_identifier($env) . "_"
        . DateTime->now->strftime("%Y-%m-%d");
}

sub reset_time {
    my $dt = DateTime->now;
    (24 * 3600) - (( 60 * $dt->minute ) + $dt->second);
}

1;
