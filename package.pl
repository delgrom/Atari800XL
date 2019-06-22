#!/usr/bin/perl -w
use POSIX qw(strftime);

my @files;

push @files, glob("mcc216/build*/output_files/*.arg");
push @files, glob("mcc216/build*/output_files/*.sof");
push @files, glob("mcc216/build*/output_files/*.rbf");
push @files, glob("mcc216/build*/output_files/*.summary");
push @files, glob("mcc216/build*/output_files/*.rpt");

push @files, glob("mcc216_5200/build*/output_files/*.arg");
push @files, glob("mcc216_5200/build*/output_files/*.sof");
push @files, glob("mcc216_5200/build*/output_files/*.rbf");
push @files, glob("mcc216_5200/build*/output_files/*.summary");
push @files, glob("mcc216_5200/build*/output_files/*.rpt");

push @files, glob("mcctv/build*/output_files/*.arg");
push @files, glob("mcctv/build*/output_files/*.sof");
push @files, glob("mcctv/build*/output_files/*.rbf");
push @files, glob("mcctv/build*/output_files/*.summary");
push @files, glob("mcctv/build*/output_files/*.rpt");

push @files, glob("mcctv_5200/build*/output_files/*.arg");
push @files, glob("mcctv_5200/build*/output_files/*.sof");
push @files, glob("mcctv_5200/build*/output_files/*.rbf");
push @files, glob("mcctv_5200/build*/output_files/*.summary");
push @files, glob("mcctv_5200/build*/output_files/*.rpt");

push @files, glob("mist/build*/out/*.sof");
push @files, glob("mist/build*/out/*.rbf");
push @files, glob("mist/build*/out/*.summary");
push @files, glob("mist/build*/out/*.rpt");

push @files, glob("mist_5200/build*/out/*.sof");
push @files, glob("mist_5200/build*/out/*.rbf");
push @files, glob("mist_5200/build*/out/*.summary");
push @files, glob("mist_5200/build*/out/*.rpt");

push @files, glob("chameleon/build*/output_files/*.sof");
push @files, glob("chameleon/build*/output_files/*.rbf");
push @files, glob("chameleon/build*/output_files/*.summary");
push @files, glob("chameleon/build*/output_files/*.rpt");

push @files, glob("chameleon2/build*/output_files/*.sof");
push @files, glob("chameleon2/build*/output_files/*.rbf");
push @files, glob("chameleon2/build*/output_files/*.summary");
push @files, glob("chameleon2/build*/output_files/*.rpt");

push @files, glob("eclaireXL_ITX/build*/output_files/*.sof");
push @files, glob("eclaireXL_ITX/build*/output_files/*.rbf");
push @files, glob("eclaireXL_ITX/build*/output_files/*.rbd");
push @files, glob("eclaireXL_ITX/build*/output_files/*.summary");
push @files, glob("eclaireXL_ITX/build*/output_files/*.rpt");

#push @files, glob("de1/build*/output_files/*.sof");
#push @files, glob("de1/build*/output_files/*.pof");
#push @files, glob("de1/build*/output_files/*.summary");
#push @files, glob("de1/build*/output_files/*.rpt");
#
#push @files, glob("de1_5200/build*/output_files/*.sof");
#push @files, glob("de1_5200/build*/output_files/*.pof");
#push @files, glob("de1_5200/build*/output_files/*.summary");
#push @files, glob("de1_5200/build*/output_files/*.rpt");
#
#push @files, glob("sockit/build*/output_files/*.sof");
#push @files, glob("sockit/build*/output_files/*.rbf");
#push @files, glob("sockit/build*/output_files/*.summary");
#push @files, glob("sockit/build*/output_files/*.rpt");
#push @files, glob("sockit/SOCKIT.elf");
#push @files, glob("sockit/type");
#push @files, glob("sockit/reboot");

#push @files, glob("papilioduo/build*/*.bit");

#push @files, glob("aeon_lite/build*/*.bit");
#push @files, glob("aeon_lite/build*/*.bin");
#
#push @files, glob("replay/sdcard/*.bin");
#push @files, glob("replay/sdcard/*.ini");

my $DEST="/home/markw/fpga/svn/repo/trunk/atari_800xl/packaged/"
mkdir "$DEST";
my $date = strftime("%Y%m%d",gmtime);
my $dir = "$DEST/$date";
mkdir $dir;
open (LOG,">".$dir."/log") or die "Failed to open log";
foreach (@files)
{
	my $creationtime = (stat($_))[9];
	my $creation = strftime("%Y%m%dT%T",gmtime($creationtime));
	print LOG "File:$_ Date:$creation\n";

	/(.*)\/(.*)/;
	my ($dir2,$file) = ($1,$2);
	#print "DIR:$dir2 FILE:$file\n";
	`mkdir -p $dir/$dir2`;

	`cp -f $_ $dir/$dir2`;
}
close(LOG);
`cp -f instructions.txt $dir/`;
`cp -f chameleon_setup.txt $dir/`;


