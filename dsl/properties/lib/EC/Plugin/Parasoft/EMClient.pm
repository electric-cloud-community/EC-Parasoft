package EC::Plugin::Parasoft::EMClient;

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

sub delete_environment {
    my ($self, $id) = @_;

    my $request = HTTP::Request->new(DELETE => $self->_get_url("/v2/environments/$id"));

    my $ua = LWP::UserAgent->new;
    $self->_add_auth($request);
    $request->header('Content-Type' => 'application/json');
    $ua->env_proxy;
    if ($self->{proxy}) {
        $ua->proxy(['http', 'https'] => $self->{proxy});
    }
    my $response = $ua->request($request);
    unless($response->is_success) {
        die 'Request failed: ' . $response->code . "\n" . $response->content;
    }
    # This one returns xml
    return;
}

sub get_servers {
    my ($self, %param) = @_;

    my $request = HTTP::Request->new(GET => $self->_get_url('/v2/servers', %param));
    my $response = $self->_request($request);
    return $response->{servers} || [];
}

sub environment_copy_status {
    my ($self, $id) = @_;

    my $request = HTTP::Request->new(GET => $self->_get_url("/v2/environments/copy/$id"));
    my $response = $self->_request($request);
    return $response;
}

sub copy_environment {
    my ($self, %param) = @_;

    my $payload = encode_json(\%param);
    my $request = HTTP::Request->new(POST => $self->_get_url('/v2/environments/copy'));
    $request->content($payload);
    my $response = $self->_request($request);
    return $response;
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
    return $response;
}


sub get_jobs {
    my ($self, %params) = @_;

    my $request = HTTP::Request->new(GET => $self->_get_url("/v2/jobs", %params));
    $self->_request($request)->{jobs};
}


sub create_job_history {
    my ($self, $job_id, %params) = @_;
    die 'No job id' unless $job_id;
    my $request = HTTP::Request->new(POST => $self->_get_url("/v2/jobs/$job_id/histories"));
    $request->content('{}');
    $self->_request($request);
}




sub get_job_history {
    my ($self, $job_id, $history_id) = @_;

    unless($job_id && $history_id) {
        die 'One of the required parameters missing';
    }

    my $request = HTTP::Request->new(GET => $self->_get_url("/v2/jobs/$job_id/histories/$history_id"));
    $self->_request($request);
}

sub get_endpoints {
    my ($self, $env_id) = @_;

    die 'No environmentId' unless $env_id;
    my $request = HTTP::Request->new(GET => $self->_get_url("/v2/environments/$env_id/endpoints"));
    my $response = $self->_request($request);
    return $response;
}

sub _request {
    my ($self, $req) = @_;

    my $ua = LWP::UserAgent->new;
    $self->_add_auth($req);
    $req->header('Content-Type' => 'application/json');
    $req->header('Accept' => 'application/json');
    $ua->env_proxy;
    if ($self->{proxy}) {
        $ua->proxy(['http', 'https'] => $self->{proxy});
    }
    my $response = $ua->request($req);
    unless($response->is_success) {
        die 'Request failed: ' . $response->code . "\n" . $response->content;
    }
    my $retval;
    eval {
        $retval = decode_json($response->content);
        1;
    } or do {
        die 'Cannot decode json: ' . $response->content;
    };
    return $retval;
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
