package EC::Plugin::Parasoft::EM;

use strict;
use warnings;
use EC::Plugin::Parasoft::EMClient;
use EC::Plugin::Core;


use constant {
    WAITING => 'waiting',
    RUNNING => 'runinng',
    SUCCESS => 'success',
    CANCELLED => 'cancelled',
    ERROR => 'error',
};


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

sub em_client {
    my ($self) = @_;

    unless($self->{em_client}) {
        # TODO separate key
        $self->{em_client} = EC::Plugin::Parasoft::EMClient->new(
            endpoint => $self->{endpoint},
            username => $self->{userName},
            password => $self->{password},
            proxy    => $self->{proxy},
        );
    }
    return $self->{em_client};
}

sub provision_environment {
    my ($self, $params) = @_;

    my $system = $self->get_system_by_name($params->{systemName});
    unless($system) {
        die "Cannot find system $params->{systemName}";
    }

    my $system_id = $system->{id};
    $self->logger->trace("System id: $system_id");
    my $environment = $self->get_environment_by_name($system_id, $params->{environmentName});
    unless($environment) {
        die "Cannot find an environment with name $params->{environmentName} within system $params->{systemName}";
    }

    my $environment_id = $environment->{id};
    $self->logger->trace("Environment id: $environment_id");

    my $instance = $self->get_environment_instance_by_name($environment_id, $params->{environmentInstanceName});
    unless($instance) {
        die "Cannot find environment instance $params->{environmentInstanceName}";
    }
    my $instance_id = $instance->{id};

    my $provision_response = $self->em_client->provision_environment(
        $environment_id,
        $instance_id,
        abortOnFailure => 'true',
    );
    $self->logger->trace('Provision response', $provision_response);

    my $event_id = $provision_response->{eventId};
    my $event = $self->em_client->get_provision_event($event_id);
    $self->logger->trace('Event', $event);

    my $tries_count = 0;
    my $max_tries = 10;

    while($event->{status} eq 'waiting' || $event->{status} eq 'running') {
        sleep 1;
        $event = $self->em_client->get_provision_event($event_id);
        $tries_count ++;
        if ($tries_count > $max_tries) {
            die "Tries count exceeded: eventId $event_id";
        }
        $self->logger->trace($event);
        for my $step (@{$event->{steps}}) {
            if ($step->{result} ne WAITING || $step->{result} ne RUNNING) {
                $self->logger->info("$step->{description} ($step->{name}) $step->{result}")
            }
        }
    }

    $self->logger->info("Event status: $event->{status}");
    if ($event->{status} ne 'success') {
        die "Provision failed, see event $event_id";
    }
}

sub execute_job {
    my ($self, $params) = @_;

    my $job = $self->get_job_by_name($params->{jobName});
    $self->logger->debug($job);
    unless($job) {
        die "No job found for name $params->{jobName}";
    }
    my $job_id = $job->{id};
    my $job_history = $self->em_client->create_job_history($job_id);
    $self->logger->debug($job_history);

    while($job_history->{status} =~ /waiting|running/i) {
        sleep 1;
        $job_history = $self->em_client->get_job_history($job_id, $job_history->{id});
    }
    $self->logger->debug($job_history);

    return $job_history;
}

sub delete_environment {
    my ($self, $params) = @_;

    my $system = $self->get_system_by_name($params->{systemName});
    unless($system) {
        die "Cannot find system $params->{systemName}";
    }

    my $system_id = $system->{id};
    $self->logger->trace("System id: $system_id");
    my $environment = $self->get_environment_by_name($system_id, $params->{environmentName});
    unless($environment) {
        my $message = "Cannot find an environment with name $params->{environmentName} within system $params->{systemName}";
        if ($params->{strictMode}) {
            die $message;
        }
        else {
            $self->logger->warning($message);
            return {does_not_exist => 1};
        }
    }
    my $environment_id = $environment->{id};
    $self->em_client->delete_environment($environment_id);
    return {deleted => 1};
}

