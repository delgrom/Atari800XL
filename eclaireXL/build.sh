#!/usr/bin/perl -w
use strict;

my $wanted_variant = shift @ARGV;

my $name="eclaireXL";

#variants...
my $PAL = 1;
my $NTSC = 0;

my $RGB = 1; # i.e. not scandoubled
my $VGA = 2;

#Added like this to the generated qsf
#set_parameter -name TV 1

my %variants = 
(
#	"PAL" => 
#	{
#		"TV" => $PAL
#	},
#	"NTSC" =>
#	{
#		"TV" => $NTSC
#	},
	"A2EBArom" =>
	{
		"TV" => 2,
		"GPIO" => 2,
		"internal_ram" => 65536,
		"internal_rom" => 1
	},
	"A9EFArom" =>
	{
		"TV" => 2,
		"GPIO" => 2,
		"internal_ram" => 65536,
		"internal_rom" => 1
	},
	"A2EBA" =>
	{
		"TV" => 2,
		"GPIO" => 3,
		"internal_ram" => 0,
		"internal_rom" => 0
	},
	"A9EFA" =>
	{
		"TV" => 2,
		"GPIO" => 2,
		"internal_ram" => 0,
		"internal_rom" => 0
	}
);

if (not defined $wanted_variant or (not exists $variants{$wanted_variant} and $wanted_variant ne "ALL"))
{
	die "Provide variant of ALL or ".join ",",sort keys %variants;
}

foreach my $variant (sort keys %variants)
{
	next if ($wanted_variant ne $variant and $wanted_variant ne "ALL");
	print "Building $variant of $name\n";

	my $dir = "build_$variant";
	`rm -rf $dir`;
	mkdir $dir;
	`cp atari800core_eclaireXL.vhd $dir`;
	`cp -a *pll* $dir`;
	`cp -a *gpioram* $dir`;
	#`cp -a *serial_loader* $dir`;
	`cp *.v $dir`;
	`cp *.vhd* $dir`;
	`cp atari800core*.sdc $dir`;
	`mkdir $dir/common`;
	`mkdir $dir/common/a8core`;
	`mkdir $dir/common/components`;
	`mkdir $dir/common/zpu`;
	mkdir "./$dir/common/components/usbhostslave";
	`cp ../common/components/usbhostslave/trunk/RTL/*/*.v ./$dir/common/components/usbhostslave`;
	`cp ../common/a8core/* ./$dir/common/a8core`;
	`cp ../common/components/* ./$dir/common/components`;
	`cp ../common/zpu/* ./$dir/common/zpu`;

	chdir $dir;
	`../makeqsf ../atari800core_eclaireXL.qsf ./common/a8core ./common/components ./common/zpu ./common/components/usbhostslave`;
	`cat ../atari800core_eclaireXL.qsf_$variant >> atari800core_eclaireXL.qsf`;

	foreach my $key (sort keys %{$variants{$variant}})
	{
		my $val = $variants{$variant}->{$key};
		`echo set_parameter -name $key $val >> atari800core_eclaireXL.qsf`;
	}

	`quartus_sh --flow compile atari800core_eclaireXL > build.log 2> build.err`;

#	`quartus_cpf --convert ../output_file.cof`;
	
	chdir "..";
}

