package EC::Plugin::Parasoft::Core;

use strict;
use warnings;
use EC::Plugin::Parasoft::Client;
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
        $self->{em_client} = EC::Plugin::Parasoft::Client->new(
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


sub get_system_by_name {
    my ($self, $name) = @_;

    my $systems = $self->em_client->get_systems(name => $name);
    $self->logger->debug('Systems', $systems);
    my ($system) = grep {$_->{name} =~ m/^$name$/i} @$systems;
    return $system;
}

sub get_environment_by_name {
    my ($self, $system_id, $name) = @_;

    my $environments = $self->em_client->get_environments(
        name => $name
    );
    $self->logger->trace('Environment', $environments);
    return unless @$environments;
    my ($environment) = grep { $_->{systemId} == $system_id && $_->{name} =~ m/^$name$/i } @$environments;
    return $environment;
}

sub get_environment_instance_by_name {
    my ($self, $environment_id, $name) = @_;

    my $instances = $self->em_client->get_environment_instances(
        $environment_id,
        name => $name
    );
    $self->logger->trace('Instances', $instances);
    return unless @$instances;

    my ($instance) = grep { $_->{name} =~ m/^$name$/i } @$instances;
    return $instance;
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


1;
