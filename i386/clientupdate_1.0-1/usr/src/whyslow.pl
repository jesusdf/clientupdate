#!/usr/bin/perl
# Copy from https://github.com/orezpraw/scripts/blob/master/whyslow.pl
# Must be run with root permissions.
# Requires msr-tools to be installed.
# Requires msr module to be loaded.
use warnings;
no warnings 'portable';  # Support for 64-bit ints required
use strict;
$\ = $/;

use Getopt::Long;

my $ncpus = `rdmsr 0x19c -a` =~ tr/\n//;

my $clear = 0;
my $quiet = 0;   
GetOptions ('clear' => \$clear, 'quiet' => \$quiet);

sub rdmsr {
    my ($register, $cpu) = @_;
    $_ = `rdmsr $register --processor $cpu`;
    chomp;
    return hex($_);
}


sub bit {
    my ($number, $bit) = @_;
    return ($number >> $bit) & 0x1;
}

sub bitfield {
    my ($number, $top, $bottom) = @_;
    my $bits = $top-$bottom;
    my $mask = (2**($bits+1))-1;
    return ($number >> $bottom) & $mask;
}

sub misc {
    my $ia32_misc_enable = rdmsr('0x1a0', 0);
    print "Package automatic thermal control enabled" if bit($ia32_misc_enable, 3) and not $quiet;        
    print "Package intel speedstep enabled" if bit($ia32_misc_enable, 16) and not $quiet;
    print "Package turbo disabled" if bit($ia32_misc_enable, 38);
    my $temperature_target = rdmsr('0x1a2', 0);
    print "Package temp target: " . bitfield($temperature_target, 23, 16) . "C" unless $quiet;
    my $misc_pwr_mgmt = rdmsr('0x1aa', 0);
    print "Bias enabled " if bit($misc_pwr_mgmt, 1);
#     my $turbo_power_current_limit = rdmsr('0x1ac', 0);
#     print "Turbo power limit: " . bitfield($turbo_power_current_limit, 14, 0)/8 . "W";
#     print "Turbo power limit overriden" if bit($turbo_power_current_limit, 15);
#     print "Turbo current limit: " . bitfield($turbo_power_current_limit, 30, 16)/8 . "A";
#     print "Turbo current limit overriden" if bit($turbo_power_current_limit, 31);
    my $power_ctl = rdmsr('0x1fc', 0);
    print "C1E enabled" if bit($power_ctl, 1);
}

sub pstate {
    for (my $cpu = 0; $cpu < $ncpus; $cpu++) {
        my $ia32_perf_status = rdmsr('0x198', $cpu);
        print "CPU $cpu P-state: " . bitfield($ia32_perf_status, 15, 0) unless $quiet;

        my $ia32_perf_ctl = rdmsr('0x199', $cpu);
        print "CPU $cpu turbo disengaged" if bit($ia32_perf_ctl, 32);
        print "CPU $cpu P-state transition target: " . bitfield($ia32_perf_ctl, 15, 0) unless $quiet;

        my $ia32_energy_perf_bias = rdmsr('0x1b0', $cpu);
        print "CPU $cpu policy preference hint: " . bitfield($ia32_energy_perf_bias, 3, 0) unless $quiet;

    }
}

