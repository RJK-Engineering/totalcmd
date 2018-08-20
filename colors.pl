use strict;
use warnings;

use Try::Tiny;

use TotalCmd::Utils qw(GetTotalCmdIni);

my $tcmdiniPath = shift;
my %opts = (
    verbose => 0,
    colors => 'colors.txt',
);

my $ini;
try {
    $ini = GetTotalCmdIni($tcmdiniPath);
} catch {
    if ($tcmdiniPath) {
        print "File not found: $tcmdiniPath\n";
    } else {
        print "$_\n";
    }
    exit 1;
};
print "Loaded $ini->{path}\n";

my @colors = $ini->getColors;
foreach (@colors) {
    print "$_->{nr} $_->{Color} $_->{Search}\n" if $opts{verbose};
}
print "Colors in INI file: " . scalar @colors . "\n";

my %searches = map { $_->{Search} => 1 } @colors;

my $i = 0;
open my $fh, '<', $opts{colors} or die "$!";
while (<$fh>) {
    my ($search, $hex) = /(\*?\w+)\s+#(\w{6})/;
    next unless $search;
    $i++;
    printf "%s %s\n", $hex, $search if $opts{verbose};
    push @colors, { Color => hex($hex), Search => $search } unless $searches{$search};
}
close $fh;

print "Colors in $opts{colors}: $i\n";

$ini->setColors(\@colors);

print "Type \"ok\" to write INI ...\n";
my $r = <STDIN>;
chomp $r;
if ($r eq "ok") {
    $ini->write;
    print "Written: $ini->{path}\n";
} else {
    print "Nothing written\n";
}
