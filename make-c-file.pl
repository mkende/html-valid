#!/home/ben/software/install/bin/perl

# Make the tidy-html5 library into one big C file for use in a Perl
# project to validate HTML.

# This file is specific to version 5.0.0 of tidy-html5. The maintainer
# should expect to have to overhaul this with each new version of
# tidy-html5, as the changes made here become less relevant.

use warnings;
use strict;
use utf8;
use FindBin '$Bin';
use Path::Tiny;

# This is used for the line directives, but they turned out to be a nuisance.

use C::Utility ':all';

use C::Tokenize '0.10', ':all';

# If $verbose is true, the program prints various information as
# it works. The information goes via the routine "msg" below and
# is printed with the file and line number of the processing.

my $verbose;

# Print a line directive?

my $line_directives;

# Time now as string.

my $time = scalar (localtime ());

# Stamp for the top of the automatically generated files.

my $stamp =<<EOF;
/*
   This file was generated by

   $0

   at $time 
*/
EOF

main ();
exit;

sub main
{
    my $htdir = '/home/ben/software/tidy-html5-5.0.0';
    my $srcdir = "$htdir/src";
    my $incdir = "$htdir/include";
    my $base = 'tidy-html5';

    my $houtput = "$Bin/$base.h";
    msg ("Writing $houtput");
    write_public_h_file ($incdir, $houtput);

    my $coutput = "$Bin/$base.c";
    msg ("Writing $coutput");
    write_c_files ($srcdir, $coutput);
}

# Write the combined header file made out of the three or four
# separate header files.

sub write_public_h_file
{
    my ($incdir, $houtput) = @_;
    if (-f $houtput) {
	chmod 0644, $houtput;
    }
    open my $out, ">", $houtput or die $!;
    print $out $stamp;
    print_h_defines ($out);

    # Order counts here.

    my @pubhfiles = ("$incdir/tidyplatform.h", "$incdir/tidyenum.h",
		     "$incdir/tidy.h", "$incdir/tidybuffio.h");

    for my $file (@pubhfiles) {
	my $path = path ($file);
	my $text = $path->slurp ();
	$text =~ s!$include_local!/* $1 */!g;
	$text = disable_local_variables ($text);
	$text = remove_typedefs ($text);
	print $out $text;
    }

    # Add declarations for our extra things.

    system ("cfunctions extra.c") == 0 or die "Error making extra.h";
    my $extrah = path ("$Bin/extra.h")->slurp_utf8 ();
    print $out $extrah;
    close $out;
    chmod 0444, $houtput;
}

sub print_h_defines
{
    my ($out) = @_;
    print $out <<EOF;

/* We are not going to open any files using any facility of HTML Tidy,
   so undefine all of these things so that the library compiles on
   various operating systems. */

#define PRESERVE_FILE_TIMES 0
#define HAS_FUTIME 0

/* -------------------------------------------------- */

EOF
}

sub write_c_files
{
    my ($srcdir, $coutput) = @_;
    my @cfiles = <$srcdir/*.c>;
    my @privhfiles = <$srcdir/*.h>;

    msg ("Writing output to $coutput");

    if (-f $coutput) {
	chmod 0644, $coutput;
    }
    open my $out, ">", $coutput or die $!;

    print $out $stamp;

    write_include ($out);

#    $verbose = 1;

    write_internal_header_files ($out, \@privhfiles);

    msg ("Including C files");

    for my $cfile (@cfiles) {
	write_c_file ($out, $cfile);
    }
    my $extra = path ("$Bin/extra.c")->slurp_utf8 ();
    print $out $extra;
    close $out;
    chmod 0444, $coutput;
}

sub write_c_file
{
    my ($out, $cfile) = @_;
    my $path = path ($cfile);
    my $text = $path->slurp ();
    my $basename = $path->basename ();
    # Fix clashes by appending the file's name to clashing items.
    my $id = $basename;
    # Make $id a safe C identifier.
    $id =~ s/[^A-Za-z0-9]/_/g;
    if ($line_directives) {
    	line_directive ($out, 1, $basename);
    }
    $text =~ s!$include_local!/* $1 */!g;
    # Fix clashes with C names.
    $text =~ s!(DiscardContainer|CleanNode)!$1_$id!g;

    # Apparently most of the declarations of freeFileSource and
    # initFileSource are dead code, so we mothball all of them except
    # in the following four files where the function is actually being
    # used:

    if ($basename ne 'mappedio.c' && $basename ne 'config.c' &&
	$basename ne 'streamio.c' && $basename ne 'tidylib.c') {
	$text =~ s!((?:free|init)FileSource)!$1_$id!g;
    }

    # This code makes a warning. 

    if ($basename eq 'pprint.c') {
	$text =~ s/\Q(((ix + 1) == end) || ((ix + 1) < end) && (isspace(doc->lexer->lexbuf[ix+1]))) )\E/(((ix + 1) == end) || (((ix + 1) < end) && (isspace(doc->lexer->lexbuf[ix+1])))) )/;
    }
    
    # Unused variable warning.

    if ($basename eq 'streamio.c') {
	$text =~ s!(static const uint Symbol2Unicode[^;]+;)!/* UNUSED VARIABLE COMMENTED OUT BY $0: $1 */!;
    }

    # Unused variable warning.

    if ($basename eq 'localize.c') {
	$text =~ s!(static const TidyOptionId TidyGDocCleanLinks[^;]+;)!/* UNUSED VARIABLE COMMENTED OUT BY $0: $1 */!;
    }

    $text = disable_local_variables ($text);
    $text = remove_typedefs ($text);

    print $out $text;
}

