package EC::Plugin::Parasoft::Client;

use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Request;
use URI;
use Data::Dumper;
use JSON;

sub new {
    my ($class, %param) = @_;

    my $self = { %param };

    $self->{endpoint} || die 'No endpoint for parasoft client';
    $self->{username} || die 'No username for parasoft client';
    $self->{password} || die 'No password for parasoft client';

    return bless $self, $class;
}


sub get_systems {
    my ($self, %param) = @_;

    my $request = HTTP::Request->new(GET => $self->_get_url('/v2/systems', %param));
    my $response = $self->_request($request);
    return $response->{systems} || [];
}

sub get_environments {
    my ($self, %param) = @_;

    my $request = HTTP::Request->new(GET => $self->_get_url('/v2/environments', %param));
    my $response = $self->_request($request);
    return $response->{environments} || [];
}

sub get_environment_instances {
    my ($self, $env_id, %param) = @_;

    die 'No environmentId' unless $env_id;
    my $request = HTTP::Request->new(GET => $self->_get_url("/v2/environments/$env_id/instances", %param));
    my $response = $self->_request($request);
    return $response->{instances} || [];
}

sub provision_environment {
    my ($self, $environment_id, $instance_id, %params) = @_;

    die 'No environmentId' unless $environment_id;
    die 'No instanceId' unless $instance_id;

    my $request = HTTP::Request->new(POST => $self->_get_url('/v2/provisions'));
    my $body = {
        environmentId => $environment_id,
        instanceId => $instance_id,
        %params,
    };

    my $payload = encode_json($body);
    $request->content($payload);

    my $response = $self->_request($request);
    return $response;
}

sub get_provision_event {
    my ($self, $event_id) = @_;

    my $request = HTTP::Request->new(GET => $self->_get_url("/v2/provisions/$event_id"));
    my $response = $self->_request($request);
}

sub _request {
    my ($self, $req) = @_;

    my $ua = LWP::UserAgent->new;
    $self->_add_auth($req);
    $req->header('Content-Type' => 'application/json');
    $ua->env_proxy;
    if ($self->{proxy}) {
        $ua->proxy(['http', 'https'] => $self->{proxy});
    }
    my $response = $ua->request($req);
    print Dumper $response;
    unless($response->is_success) {
        die 'Request failed: ' . $response->code . "\n" . $response->content;
    }
    return decode_json($response->content);
}

sub _get_url {
    my ($self, $api, %query) = @_;

    if ($api !~ /^\//) {
        $api = '/' . $api;
    }
    my $uri = URI->new($self->{endpoint} . $api);
    $uri->query_form(%query);
    return $uri;
}

sub _add_auth {
    my ($self, $req) = @_;
    $req->authorization_basic($self->{username}, $self->{password});
}

1;