sub copy_environment {
    my ($self, $params) = @_;

    my $server_name = $params->{copyEnvServerName};

    my $system = $self->get_system_by_name($params->{systemName});
    unless($system) {
        die "Cannot find system $params->{systemName}";
    }

    my $system_id = $system->{id};
    $self->logger->trace("System id: $system_id");
    my $environment = $self->get_environment_by_name($system_id, $params->{environmentName});
    unless($environment) {
        die "Cannot find an environment with name $params->{environmentName} within system $params->{systemName}";
    }

    my $environment_id = $environment->{id};

    my $server = $self->get_server_by_name($server_name);
    unless($server) {
        die "Cannot find server $server_name";
    }

    my $server_id = $server->{id};
    my $new_name = $params->{environmentCopyName} || $self->generate_unique_env_name($system_id, $params->{environmentName});

    my $copy_result = $self->em_client->copy_environment(
        originalEnvId => $environment_id,
        server_id => $server_id,
        copyDataRepo => \0,
        newEnvironmentName => $new_name,
    );

    $self->logger->debug($copy_result);

    my $status_id = $copy_result->{id};
    my $copy_status = $self->em_client->environment_copy_status($status_id);
    while($copy_status->{status} =~ /copying/i) {
        sleep 1;
        $copy_status = $self->em_client->environment_copy_status($status_id);
    }

    if ($copy_status->{status} !~ /complete/i ) {
        die "Copy failed: $copy_status->{message}";
    }

    $self->logger->debug($copy_status);
    return {status => $copy_status, name => $new_name};
}


sub get_server_by_name {
    my ($self, $server_name) = @_;

    my $servers = $self->em_client->get_servers(name => $server_name);
    $self->logger->debug('Servers', $servers);
    my ($server) = grep { $_->{name} =~ /^$server_name/i } @$servers;
    return $server;
}

sub generate_unique_env_name {
    my ($self, $system_id, $current_name) = @_;

    my $new_name = "$current_name (Copy)";
    my $index = 1;
    while ($self->get_environment_by_name($system_id, $new_name)) {
        $new_name = "$current_name (Copy $index)";
        $index ++;
    }
    return $new_name;
}

sub get_system_by_name {
    my ($self, $name) = @_;

    unless($self->{systems}->{$name}) {
        my $systems = $self->em_client->get_systems(name => $name);
        $self->logger->debug('Systems', $systems);
        $name = quotemeta $name;
        my ($system) = grep {$_->{name} =~ m/^$name$/i} @$systems;
        $self->{systems}->{$name} = $system;
    }
    return $self->{systems}->{$name};
}

sub get_environment_by_name {
    my ($self, $system_id, $name) = @_;

    die 'No system id' unless $system_id;
    die 'No environment name' unless $name;

    unless($self->{environments}->{$name}) {
        my $environments = $self->em_client->get_environments(
            name => $name
        );
        $self->logger->trace('Environment', $environments);
        return unless @$environments;
        @$environments = grep { $_->{systemId} == $system_id && $_->{name} =~ m/^\Q$name\E$/i } @$environments;
        if (scalar @$environments > 1) {
            die "More than one environment found for name $name";
        }
        $self->{environments}->{$name} = $environments->[0];
    }
    return $self->{environments}->{$name};
}

sub get_environment_instance_by_name {
    my ($self, $environment_id, $name) = @_;

    my $instances = $self->em_client->get_environment_instances(
        $environment_id,
        name => $name
    );
    $self->logger->trace('Instances', $instances);
    return unless @$instances;
    $name = quotemeta $name;
    # TODO multiple instances for one name
    my ($instance) = grep { $_->{name} =~ m/^$name$/i } @$instances;
    return $instance;
}


sub get_job_by_name {
    my ($self, $job_name) = @_;

    my $jobs = $self->em_client->get_jobs(name => $job_name);
    my ($job) = grep { $_->{name} =~ m/^$job_name$/i } @$jobs;
    return $job;
}

sub get_endpoints {
    my ($self, $params) = @_;

    my $system = $self->get_system_by_name($params->{systemName});
    die "No system found by name $params->{systemName}" unless $system;

    my $system_id = $system->{id};
    my $environment = $self->get_environment_by_name($system_id, $params->{environmentName});
    die "No environment found by name $params->{environmentName}" unless $environment;
    my $environment_id = $environment->{id};

    my $endpoints = $self->em_client->get_endpoints($environment_id);
    return $endpoints;
}


sub get_em_site_address {
    my ($self) = @_;

    unless($self->{site_address}) {
        my $endpoint = URI->new($self->{endpoint});
        $endpoint->path('');
        $endpoint->query_form({});
        $self->{site_address} = $endpoint;
    }
    return $self->{site_address};
}


sub get_system_link {
    my ($self, $system) = @_;

    my $site_address = $self->get_em_site_address;
    $site_address->path('/em/ui/systems/' . $system->{id});
    return $site_address->as_string;
}


sub get_environment_link {
    my ($self, $environment) = @_;

    my $site_address = $self->get_em_site_address;
    $site_address->path("/em/environments/$environment->{id}");
    $site_address->query_form(edit => 'true');
    return $site_address->as_string;
}

1;
