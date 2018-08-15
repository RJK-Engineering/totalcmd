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
        print "File not found: $tcmdiniPath\n"
    } else {
        print "$_\n"
    }
    exit 1;
};
print "Loaded $ini->{path}\n";

my @colors = $ini->getColors;
foreach (@colors) {
    print "$_->{nr} $_->{Color} $_->{search}\n" if $opts{verbose};
}

my $i = 1;
open my $fh, '<', $opts{colors} or die "$!";
while (<$fh>) {
    my ($name, $hex) = /(\*?\w+)\s+#(\w{6})/;
    next unless $name;
    if ($opts{verbose}) {
        printf "ColorFilter%u=%s*\n", $i, $name;
        printf "ColorFilter%uColor=%u\n", $i++, hex($hex);
    }
    push @colors, { Color => hex($hex), search => $name };
}
close $fh;
