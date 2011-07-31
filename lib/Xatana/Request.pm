package Xantena::Request;
use strict;
use warnings;
use base qw/Plack::Request/;
use Encode ();
use Carp ();
use URI::QueryParam;
use Hash::MultiValue;

# ------------------------------------------------------------------------- 
# This object returns decoded parameter values by default

sub body_parameters {
    my ($self) = @_;
    $self->{'amon2.body_parameters'} ||= $self->_decode_parameters($self->SUPER::body_parameters());
}

sub query_parameters {
    my ($self) = @_;
    $self->{'amon2.query_parameters'} ||= $self->_decode_parameters($self->SUPER::query_parameters());
}

sub _decode_parameters {
    my ($self, $stuff) = @_;

    my $encoding = 'utf8';
    my @flatten = $stuff->flatten();
    my @decoded;
    while ( my ($k, $v) = splice @flatten, 0, 2 ) {
        push @decoded, Encode::decode($encoding, $k), Encode::decode($encoding, $v);
    }
    return Hash::MultiValue->new(@decoded);
}
sub parameters {
    my $self = shift;

    $self->env->{'amon2.request.merged'} ||= do {
        my $query = $self->query_parameters;
        my $body  = $self->body_parameters;
        Hash::MultiValue->new( $query->flatten, $body->flatten );
    };
}

# ------------------------------------------------------------------------- 
# raw parameter values are also available.

sub body_parameters_raw {
    shift->SUPER::body_parameters();
}
sub query_parameters_raw {
    shift->SUPER::query_parameters();
}
sub parameters_raw {
    my $self = shift;

    $self->env->{'plack.request.merged'} ||= do {
        my $query = $self->SUPER::query_parameters();
        my $body  = $self->SUPER::body_parameters();
        Hash::MultiValue->new( $query->flatten, $body->flatten );
    };
}
sub param_raw {
    my $self = shift;

    return keys %{ $self->parameters_raw } if @_ == 0;

    my $key = shift;
    return $self->parameters_raw->{$key} unless wantarray;
    return $self->parameters_raw->get_all($key);
}


# ------------------------------------------------------------------------- 
# uri_with funcition.  The code was taken from Catalyst::Request
sub uri_with {
    my( $self, $args, $behavior) = @_;

    Carp::carp( 'No arguments passed to uri_with()' ) unless $args;

    my $append = 0;
    if((ref($behavior) eq 'HASH') && defined($behavior->{mode}) && ($behavior->{mode} eq 'append')) {
        $append = 1;
    }

    my $params = do {
        foreach my $value ( values %$args ) {
            next unless defined $value;
            for ( ref $value eq 'ARRAY' ? @$value : $value ) {
                $_ = "$_";
                utf8::encode($_) if utf8::is_utf8($_);
            }
        }

        my %params = %{ $self->uri->query_form_hash };
        foreach my $key ( keys %{$args} ) {
            my $val = $args->{$key};
            if ( defined($val) ) {

                if ( $append && exists( $params{$key} ) ) {

                  # This little bit of heaven handles appending a new value onto
                  # an existing one regardless if the existing value is an array
                  # or not, and regardless if the new value is an array or not
                    $params{$key} = [
                        ref( $params{$key} ) eq 'ARRAY'
                        ? @{ $params{$key} }
                        : $params{$key},
                        ref($val) eq 'ARRAY' ? @{$val} : $val
                    ];

                }
                else {
                    $params{$key} = $val;
                }
            }
            else {

                # If the param wasn't defined then we delete it.
                delete( $params{$key} );
            }
        }
        \%params;
    };

    my $uri = $self->uri->clone;
    $uri->query_form($params);

    return $uri;
}

1;

