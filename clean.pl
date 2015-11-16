#!/home/ben/software/install/bin/perl
use warnings;
use strict;
use utf8;
use FindBin '$Bin';
my @rmfiles = (qw/extra.h tidy-html5.c tidy-html5.h/);
for my $file (@rmfiles) {
    if (-f $file) {
	unlink $file or warn "Error unlinking $file: $!";
    }
}
