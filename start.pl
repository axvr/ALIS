#!/usr/bin/perl

# ALIS - Arch Linux Installation Script
# =====================================
#
# The successor to Architect Linux

# Things to do next in this file:
# * comment code
# * bug fixes

# MODULES SETUP
use v5.24.1;
use strict;
use warnings;
use Getopt::Long;

# Log file setup
my $log_file = "alis.log";

# PARAMETERS SETUP
my $current_version = "0.0.4";
my $usage_message = "perl start.pl --start [--version] [--help] [--force]\n";
my $start = "";
my $force = 0;
my $help_menu = "";
my $version = "";
my $usage = !scalar(@ARGV);

GetOptions (
	"start+"	=> \$start,
	"force+"   	=> \$force,
	"h|help+"  	=> \$help_menu,
	"v|version+"=> \$version);
	
my $operation = shift @ARGV;

if ($usage) {
	print STDERR "$usage_message";
	exit 1;
}

if ($version) {
	print STDERR "ALIS $current_version\n";
	exit 1;
}

if ($help_menu) {
	print STDERR "\n", `cat README.md`, "\n";
	exit 1;
}

if (!$start) {
	print STDERR "$usage_message";
	exit 1;
}


# MAIN CODE

# run the network connection check bash script
if (!$force) {
	system("whiptail", "--title", "ALIS - Arch Linux Installation Script", "--msgbox",
		"Welcome to ALIS, the successor to Architect Linux. Press OK to continue.", "8", "55");
	exec("bash", "network-check.sh");
}

# wipe the log file via truncating it
open (my $cl, ">", $log_file) or die "Could not open '$log_file'. $!";
print $cl "ALIS is starting\n";
close $cl;

# reopen the log file in append mode
open (my $fh, ">>", $log_file) or die "Could not open '$log_file'. $!";
print $fh "Network connected or was forced\n";

# collect hardware information
my $hardware_version = `uname -m`;
my $uefi_or_bios = `[ -d /sys/firmware/efi ] && echo UEFI || echo BIOS`;
chomp($hardware_version);
chomp($uefi_or_bios);

# Hardware validation check
if (($uefi_or_bios ne "BIOS") && ($uefi_or_bios ne "UEFI")) {
	print "Installation canceled. Incompatible system boot mode.\n";
	print $fh "INCOMPATIBLE SYSTEM BOOT MODE\n";
	print $fh "You are running: $uefi_or_bios\n";
	print $fh "ALIS will only work with (UEFI or BIOS) and (i686 or x86_64)\n";
	print $fh "Installation Cancelled\n";
	close $fh or die "Could not open '$log_file'. $!";
	exit 0;
} elsif (($hardware_version ne "x86_64") && ($hardware_version ne "i686")) {
	print "Installation canceled. Incompatible system architecture.\n";
	open (my $fh, ">>", $log_file) or die "Could not open '$log_file'. $!";
	print $fh "INCOMPATIBLE HARDWARE ARCHITECTURE\n";
	print $fh "You are using: $hardware_version\n";
	print $fh "ALIS will only work with (UEFI or BIOS) and (i686 or x86_64)\n";
	print $fh "Installation Cancelled\n";
	close $fh or die "Could not open '$log_file'. $!";
	exit 0;
}

# log the hardware configuration to the log file
print $fh "Hardware:  $hardware_version\n";
print $fh "Boot Mode: $uefi_or_bios\n";
print $fh "Device hardware appears to be compatible\n";

# Sync time with NTP servers
system("timedatectl", "set-ntp", "true");
my @universal_time = `timedatectl status`;
print $fh "\nTime has been NTP synced\n";
print $fh "@universal_time\n";
my $utc = substr($universal_time[1], 2);

# choose keymap part 1
my $whiptail;
my $keyboard_layout;

