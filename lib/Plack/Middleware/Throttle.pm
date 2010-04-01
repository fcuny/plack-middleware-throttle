package Plack::Middleware::Throttle;

use Moose;
use Carp;
use Scalar::Util;
use DateTime;
use Plack::Util;

our $VERSION = '0.01';

extends 'Plack::Middleware';

has code => ( is => 'rw', isa => 'Int', lazy => 1, default => '503' );
has message =>
    ( is => 'rw', isa => 'Str', lazy => 1, default => 'Over rate limit' );
has backend => ( is => 'rw', isa => 'Object', required => 1 );
has key_prefix =>
    ( is => 'rw', isa => 'Str', lazy => 1, default => 'throttle' );
has max => ( is => 'rw', isa => 'Int', lazy => 1, default => 100 );
has white_list =>
    ( is => 'rw', isa => 'ArrayRef', predicate => 'has_white_list' );
has black_list =>
    ( is => 'rw', isa => 'ArrayRef', predicate => 'has_black_list' );

sub prepare_app {
    my $self = shift;
    $self->backend( $self->_create_backend( $self->backend ) );
}

sub _create_backend {
    my ( $self, $backend ) = @_;

    if ( defined !$backend ) {
        Plack::Util::load_class("Plack::Middleware::Throttle::Backend::Hash");
    }

    return $backend if defined $backend && Scalar::Util::blessed $backend;
    die "backend must be a cache object";
}

sub call {
    my ( $self, $env ) = @_;

    my $res     = $self->app->($env);
    my $key     = $self->cache_key($env);
    my $allowed = $self->allowed($key);

    if ( !$allowed ) {
        $self->over_rate_limit();
    }
    else {
        $self->response_cb(
            $res,
            sub {
                my $res = shift;
                $self->add_headers($res);
            }
        );
    }
}

sub allowed {
    return 1;
}

sub request_done {
    return 1;
}

sub is_white_listed {
    my ( $self, $env ) = @_;
    return 1 if !$self->has_white_list;
    my $ip = $env->{REMOTE_ADDR};
    if ( grep { $_ == $ip } @{ $self->white_list } ) {
        return 1;
    }
    return 0;
}

sub is_black_listed {
    my ( $self, $env ) = @_;
    return 0 if !$self->has_black_list;
    my $ip = $env->{REMOTE_ADDR};
    if ( grep { $_ == $ip } @{ $self->black_list } ) {
        return 1;
    }
    return 0;
}

sub over_rate_limit {
    my $self = shift;
    return [
        $self->code,
        [
            'Content-Type'      => 'text/plain',
            'X-RateLimit-Reset' => $self->reset_time
        ],
        [ $self->message ]
    ];
}

sub add_headers {
    my ( $self, $res ) = @_;
    my $headers = $res->[1];
    Plack::Util::header_set( $headers, 'X-RateLimit-Limit', $self->max );
    Plack::Util::header_set( $headers, 'X-RateLimit-Reset',
        $self->reset_time );
    return $res;
}

sub client_identifier {
    my ( $self, $env ) = @_;
    if ( $env->{REMOTE_USER} ) {
        return $self->key_prefix."_".$env->{REMOTE_USER};
    }
    else {
        return $self->key_prefix."_".$env->{REMOTE_ADDR};
    }
}

1;
__END__

=head1 NAME

Plack::Middleware::Throttle - A Plack Middleware for rate-limiting incoming HTTP requests.

=head1 SYNOPSIS

=head1 DESCRIPTION

Set a limit on how many requests per hour is allowed on your API. In of a authorized request, 3 headers are added:

=over 2

=item B<X-RateLimit-Limit>

How many requests are authorized by hours

=item B<X-RateLimit-Remaining>

How many remaining requests

=item B<X-RateLimit-Reset>

When will the counter be reseted (in epoch)

=back

=head2 VARIABLES

=over 4

=item B<backend>

Which backend to use. Currently only Hash and Redis are supported. If no
backend is specified, Hash is used by default. Backend must implement B<set>,
B<get> and B<incr>.

=item B<code>

HTTP code that will be returned when too many connections have been reached.

=item B<message>

HTTP message that will be returned when too many connections have been reached.

=back

=head1 AUTHOR

franck cuny E<lt>franck@lumberjaph.netE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
