#!/usr/bin/perl -w
use strict;

my $wanted_variant = shift @ARGV;

#variants...
my $PAL = 1;
my $NTSC = 0;

my $SVIDEO = 1;
my $VGA = 2;

#Added like this to the generated qsf
#set_parameter -name TV 1

my %variants = 
(
	"PAL_SVIDEO" => 
	{
		"TV" => $PAL,
		"SCANDOUBLE" => 0,
		"VIDEO" => $SVIDEO,
		"internal_ram" => 0,
		"internal_rom" => 0,
		"ext_clock" => 0
	},
	"NTSC_SVIDEO" =>
	{
		"TV" => $NTSC,
		"SCANDOUBLE" => 0,
		"VIDEO" => $SVIDEO,
		"internal_ram" => 0,
		"internal_rom" => 0,
		"ext_clock" => 0
	}
);

if (not defined $wanted_variant or (not exists $variants{$wanted_variant} and $wanted_variant ne "ALL"))
{
	die "Provide variant of ALL or ".join ",",sort keys %variants;
}

foreach my $variant (sort keys %variants)
{
	next if ($wanted_variant ne $variant and $wanted_variant ne "ALL");
	print "Building $variant\n";

	my $dir = "build_$variant";
	`rm -rf $dir`;
	mkdir $dir;
	`cp atari800core_mcc.vhd $dir`;
	`cp *pll*.* $dir`;
	`cp sdram_ctrl_3_ports.v $dir`;
	`cp zpu_rom.vhdl $dir`;
	`cp atari800core.sdc $dir`;
	`mkdir $dir/common`;
	`mkdir $dir/common/a8core`;
	`mkdir $dir/common/components`;
	`mkdir $dir/common/zpu`;
	`mkdir $dir/svideo`;
	`mkdir $dir/usb`;
	`cp ../common/a8core/* ./$dir/common/a8core`;
	`cp ../common/components/* ./$dir/common/components`;
	`cp ../common/zpu/* ./$dir/common/zpu`;
	`cp ./svideo/* ./$dir/svideo`;
	`cp ./usb/* ./$dir/usb`;

	chdir $dir;
	`../makeqsf ../atari800core.qsf ./svideo ./usb ./common/a8core ./common/components ./common/zpu`;

	foreach my $key (sort keys %{$variants{$variant}})
	{
		my $val = $variants{$variant}->{$key};
		`echo set_parameter -name $key $val >> atari800core.qsf`;
	}

	`quartus_sh --flow compile atari800core > build.log 2> build.err`;

	`quartus_cpf --convert ../output_file.cof`;
	my $vga = 1;
	if ($variant =~ /SVIDEO/)
	{
		$vga = 0;
	}
	
	#TODO - generate automated version number
	my $version = `svn info  | grep Revision: | cut -d' ' -f 2`;
	chomp $version;
	$version = `date +%y%m`;
	my $version2 = `date +%d`;
	chomp $version;
	chomp $version2;
	my $cmd = "wine ../rbf2arg/rbf2arg.exe 2 A $version.$version2 \"Atari 800XL $variant\" output_files/atari800core.rbf output_files/atari800core_$variant.arg";
	print "Running $cmd\n";
	`$cmd`;
	
	chdir "..";
}


#--for the MCC216 S-Video
#--rbf2arg 0 A <version.revison> "description" <filename.rbf> <filename.arg>
#--for the MCC216 VGA
#--rbf2arg 1 A <version.revison> "description" <filename.rbf> <filename.arg>


