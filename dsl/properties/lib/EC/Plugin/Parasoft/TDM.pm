package EC::Plugin::Parasoft::TDM;

use strict;
use warnings;
use EC::Plugin::Parasoft::TDMClient;
use Data::Dumper;

sub new {
    my ($class, %param) = @_;

    my $self = { %param };
    return bless $self, $class;
}

sub logger {
    my ($self) = @_;
    $self->{logger} ||= EC::Plugin::Logger->new;
    return $self->{logger};
}

sub tdm_client {
    my ($self) = @_;

    unless($self->{tdm_client}) {
        # TODO separate key
        $self->{tdm_client} = EC::Plugin::Parasoft::TDMClient->new(
            endpoint => $self->{endpoint},
            username => $self->{userName},
            password => $self->{password},
            proxy    => $self->{proxy},
        );
    }
    return $self->{tdm_client};
}


sub import_repository {
    my ($self, $params) = @_;

    my $repository_name = $params->{repositoryName};
    my $export_file = $params->{repositoryExportFile};
    my $server_name = $params->{serverName};

    my $server = $self->get_server_by_name($server_name);
    unless($server) {
        die "No server for name $server_name found";
    }

    my $server_id = $server->{id};

    unless(-f $export_file) {
        die "File $export_file does not exists";
    }

    my $repository = $self->tdm_client->get_repository($server_id, $repository_name);
    unless($repository) {
        # TODO
        die;
    }

    my $upload_response = $self->tdm_client->upload_export($server_id, $export_file);
    my $export_id = $upload_response->{exports}->[0]->{id};


    my $import_response = $self->tdm_client->import_repo(
        $server_id, $repository_name,
        export => $export_id,
        name => "Importing $repository_name"
    );
    my $task_id = $import_response->{tasks}->[0]->{id};

    my $task_status = $self->tdm_client->get_task($task_id);
    my $timeout = 60;
    my $start_time = time;

    while($task_status->{status} =~ /INPROGRESS/i) {
        sleep 1;
        $task_status = $self->tdm_client->get_task($task_id);
        if (time > $start_time + $timeout) {
            die "Task wait time exceeded";
        }
    }

    print Dumper $task_status;

}


sub get_server_by_name {
    my ($self, $name) = @_;

    unless($self->{servers}->{$name}) {
        my $servers = $self->tdm_client->get_servers;
        my ($server) = grep { $_->{alias} eq $name } @$servers;
        $self->{servers}->{$name} = $server;
    }
    return $self->{servers}->{$name};
}

sub get_tdm_site_address {
    my ($self) = @_;

    unless($self->{site_address}) {
        my $endpoint = URI->new($self->{endpoint});
        $endpoint->path('');
        $endpoint->query_form({});
        $self->{site_address} = $endpoint;
    }
    return $self->{site_address};
}


sub get_link_to_repository {
    my ($self, $server, $repo_name) = @_;

    my $link = $self->get_tdm_site_address;
    $link->path("em/tdm/servers/$server->{id}/$repo_name");
    return $link->as_string;
}

1;
