#!/usr/bin/perl
#
#	Usage: bin2mem.pl <addr> <binary-file> > output.mem
#
#	Convert a binary file to a .mem file usable by Xilinx tools.
#

if ($#ARGV < 1) {
    die "Usage: bin2mem.pl <addr> <binaryfile>\n";
}

$addr = hex($ARGV[0]);
$file = $ARGV[1];
$column = 0;

open(BINFILE, "$file") || die "Couldn't open $file for reading.\n";
while (read(BINFILE, $buf, 1) == 1) {
    $byte = unpack("C", $buf);
    if ($column == 0) {
	printf "@%04X ", $addr;
    }
    printf "%02X ", $byte;
    $addr++;
    if (++$column == 16) {
	$column = 0;
	print "\n";
    }
}
close(BINFILE);
