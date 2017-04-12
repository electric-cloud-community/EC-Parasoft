package EC::Parasoft;

use strict;
use warnings;
use EC::Plugin::Parasoft::Client;

use base qw(EC::Plugin::Core);

use constant {
    WAITING => 'waiting',
    RUNNING => 'runinng',
    SUCCESS => 'success',
    CANCELLED => 'cancelled',
    ERROR => 'error',
};


sub after_init_hook {
    my ($self, %params) = @_;

    $self->{plugin_name} = '@PLUGIN-NAME@';
    $self->{plugin_key} = '@PLUGIN_KEY@';
    $self->{_credentials} = {};
    my $debug_level = 0;

    if ($self->{plugin_key}) {
        eval {
            $debug_level = $self->ec()->getProperty(
                "/plugins/$self->{plugin_key}/project/debugLevel"
            )->findvalue('//value')->string_value();
        };
    }
    if ($debug_level) {
        $self->debug_level($debug_level);
        $self->logger->debug('Debug enabled');
    }
    else {
        $self->debug_level(0);
    }
}

sub run_step {
    my ($self, $step) = @_;

    eval {
        $step->();
        1;
    } or do {
        my $error = $@;
        $error =~ s/\sat\s.+\sline\s\d+\.//;
        $self->bail_out($error);
    };
}

sub step_provision_environment {
    my ($self) = @_;

    my $step = sub {
        my $params = $self->get_params_as_hashref(qw/
            config
            systemName
            environmentName
            environmentInstanceName
        /);

        $self->logger->debug('Params are', $params);

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
            return $self->bail_out("Provision failed, see event $event_id");
        }
    };

    $self->run_step($step);
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

sub em_client {
    my ($self, $config_name) = @_;

    unless($self->{em_client}) {
        unless($config_name) {
            $config_name = $self->get_param('config');
        }
        my $plugin_project_name = '$[/myProject/name]';
        my $config = $self->get_config_values($plugin_project_name, $config_name);
        $self->{em_client} = EC::Plugin::Parasoft::Client->new(
            endpoint => $config->{endpoint},
            username => $config->{userName},
            password => $config->{password},
        );
    }
    return $self->{em_client};
}

1;
