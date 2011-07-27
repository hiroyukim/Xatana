package Xatana;
use strict;
use warnings;
our $VERSION = '0.01';
use base qw/Class::Accessor::Fast Class::Data::Inheritable/;
__PACKAGE__->mk_accessors(qw/req config router env stash/);

use Smart::Args;
use URI;
use Try::Tiny;
use Xatena::Request;
use Xatena::Router;
use Xatena::Config;
use Xatena::View::Factory;
use Xatena::Exception;

__PACKAGE__->mk_classdata($_) for qw/config_class request_class router_class view_factory_class/;

__PACKAGE__->config_class('Xatena::Config');
__PACKAGE__->request_class('Xatena::Request');
__PACKAGE__->router_class('Xatena::Router');
__PACKAGE__->view_factory_class('Xatena::View::Factory');

sub new {
    my $class = shift;
    my $env   = shift;

    my $self = bless {
        config => $class->config_class->new,
        req    => $class->request_class->new($env),
        router => $class->router_class->new,
        env    => $env,
        stash  => {},
    },$class;

    $self->_init();

    return $self;
}

sub _init {
    my $self = shift;

    if( my $router = $self->config->{router} ) {
        $self->router->connect(%{$_}) for @$router;
    }
    else {
        die 'RouterSettingNotFound';
    }
}

sub run {
    my $self = shift;

    my $router_results = $self->router->match($self->env);

    if( $router_results->is_not_found ) {
        return [404, [], ['not found']];
    }

    my $exception_res;
    try {
        $router_results->dispatch($self);
    }
    catch {
        my $err = shift;

        if ( ref $err && $err->isa("Xatena::Exception::HTTP") ) {
            $exception_res = $err->to_response;
        }
        else {
            die $err;
        }
    };

    if( $exception_res ) {
        return $exception_res;
    }

    my $content = $self->render(
        $router_results->template_path()
    );

    return [200,['Content-Type' => 'text/html'],[Encode::encode('utf8',$content)]];
}

sub model  {
    my ($self,$name) = @_;

    my $module = 'Xatena::Model::' . $name ;

    Class::Load::load_class($module);

    return $module->new;
}

sub render {
    my $self          = shift;
    my $template_path = shift;
    $self->view_factory_class->new()->render($self,$template_path);    
}

sub redirect {
    my $self     = shift;
    my $location = shift;
    my $router_resultsarams   = shift;
    
    my $uri = URI->new('http://' . $self->req->uri->host .$location);
    $uri->query_form(%{ $router_resultsarams || {} }, $uri->query_form);

    Xatena::Exception::HTTP::Redirect->throw(msg => $uri->as_string);
}


1;
__END__

=head1 NAME

Xatana -

=head1 SYNOPSIS

  use Xatana;

=head1 DESCRIPTION

Xatana is

=head1 AUTHOR

Hiroyuki Yamanaka E<lt>hiroyukimm at gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