sub keys1 {
	$whiptail = qq{whiptail --title "Select keyboard layout" --radiolist --nocancel }.
		qq{--backtitle "ARCH LINUX INSTALLATION SCRIPT $hardware_version $uefi_or_bios" }.
		qq{"\nChoose Your Keyboard Layout:" 15 55 6 }.
		qq{"QWERTY" "The QWERTY keymap (Most Common)" "ON" }.
		qq{"QWERTZ" "The QWERTZ style keyboard layout" "OFF" }.
		qq{"AZERTY" "The AZERTY keyboard layout" "OFF" }.
		qq{"Dvorak" "The Dvorak keyoard layout map" "OFF" }.
		qq{"Colemak" "The Colemak keyboard layout" "OFF" }.
		qq{"Other" "Select a different keymap here" "OFF" 3>&1 1>&2 2>&3 };
	$keyboard_layout = `$whiptail`;
	$keyboard_layout =~ tr/A-Z/a-z/;
	
	if ($keyboard_layout eq "other") {
		$whiptail = qq{whiptail --title "Select keyboard layout" }.
			qq{--backtitle "ARCH LINUX INSTALLATION SCRIPT $hardware_version $uefi_or_bios" }.
			qq{--inputbox "\nInput a different keymap" 7 45 "" 3>&1 1>&2 2>&3};
		my $keymap = `$whiptail`;
		
		if ($keymap eq "") {
			keys1();
		} else {
			my @values = split(' ', $keymap);
			$keymap = $values[0];
			my $run_loadkeys = system("loadkeys", "$keymap");
			print $fh "Loading keymap: $keymap\n";
			
			if ($run_loadkeys != 0) {
				system("whiptail", "--title", "Invalid keymap", "--msgbox",
					"--backtitle", "ARCH LINUX INSTALLATION SCRIPT $hardware_version $uefi_or_bios",
					"Keymap '$keymap' was invalid. Press OK to go back.", "8", "45");
				print $fh "Keymap was invalid, starting again\n";
				keys1();
			} else {
				print $fh "Keymap was valid, continuing\n";
				print $fh "Running main-menu.pl using perl\n";
				close $fh or die "Could not close '$log_file'. $!";
				system("whiptail", "--title", "Keymap was successfully set", "--msgbox",
					"--backtitle", "ARCH LINUX INSTALLATION SCRIPT $hardware_version $uefi_or_bios",
					"Keymap '$keymap' was set successfully. Press OK to continue.", "8", "45");
				exec("perl", "main-menu.pl", "$hardware_version", "$uefi_or_bios", "$keymap");
			}
		}
	} elsif ($keyboard_layout ne "other") {
		keys2();
	}

}

# choose keymap part 2
sub keys2 {
	my @keymaps = `ls /usr/share/kbd/keymaps/i386/$keyboard_layout/`;
	my $layouts_for_whiptail = "";

	#foreach (my $i (0..($total - 1)) {
	foreach (@keymaps) {
		chomp($_);
		if ($_ eq "us.map.gz") {
			$layouts_for_whiptail = $layouts_for_whiptail . qq{"$_" "ON" };
		} else {
			$layouts_for_whiptail = $layouts_for_whiptail . qq{"$_" "OFF" };
		}
	}

	$whiptail = qq{whiptail --title "Select keyboard layout" }.
		qq{--radiolist --noitem --cancel-button "Back" }.
		qq{--backtitle "ARCH LINUX INSTALLATION SCRIPT $hardware_version $uefi_or_bios" }.
		qq{"\nChoose Your Keyboard Layout:  (Default = US QWERTY)" 15 55 7 }.
		qq{$layouts_for_whiptail}.
		qq{3>&1 1>&2 2>&3 };
	my $keymap = `$whiptail`;
	if ($keymap eq "") {
		keys1();
	} else {
		print $fh "Loading keymap: $keyboard_layout/$keymap\n";
		system("loadkeys", "$keyboard_layout/$keymap");
		# run the menu script (parameters to send the architecture, boot mode, and keyboard layout)
		print $fh "Running main-menu.pl using perl\n";
		close $fh or die "Could not close '$log_file'. $!";
		exec("perl", "main-menu.pl", "$hardware_version", "$uefi_or_bios", "$keymap");
	}
}

keys1();

