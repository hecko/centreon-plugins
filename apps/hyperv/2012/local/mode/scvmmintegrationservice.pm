#
# Copyright 2017 Centreon (http://www.centreon.com/)
#
# Centreon is a full-fledged industry-strength solution that meets
# the needs in IT infrastructure and application monitoring for
# service performance.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

package apps::hyperv::2012::local::mode::scvmmintegrationservice;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::misc;
use centreon::common::powershell::hyperv::2012::scvmmintegrationservice;

my $instance_mode;

sub custom_status_threshold {
    my ($self, %options) = @_; 
    my $status = 'ok';
    my $message;
    
    eval {
        local $SIG{__WARN__} = sub { $message = $_[0]; };
        local $SIG{__DIE__} = sub { $message = $_[0]; };
        
        if (defined($instance_mode->{option_results}->{critical_status}) && $instance_mode->{option_results}->{critical_status} ne '' &&
            eval "$instance_mode->{option_results}->{critical_status}") {
            $status = 'critical';
        } elsif (defined($instance_mode->{option_results}->{warning_status}) && $instance_mode->{option_results}->{warning_status} ne '' &&
                 eval "$instance_mode->{option_results}->{warning_status}") {
            $status = 'warning';
        }
    };
    if (defined($message)) {
        $self->{output}->output_add(long_msg => 'filter status issue: ' . $message);
    }

    return $status;
}

sub custom_status_output {
    my ($self, %options) = @_;
    
    my $msg = 'VMAddition : ' . $self->{result_values}->{vmaddition};
    return $msg;
}

sub custom_status_calc {
    my ($self, %options) = @_;
    
    $self->{result_values}->{vm} = $options{new_datas}->{$self->{instance} . '_vm'};
    $self->{result_values}->{status} = $options{new_datas}->{$self->{instance} . '_status'};
    $self->{result_values}->{vmaddition} = $options{new_datas}->{$self->{instance} . '_vmaddition'};
    return 0;
}

sub set_counters {
    my ($self, %options) = @_;
    
    $self->{maps_counters_type} = [
        { name => 'vm', type => 1, cb_prefix_output => 'prefix_vm_output', message_multiple => 'All integration services are ok' },
    ];
    $self->{maps_counters}->{vm} = [
        { label => 'snapshot', set => {
                key_values => [ { name => 'vm' }, { name => 'status' }, { name => 'vmaddition' } ],
                closure_custom_calc => $self->can('custom_status_calc'),
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => $self->can('custom_status_threshold'),
            }
        },
    ];
}

sub prefix_vm_output {
    my ($self, %options) = @_;
    
    return "VM '" . $options{instance_value}->{vm} . "' ";
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;
    
    $self->{version} = '1.0';
    $options{options}->add_options(arguments =>
                                {
                                  "scvmm-hostname:s"    => { name => 'scvmm_hostname' },
                                  "scvmm-username:s"    => { name => 'scvmm_username' },
                                  "scvmm-password:s"    => { name => 'scvmm_password' },
                                  "scvmm-port:s"        => { name => 'scvmm_port', default => 8100 },
                                  "timeout:s"           => { name => 'timeout', default => 50 },
                                  "command:s"           => { name => 'command', default => 'powershell.exe' },
                                  "command-path:s"      => { name => 'command_path' },
                                  "command-options:s"   => { name => 'command_options', default => '-InputFormat none -NoLogo -EncodedCommand' },
                                  "no-ps"               => { name => 'no_ps' },
                                  "ps-exec-only"        => { name => 'ps_exec_only' },
                                  "filter-vm:s"             => { name => 'filter_vm' },
                                  "filter-description:s"    => { name => 'filter_description' },
                                  "filter-hostgroup:s"      => { name => 'filter_hostgroup' },
                                  "filter-status:s"         => { name => 'filter_status' },
                                  "warning-status:s"    => { name => 'warning_status', default => '' },
                                  "critical-status:s"   => { name => 'critical_status', default => '%{vmaddition} =~ /not detected/i' },
                                });
    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);
    
    foreach my $label (('scvmm_hostname', 'scvmm_username', 'scvmm_password', 'scvmm_port')) {
        if (!defined($self->{option_results}->{$label}) || $self->{option_results}->{$label} eq '') {
            my ($label_opt) = $label;
            $label_opt =~ tr/_/-/;
            $self->{output}->add_option_msg(short_msg => "Need to specify --" . $label_opt . " option.");
            $self->{output}->option_exit();
        }
    }    
    
    $instance_mode = $self;
    $self->change_macros();
}

