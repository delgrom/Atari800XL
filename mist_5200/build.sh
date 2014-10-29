#!/usr/bin/perl -w
use strict;

my $wanted_variant = shift @ARGV;

#variants...
my $NTSC = 0;

my $RGB = 1; # i.e. not scandoubled
my $VGA = 2;

#Added like this to the generated qsf
#set_parameter -name TV 1

my %variants = 
(
	"NTSC_RGB" =>
	{
		"TV" => $NTSC,
		"SCANDOUBLE" => 0,
		"VIDEO" => $RGB, 
		"COMPOSITE_SYNC" => 1
	},
	"NTSC_VGA" => 
	{
		"TV" => $NTSC,
		"SCANDOUBLE" => 1,
		"VIDEO" => $VGA,
		"COMPOSITE_SYNC" => 0
	},
	"NTSC_VGA_CS" => 
	{
		"TV" => $NTSC,
		"SCANDOUBLE" => 1,
		"VIDEO" => $VGA,
		"COMPOSITE_SYNC" => 1
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
	`cp atari5200core_mist.vhd $dir`;
	`cp *pll*.* $dir`;
	`cp *mist_sector*.* $dir`;
	`cp *.v $dir`;
	`cp *.vhdl $dir`;
	`cp zpu_rom.vhdl $dir`;
	`cp atari5200core.sdc $dir`;
	`mkdir $dir/common`;
	`mkdir $dir/common/a8core`;
	`mkdir $dir/common/components`;
	`mkdir $dir/common/zpu`;
	`cp ../common/a8core/* ./$dir/common/a8core`;
	`cp ../common/components/* ./$dir/common/components`;
	`cp ../common/zpu/* ./$dir/common/zpu`;

	chdir $dir;
	`../makeqsf ../atari5200core.qsf ./common/a8core ./common/components ./common/zpu`;

	foreach my $key (sort keys %{$variants{$variant}})
	{
		my $val = $variants{$variant}->{$key};
		`echo set_parameter -name $key $val >> atari5200core.qsf`;
	}

	`quartus_sh --flow compile atari5200core > build.log 2> build.err`;

	`quartus_cpf --convert ../output_file.cof`;
	
	chdir "..";
}

