package EC::Plugin::Parasoft::TDMClient;

use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Request::Common;
use URI;
use Data::Dumper;
use JSON;
use File::Basename;


sub new {
    my ($class, %param) = @_;

    my $self = { %param };

    $self->{endpoint} || die 'No endpoint for parasoft client';
    $self->{username} || die 'No username for parasoft client';
    $self->{password} || die 'No password for parasoft client';

    return bless $self, $class;
}

sub get_servers {
    my ($self) = @_;

    my $request = HTTP::Request->new(GET => $self->get_url('/v1/servers'));
    my $response = $self->request($request);
    return $response->{servers};
}

sub get_repositories {
    my ($self, $server_id) = @_;

    my $request = HTTP::Request->new(GET => $self->get_url("/v1/servers/$server_id/repositories"));
    $self->request($request);
}

sub get_repository {
    my ($self, $server_id, $name) = @_;

    die 'No serverId' unless $server_id;
    die 'No repository name' unless $name;
    my $request = HTTP::Request->new(GET => $self->get_url("/v1/servers/$server_id/repositories/$name"));
    $self->request($request);
}

sub upload_export {
    my ($self, $server_id, $filename) = @_;

    my $export_name = 'Export upload ' . basename($filename);
    my $data = qq{<?xml version="1.0" encoding="UTF-8"?>
        <exportUploadRequest xmlns="http://www.parasoft.com/api/tdm/v1/exports/messages">
            <name>$export_name</name>
            <serverID>$server_id</serverID>
        </exportUploadRequest>
    };
    my $request =  POST $self->get_url("/v1/exports/upload"),
       Content_Type => 'form-data',
       Content      => [ data  => $data, file => [$filename]];

    $self->add_auth($request);
    $request->header('Accept', 'application/json');

    my $response = $self->ua->request($request);

    if ($response->is_success) {
        my $retval = decode_json($response->content);
        return $retval;
    }
    else {
        die 'Request failed: ' . $response->code . "\n" . $response->content;
    }
}

sub get_task {
    my ($self, $id) = @_;

    my $request = HTTP::Request->new(GET => $self->get_url("/v1/tasks/$id"));
    my $response = $self->request($request);
    return $response->{tasks}->[0];
}

sub get_exports {
    my ($self) = @_;

    my $request = HTTP::Request->new(GET => $self->get_url('/v1/exports'));
    my $response = $self->request($request);
}

sub get_url {
    my ($self, $api, %query) = @_;

    if ($api !~ /^\//) {
        $api = '/' . $api;
    }
    my $uri = URI->new($self->{endpoint} . $api);
    $uri->query_form(%query);
    return $uri;
}

sub import_repo {
    my ($self, $server_id, $repo_name, %param) = @_;

    my $request = HTTP::Request->new(POST => $self->get_url("/v1/servers/$server_id/repositories/$repo_name/import"));
    my $payload = encode_json(\%param);
    $request->content($payload);
    $self->request($request);
}

sub ua {
    my ($self) = @_;

    unless($self->{ua}) {
        $self->{ua} = LWP::UserAgent->new;
    }
    return $self->{ua};
}

sub add_auth {
    my ($self, $req) = @_;
    $req->authorization_basic($self->{username}, $self->{password});
}


sub update_dataset {
    my ($self, $server_id, $repo_name, $dsname, $ds_record_id, $payload) = @_;

    unless($server_id && $repo_name && $dsname && $ds_record_id && $payload) {
        die "One of the required parameters is missing";
    }
    my $request = HTTP::Request->new(PUT => $self->get_url("/v1/servers/$server_id/repositories/$repo_name/dataSets/$dsname/$ds_record_id"));
    $request->content($payload);
    $self->request($request);
}

# TODO duplicate
sub request {
    my ($self, $req) = @_;

    my $ua = LWP::UserAgent->new;
    $self->add_auth($req);
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


1;