# Remove typedefs for "uint" and "ulong".

# This is due to Darwin not being supported:

# http://matrix.cpantesters.org/?dist=HTML-Valid%200.00_02

# and the typedefs for uint and ulong are not formed correctly for
# Darwin OS.

sub remove_typedefs
{
    my ($text) = @_;
    $text =~ s!(#\s*undef.*(?:uint|ulong))!/* COMMENTED OUT TYPEDEF by $0: $1 */!g;
    $text =~ s!(typedef.*(?:uint|ulong);)!/* COMMENTED OUT TYPEDEF by $0: $1 */!g;
    $text =~ s/\buint\b/unsigned int/g;
    $text =~ s/\bulong\b/unsigned int/g;
    return $text;
}


# Disable the "local variables:" declarations in the file so that
# Emacs doesn't keep printing questions about the "eval" in the Local
# variables section.

sub disable_local_variables
{
    my ($text) = @_;

    # The following regex was overkill, but I'm leaving it here,
    # commented out, in case it becomes necessary again.

    #    $text =~ s!/\*([^\*]|\*[^/])*local\s*variables:([^\*]|\*[^/])*\*+/!!gism;
    # This is enough to fool Emacs.

    $text =~ s!local\s*variables:!DISABLEDLOCALVARIABLES!gism;
    return $text;
}

sub write_include
{
    my ($out) = @_;
    print $out <<EOF;
#include "tidy-html5.h"
EOF
}

# Recursively copy the internal header files into our giant file.

sub write_internal_header_files
{
    my ($out, $hfiles) = @_;

    my %hfiles;

    # The header files without the directories.

    my @basehfiles;

    for my $file (@$hfiles) {
	my $basename = path ($file)->basename ();
	$hfiles{$basename} = {
	    orig => $file,
	    included => 0,
	};
	push @basehfiles, $basename;
    }

    msg ("Including header files");

    for my $hfile (@basehfiles) {
	include_h_file ($out, $hfile, \%hfiles, $verbose);
    }
}

# Recursive routine to copy header files.

sub include_h_file
{
    my ($out, $hfile, $hfiles, $verbose) = @_;
    if (! $hfiles->{$hfile}) {
	warn "Unknown local header file $hfile";
	return;
    }
    if ($hfiles->{$hfile}{included} eq 'ok') {
	msg ("$hfile is already included");
	return;
    }
    my $orig = $hfiles->{$hfile}{orig};

    msg ("Reading $orig");

    my $path = path ($orig);
    my $text = $path->slurp ();

    # Include all the previous includes into this file.

    while ($text =~ s!$include_local!/* $1 */!g) {
	my $dephfile = $2;
	if ($dephfile =~ /^tidy.*\.h$/ && $dephfile ne 'tidy-int.h') {
	    msg ("Not including <tidy*.h> file $dephfile");
	    next;
	}
	msg ("Including previous header file $dephfile before $hfile");
	if (! $hfiles->{$dephfile}) {
	    warn "Unknown local header file $dephfile";
	}
	else {
	    include_h_file ($out, $dephfile, $hfiles, $verbose);
	}
    }
    my $basename = $path->basename ();
    if ($line_directives) {
	line_directive ($out, 1, $basename);
    }
    $text = remove_typedefs ($text);
    print $out $text;
    $hfiles->{$hfiles}{included} = 'ok';
}

sub msg
{
    if (! $verbose) {
	return;
    }
    my (undef, $file, $line) = caller ();
    print "$file:$line: @_\n";
}
