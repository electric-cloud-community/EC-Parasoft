package EC::Parasoft;

use strict;
use warnings;
use EC::Plugin::Parasoft::Core;

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

sub step_get_endpoints {
    my ($self) = @_;

    my $step = sub {
        my $params = $self->get_params_as_hashref(qw/config systemName environmentName propertyName/);
        my $endpoints = $self->parasoft_core->get_endpoints($params);
        $self->logger->debug('Endpoints', $endpoints);

        my $components = $endpoints->{components};
        my $retval = {};

        for my $comp (@$components) {
            my $comp_name = $comp->{componentName};
            my $endpoints = $comp->{endpoints};
            for my $endpoint (@$endpoints) {
                my ($url, $proxy, $type) = ($endpoint->{httpUrl}, $endpoint->{proxy}, $endpoint->{type});
                if ($proxy) {
                    $retval->{$comp_name}->{proxy} = {url => $url, type => $type};
                }
                else {
                    $retval->{$comp_name}->{real} = {url => $url, type => $type};
                }
            }
        }
        my $flat_map = _flatten_map($retval, $params->{propertyName});
        for my $key (sort keys %$flat_map) {
            $self->ec->setProperty($key, $flat_map->{$key});
            $self->logger->info("Saved property $flat_map->{$key} under $key");
        }
    };

    $self->run_step($step);
}


sub step_provision_environment {
    my ($self) = @_;

    my $step = sub {
        my $params = $self->get_params_as_hashref(qw/
            config
            systemName
            environmentName
            environmentInstanceName
            copyEnvironment
            environmentCopyName
            copyEnvServerName
        /);

        if ($params->{copyEnvironment}) {
            my $copy_env_result = $self->parasoft_core->copy_environment($params);
            my $env_name = $copy_env_result->{name};
            $params->{environmentName} = $env_name;
            $self->ec->setProperty('/myJob/parasoftEnvironmentName', $env_name);
        }

        $self->parasoft_core->provision_environment($params);
        $self->set_summary("Environment $params->{environmentName} has been provisioned with instance $params->{environmentInstanceName}");
    };

    $self->run_step($step);
}


sub step_delete_environment {
    my ($self) = @_;
}

sub parasoft_core {
    my ($self, $config_name) = @_;

    unless($self->{core}) {
        unless($config_name) {
            $config_name = $self->get_param('config');
        }
        my $plugin_project_name = '$[/myProject/name]';
        my $config = $self->get_config_values($plugin_project_name, $config_name);
        my $proxy;
        eval {
            $proxy = $self->ec->getProperty("/plugins/$self->{plugin_key}/project/httpProxy")->findvalue('//value')->string_value;
            $self->logger->debug("HTTP Proxy is set: $proxy");
        };
        $self->{core} = EC::Plugin::Parasoft::Core->new(
            endpoint => $config->{endpoint},
            userName => $config->{userName},
            password => $config->{password},
            proxy => $proxy,
            logger => $self->logger,
        );
    }
    return $self->{core};
}

sub _flatten_map {
    my ($map, $prefix) = @_;

    $prefix ||= '';
    my %retval = ();
    for my $key (keys %$map) {
        my $value = $map->{$key};
        if (ref $value eq 'ARRAY') {
            my $counter = 1;
            my %copy = map { my $key = ref $_ ? $counter ++ : $_; $key => $_ } @$value;
            $value = \%copy;
        }
        if (ref $value) {
            %retval = (%retval, %{_flatten_map($value, "$prefix/$key")});
        }
        else {
            $retval{"$prefix/$key"} = $value;
        }
    }
    return \%retval;
}

1;