sub change_macros {
    my ($self, %options) = @_;
    
    foreach (('warning_status', 'critical_status')) {
        if (defined($self->{option_results}->{$_})) {
            $self->{option_results}->{$_} =~ s/%\{(.*?)\}/\$self->{result_values}->{$1}/g;
        }
    }
}

sub manage_selection {
    my ($self, %options) = @_;
    
    my $ps = centreon::common::powershell::hyperv::2012::scvmmintegrationservice::get_powershell(
        scvmm_hostname => $self->{option_results}->{scvmm_hostname},
        scvmm_username => $self->{option_results}->{scvmm_username},
        scvmm_password => $self->{option_results}->{scvmm_password},
        scvmm_port => $self->{option_results}->{scvmm_port},
        no_ps => $self->{option_results}->{no_ps});
    
    $self->{option_results}->{command_options} .= " " . $ps;
    my ($stdout) = centreon::plugins::misc::execute(output => $self->{output},
                                                    options => $self->{option_results},
                                                    command => $self->{option_results}->{command},
                                                    command_path => $self->{option_results}->{command_path},
                                                    command_options => $self->{option_results}->{command_options});
    if (defined($self->{option_results}->{ps_exec_only})) {
        $self->{output}->output_add(severity => 'OK',
                                    short_msg => $stdout);
        $self->{output}->display(nolabel => 1, force_ignore_perfdata => 1, force_long_output => 1);
        $self->{output}->exit();
    }
    
    #[name= test1 ][description= Test Descr -  - pp -  - aa ][status= Running ][cloud=  ][hostgrouppath= All Hosts\CORP\test1 ]][VMAddition= 6.3.9600.16384 ]
    #[name= test2 ][description=  ][status= HostNotResponding ][cloud=  ][hostgrouppath= All Hosts\CORP\test2 ]][VMAddition= Not Detected ]
    #[name= test3 ][description=  ][status= HostNotResponding ][cloud=  ][hostgrouppath= All Hosts\CORP\test3 ]][VMAddition= Not Detected ]
    #[name= test4 ][description=  ][status= HostNotResponding ][cloud=  ][hostgrouppath= All Hosts\CORP\test4 ]][VMAddition= Not Detected ]
    $self->{vm} = {};
    
    my $id = 1;
    while ($stdout =~ /^\[name=\s*(.*?)\s*\]\[description=\s*(.*?)\s*\]\[status=\s*(.*?)\s*\]\[cloud=\s*(.*?)\s*\]\[hostgrouppath=\s*(.*?)\s*\]\[VMAddition=\s*(.*?)\s*\]/msig) {
        my %values = (vm => $1, description => $2, status => $3, cloud => $4, hostgroup => $5, vmaddition => $6);

        $values{hostgroup} =~ s/\\/\//g;
        my $filtered = 0;
        foreach (('name', 'description', 'status', 'hostgroup')) {
            if (defined($self->{option_results}->{'filter_' . $_}) && $self->{option_results}->{'filter_' . $_} ne '' &&
                $values{$_} !~ /$self->{option_results}->{'filter_' . $_}/i) {
                $self->{output}->output_add(long_msg => "skipping  '" . $values{$_} . "': no matching filter.", debug => 1);
                $filtered = 1;
                last;
            }
        }
        
        $self->{vm}->{$id} = { %values } if ($filtered == 0);
        $id++;
    }
}

1;

__END__

=head1 MODE

Check virtual machine integration services on SCVMM.

=over 8

=item B<--scvmm-hostname>

SCVMM hostname (Required).

=item B<--scvmm-username>

SCVMM username (Required).

=item B<--scvmm-password>

SCVMM password (Required).

=item B<--scvmm-port>

SCVMM port (Default: 8100).

=item B<--timeout>

Set timeout time for command execution (Default: 50 sec)

=item B<--no-ps>

Don't encode powershell. To be used with --command and 'type' command.

=item B<--command>

Command to get information (Default: 'powershell.exe').
Can be changed if you have output in a file. To be used with --no-ps option!!!

=item B<--command-path>

Command path (Default: none).

=item B<--command-options>

Command options (Default: '-InputFormat none -NoLogo -EncodedCommand').

=item B<--ps-exec-only>

Print powershell output.

=item B<--filter-status>

Filter virtual machine status (can be a regexp).

=item B<--filter-description>

Filter by description (can be a regexp).

=item B<--filter-vm>

Filter virtual machines (can be a regexp).

=item B<--filter-hostgroup>

Filter hostgroup (can be a regexp).

=item B<--warning-status>

Set warning threshold for status (Default: '').
Can used special variables like: %{vm}, %{vmaddition}, %{status}

=item B<--critical-status>

Set critical threshold for status (Default: '%{vmaddition} =~ /not detected/i').
Can used special variables like: %{vm}, %{vmaddition}, %{status}

=back

=cut