sub ia32_therm {
    for (my $cpu = 0; $cpu < $ncpus; $cpu++) {
        my $ia32_therm_status = rdmsr('0x19c', $cpu);

        print "CPU $cpu PROCHOT/TM active" if bit($ia32_therm_status, 0);
        print "CPU $cpu PROCHOT/TM logged" if bit($ia32_therm_status, 1);
        print "CPU $cpu External PROCHOT active" if bit($ia32_therm_status, 2);
        print "CPU $cpu External PROCHOT logged" if bit($ia32_therm_status, 3);
        print "CPU $cpu Critical temperature active" if bit($ia32_therm_status, 4);
        print "CPU $cpu Critical temperature logged" if bit($ia32_therm_status, 5);
        print "CPU $cpu Thermal threshold #1 acctive" if bit($ia32_therm_status, 6);
        print "CPU $cpu Thermal threshold #1 logged" if bit($ia32_therm_status, 7);
        print "CPU $cpu Thermal threshold #2 acctive" if bit($ia32_therm_status, 8);
        print "CPU $cpu Thermal threshold #2 logged" if bit($ia32_therm_status, 9);
        print "CPU $cpu Power limit acctive" if bit($ia32_therm_status, 10);
        print "CPU $cpu Power limit logged" if bit($ia32_therm_status, 11);
        print "CPU $cpu Degrees C below critical: " . bitfield($ia32_therm_status, 22, 16) if bit($ia32_therm_status, 31) and not $quiet;
    }
    my $ia32_package_therm_status = rdmsr('0x1b1', 0);
    print "Package PROCHOT/TM active" if bit($ia32_package_therm_status, 0);
    print "Package PROCHOT/TM logged" if bit($ia32_package_therm_status, 1);
    print "Package External PROCHOT active" if bit($ia32_package_therm_status, 2);
    print "Package External PROCHOT logged" if bit($ia32_package_therm_status, 3);
    print "Package Critical temperature active" if bit($ia32_package_therm_status, 4);
    print "Package Critical temperature logged" if bit($ia32_package_therm_status, 5);
    print "Package Thermal threshold #1 acctive" if bit($ia32_package_therm_status, 6);
    print "Package Thermal threshold #1 logged" if bit($ia32_package_therm_status, 7);
    print "Package Thermal threshold #2 acctive" if bit($ia32_package_therm_status, 8);
    print "Package Thermal threshold #2 logged" if bit($ia32_package_therm_status, 9);
    print "Package Power limit acctive" if bit($ia32_package_therm_status, 10);
    print "Package Power limit logged" if bit($ia32_package_therm_status, 11);
    print "Package Degrees C below critical: " . bitfield($ia32_package_therm_status, 22, 16) unless $quiet;
}

sub ia32_clockmod {
    for (my $cpu = 0; $cpu < $ncpus; $cpu++) {
        my $ia32_clock_modulation = rdmsr('0x19a', $cpu);

        print "CPU $cpu CLOCKMOD active" if bit($ia32_clock_modulation, 4);
        print "CPU $cpu CLOCKMOD level " . bitfield($ia32_clock_modulation, 3, 0)/16 if bit($ia32_clock_modulation, 4);
    }
}

