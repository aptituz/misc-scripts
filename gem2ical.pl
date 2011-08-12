#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use File::Slurp;
use File::Basename;
use Getopt::Long;
use HTML::TagFilter;
use HTML::Entities;
use Data::Dumper;
use Data::ICal;
use Data::ICal::Entry::Event;
use Date::ICal;

my $progname = basename($0);
my $outfile = 'gem.ical';
my $debug = 1;

GetOptions(
    'd|debug' => \$debug,
    'o|outfile' => \$outfile,
);

my $trash_type_map = {
    'Hausmuell' => qr/Hausmüll/,
    'Gelber Sack' => qr/Leichtverpackungen/,
    'Papiermuell' => qr/Papier und Pappe/,
    'Biomuell' => qr/Bio-Abfälle/,
    'Sonderabholung' => qr/Sonderabholung/,
};

sub usage {
    print <<EOF
usage: $progname <filename>

extracts collect dates from a html dump of the
"GEM Mönchengladbach Müllabfuhrkalender"
EOF
}

if (not @ARGV) {
    print "$progname: missing filename\n";
    usage;
    exit(1);
}

my $file = shift @ARGV;
my $html;
eval {
    $html = read_file($file, )
} or die "$progname: unable to read `$file': $@";
$html = decode_entities($html);

# Initialize html filter
my $tf = HTML::TagFilter->new(
    strip_comments => 1,
);

# Parse html
$tf->parse($html);

# Create ical object
my $cal = Data::ICal->new();

# Search for collect dates
my @lines = split(/\n/, $tf->output);
my $current_context;
foreach (@lines) {
    next if /^$/;
    next if /^\s+$/;

    print "Processing line: $_\n" if $debug;
    # Test for a trash type
    foreach my $type (keys(%{$trash_type_map})) {
        if (/$trash_type_map->{$type}/) {
            $current_context = $type;
            print "Found new context: $current_context\n" if $debug;
        }
    }

    if (/([0-3][0-9].[0-1][0-9].[0-9]{4})/) {
        my ($day, $month, $year) = split(/\./, $1);
        print "Found new date: $1 ($current_context)\n" if $debug;
       
        my $dtstart = Date::ICal->new(
            year => $year,
            month => $month,
            day => $day,
            hour => 7
        );
        my $dtend = Date::ICal->new(
            year => $year,
            month => $month,
            day => $day,
            hour => 8
        );
        my $event = Data::ICal::Entry::Event->new();
        $event->add_properties(
            summary => $current_context,
            dtstart => $dtstart->ical,
            dtend => $dtend->ical,
        );
        $cal->add_entry($event);

    }
}

write_file($outfile, $cal->as_string) or die "unable to write ical file: $!";