sub core_perf_limit_reasons {
    for (my $cpu = 0; $cpu < $ncpus; $cpu++) {
        my $core_perf_limit_reasons = rdmsr('0x690', $cpu);

        print "CPU $cpu PROCHOT active" if bit($core_perf_limit_reasons, 0);
        print "CPU $cpu PROCHOT logged" if bit($core_perf_limit_reasons, 16);
        print "CPU $cpu Thermal active" if bit($core_perf_limit_reasons, 1);
        print "CPU $cpu Thermal logged" if bit($core_perf_limit_reasons, 17);
        print "CPU $cpu Graphics driver active" if bit($core_perf_limit_reasons, 4);
        print "CPU $cpu Graphics driver logged" if bit($core_perf_limit_reasons, 16+4);
        print "CPU $cpu Low utilization active" if bit($core_perf_limit_reasons, 5);
        print "CPU $cpu Low utilization logged" if bit($core_perf_limit_reasons, 16+5) and not $quiet;
        print "CPU $cpu Voltage regulator thermal active" if bit($core_perf_limit_reasons, 6);
        print "CPU $cpu Voltage regulator thermal logged" if bit($core_perf_limit_reasons, 16+6);
        print "CPU $cpu Electrical limit active" if bit($core_perf_limit_reasons, 8);
        print "CPU $cpu Electrical limit logged" if bit($core_perf_limit_reasons, 16+8);
        print "CPU $cpu Core power limit active" if bit($core_perf_limit_reasons, 9);
        print "CPU $cpu Core power limit logged" if bit($core_perf_limit_reasons, 16+9);
        print "CPU $cpu Package power limit #1 active" if bit($core_perf_limit_reasons, 10);
        print "CPU $cpu Package power limit #1 logged" if bit($core_perf_limit_reasons, 16+10);
        print "CPU $cpu Package power limit #2 active" if bit($core_perf_limit_reasons, 11);
        print "CPU $cpu Package power limit #2 logged" if bit($core_perf_limit_reasons, 16+11);
        print "CPU $cpu Turbo limit active" if bit($core_perf_limit_reasons, 12);
        print "CPU $cpu Turbo limit logged" if bit($core_perf_limit_reasons, 16+12) and not $quiet;
        print "CPU $cpu Turbo transition limit active" if bit($core_perf_limit_reasons, 13);
        print "CPU $cpu Turbo transition limit logged" if bit($core_perf_limit_reasons, 16+13) and not $quiet;
    }
    my $graphics_perf_limit_reasons = rdmsr('0x6B0', 0);

    print "Graphics PROCHOT active" if bit($graphics_perf_limit_reasons, 0);
    print "Graphics PROCHOT logged" if bit($graphics_perf_limit_reasons, 16);
    print "Graphics Thermal active" if bit($graphics_perf_limit_reasons, 1);
    print "Graphics Thermal logged" if bit($graphics_perf_limit_reasons, 17);
    print "Graphics Graphics driver active" if bit($graphics_perf_limit_reasons, 4);
    print "Graphics Graphics driver logged" if bit($graphics_perf_limit_reasons, 16+4);
    print "Graphics Low utilization active" if bit($graphics_perf_limit_reasons, 5);
    print "Graphics Low utilization logged" if bit($graphics_perf_limit_reasons, 16+5);
    print "Graphics Voltage regulator thermal active" if bit($graphics_perf_limit_reasons, 6);
    print "Graphics Voltage regulator thermal logged" if bit($graphics_perf_limit_reasons, 16+6);
    print "Graphics Electrical limit active" if bit($graphics_perf_limit_reasons, 8);
    print "Graphics Electrical limit logged" if bit($graphics_perf_limit_reasons, 16+8);
    print "Graphics Core power limit active" if bit($graphics_perf_limit_reasons, 9);
    print "Graphics Core power limit logged" if bit($graphics_perf_limit_reasons, 16+9);
    print "Graphics Package power limit #1 active" if bit($graphics_perf_limit_reasons, 10);
    print "Graphics Package power limit #1 logged" if bit($graphics_perf_limit_reasons, 16+10);
    print "Graphics Package power limit #2 active" if bit($graphics_perf_limit_reasons, 11);
    print "Graphics Package power limit #2 logged" if bit($graphics_perf_limit_reasons, 16+11);
    print "Graphics Turbo limit active" if bit($graphics_perf_limit_reasons, 12);
    print "Graphics Turbo limit logged" if bit($graphics_perf_limit_reasons, 16+12);
    print "Graphics Turbo transition limit active" if bit($graphics_perf_limit_reasons, 13);
    print "Graphics Turbo transision limit logged" if bit($graphics_perf_limit_reasons, 16+13);

    my $ring_perf_limit_reasons = rdmsr('0x6B1', 0);

    print "Ring PROCHOT active" if bit($ring_perf_limit_reasons, 0);
    print "Ring PROCHOT logged" if bit($ring_perf_limit_reasons, 16);
    print "Ring Thermal active" if bit($ring_perf_limit_reasons, 1);
    print "Ring Thermal logged" if bit($ring_perf_limit_reasons, 17);
    print "Ring Ring driver active" if bit($ring_perf_limit_reasons, 4);
    print "Ring Ring driver logged" if bit($ring_perf_limit_reasons, 16+4);
    print "Ring Low utilization active" if bit($ring_perf_limit_reasons, 5);
    print "Ring Low utilization logged" if bit($ring_perf_limit_reasons, 16+5);
    print "Ring Voltage regulator thermal active" if bit($ring_perf_limit_reasons, 6);
    print "Ring Voltage regulator thermal logged" if bit($ring_perf_limit_reasons, 16+6);
    print "Ring Electrical limit active" if bit($ring_perf_limit_reasons, 8);
    print "Ring Electrical limit logged" if bit($ring_perf_limit_reasons, 16+8);
    print "Ring Core power limit active" if bit($ring_perf_limit_reasons, 9);
    print "Ring Core power limit logged" if bit($ring_perf_limit_reasons, 16+9);
    print "Ring Package power limit #1 active" if bit($ring_perf_limit_reasons, 10);
    print "Ring Package power limit #1 logged" if bit($ring_perf_limit_reasons, 16+10);
    print "Ring Package power limit #2 active" if bit($ring_perf_limit_reasons, 11);
    print "Ring Package power limit #2 logged" if bit($ring_perf_limit_reasons, 16+11);
    print "Ring Turbo limit active" if bit($ring_perf_limit_reasons, 12);
    print "Ring Turbo limit logged" if bit($ring_perf_limit_reasons, 16+12);
    print "Ring Turbo transition limit active" if bit($ring_perf_limit_reasons, 13);
    print "Ring Turbo transision limit logged" if bit($ring_perf_limit_reasons, 16+13);
}

sub rapl {
    my %rapls = (
        0x610 => 'package',
        0x638 => 'PP0',
        0x640 => 'PP1',
        
    );

    my $rapl_power_units = rdmsr(0x606, 0);
    my $power_units = 0.5**bitfield($rapl_power_units, 3, 0);
    my $energy_status_units = 0.5**bitfield($rapl_power_units, 12, 8);
    my $time_units = 0.5**bitfield($rapl_power_units, 19, 16);

    for my $base (sort(keys(%rapls))) {
        my $pkg_power_limit = rdmsr($base + 0, 0);
        my $domain = $rapls{$base};

        print "$domain power limit #1 enabled" if bit($pkg_power_limit, 15);
        print "$domain power limit #1 clamping enabled" if bit($pkg_power_limit, 16);
        print "$domain power limit #1: " . bitfield($pkg_power_limit, 14, 0) * $power_units . "W" if bit($pkg_power_limit, 15) and not $quiet;
        print "$domain time limit #1: " . bitfield($pkg_power_limit, 23, 17) * $time_units . "s" if bit($pkg_power_limit, 15) and not $quiet;
        if ($domain eq "package") {
            print "$domain power limit #2 enabled" if bit($pkg_power_limit, 47);
            print "$domain power limit #2 clamping enabled" if bit($pkg_power_limit, 48);
            print "$domain power limit #2: " . bitfield($pkg_power_limit, 46, 32) * $power_units . "W" if bit($pkg_power_limit, 15) and not $quiet;
            print "$domain time limit #2: " . bitfield($pkg_power_limit, 55, 49) * $time_units . "s" if bit($pkg_power_limit, 15) and not $quiet;
            print "$domain power limit locked" if bit($pkg_power_limit, 63) and not $quiet;
        } else {
            print "$domain power limit locked" if bit($pkg_power_limit, 31) and not $quiet;
        }

        my $pkg_energy_status = rdmsr($base + 1, 0);
        print "$domain energy consumed: " . bitfield($pkg_energy_status, 31, 0) * $energy_status_units . "J";

        if ($domain eq 'package') {
            my $pkg_perf_status = rdmsr($base + 3, 0);
            print "Accumulated $domain throttled time " . bitfield($pkg_perf_status, 31, 0) if bitfield($pkg_perf_status, 31, 0) > 0;
        }

        if ($domain eq 'package' && !$quiet) {
            my $pkg_power_info = rdmsr($base + 4, 0);
            print "$domain thermal spec power: " . bitfield($pkg_power_limit, 14, 0) * $power_units . "W";
            print "$domain minimum power: " . bitfield($pkg_power_limit, 30, 16) * $power_units . "W";
            print "$domain maximum power: " . bitfield($pkg_power_limit, 46, 32) * $power_units . "W";
            print "$domain maximum time window: " . bitfield($pkg_power_limit, 53, 48) * $time_units . "s";
        }
    }
}

misc();
pstate();
ia32_therm();
ia32_clockmod();
# core_perf_limit_reasons();
rapl();

if ($clear) {
    `wrmsr -a 0x19c 0x0`;
    `wrmsr 0x1b1 0x0`;
#     `wrmsr -a 0x690 0x0`;
#     `wrmsr 0x6b0 0x0`;
#     `wrmsr 0x6b1 0x0`;
}

