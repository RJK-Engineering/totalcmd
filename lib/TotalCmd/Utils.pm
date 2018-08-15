=begin TML

---+ package TotalCmd::Utils
Total Commander utility functions.

=cut

package TotalCmd::Utils;

use strict;
use warnings;

use Exporter ();

use TotalCmd::Inc;
use TotalCmd::Ini;
use TotalCmd::UsercmdIni;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
    SendTCCommand
    SetTCPaths
    FindPath
    TempFile
    SetLeftRightPaths
    SetSourceTargetPaths
    GetTotalCmdInc
    GetTotalCmdIni
    GetUsercmdIni
);

###############################################################################
=pod

---++ SendTCCommand($commandName)
   * http://ahkscript.org - https://autohotkey.com
   * http://www.ghisler.ch/wiki/index.php/AutoHotkey:_Send_a_command_to_Total_Commander
   * =SendTCCommand.exe= cm_LoadSelectionFromClip
   * commands are listed in =totalcmd.inc=
   * =SendTCCommand.exe= needs to be in PATH environment variable.

=cut
###############################################################################

sub SendTCCommand {
    my ($cm) = @_;
    my $exe = 'SendTCCommand.exe';
    system $exe, $cm;
}

###############################################################################
=pod

---++ SetTCPaths($left, $right)

See topic "Command line parameters" in Total Commander help.

| /O   | If Total Commander is already running, activate it and pass the path(s) in the command line to that instance (overrides the settings in the configuration dialog to have multiple windows) ||
| /L=  | Set path in left window ||
| /R=  | Set path right window ||
| /T   | Opens the passed dir(s) in new tab(s). Now also works when Total Commander hasn't been open yet. ||
| /P=  | Sets the active panel at program start: /P=L left, /P=R right. Overrides wincmd.ini option ActiveRight=. ||
| /S=L | Start Lister directly, pass file name to it for viewing (requires full name including path). May include bookmark in html files, e.g. c:\test\test.html#bookmark ||
|      | Accepts additional parameters separated by a colon, e.g. /S=L:AT1C1250 ||
|      | A      | ANSI/Windows text |
|      | S      | ASCII/DOS text |
|      | V      | Variable width text |
|      | T1..T7 | View mode 1-7 (1: Text, 2: Binary, 3: Hex, 4: Multimedia, 5: HTML, 6:Unicode, 7: UTF-8) |
|      | C<nr>  | Codepage, e.g. C1251 for Cyrillic |
|      | N      | Auto-detect, but no multimedia or plugins allowed |
|      | P<x>   | As LAST parameter: Choose plugin, e.g. /S=L:Piclview for iclview plugin (As shown in Lister title) |

=cut
###############################################################################

sub SetTCPaths {
    my ($left, $right) = @_;
    my @args = ("totalcmd.exe", "/O", "/L=\"$left\"");
    push @args, "/R=\"$right\"" if $right;
    system @args;
}

###############################################################################
=pod

---++ FindPath(@paths)
Look in common locations with environment variable substitution.

=cut
###############################################################################

sub FindPath {
    my @paths = @_;
    my $path;
    foreach (@paths) {
        s|%(\w+)%|$ENV{$1}//''|ge;
        next unless -e;
        $path = $_;
        last;
    }
    return $path;
}

###############################################################################
=pod

---++ TempFile([$extension]) -> ($handle, $filename)
Returns =undef= for =$filename= if no file location can be found.
Returns =undef= for =$handle= if file can not be opened.
=$extension= defaults to "tmp".

=cut
###############################################################################

sub TempFile {
    my $extension = shift // "tmp";
    my $tempDir = FindPath('%TEMP%') || return;
    my $file;

    do {
        $file = "$tempDir/CMD";
        $file .= sprintf "%X", int rand(16) for 1..4;
        $file .= ".$extension";
    } while (-e $file);

    open (my $fh, '>', $file) || return (undef, $file);
    return ($fh, $file);
}

###############################################################################
=pod

---++ SetLeftRightPaths()

=cut
###############################################################################

sub SetLeftRightPaths {
    my ($l, $r) = @_;
    my @args = ("totalcmd", "/O");
    push @args, "/L=\"$l\"" if $l;
    push @args, "/L=\"$r\"" if $r;
    system @args;
}


###############################################################################
=pod

---++ SetSourceTargetPaths()

=cut
###############################################################################

sub SetSourceTargetPaths {
    my ($s, $t) = @_;
    my @args = ("totalcmd", "/O", "/S");
    push @args, "/L=\"$s\"" if $s;
    push @args, "/L=\"$t\"" if $t;
    #~ print "@args\n";
    system @args;
}

###############################################################################
=pod

---+++ GetTotalCmdInc([$path]) -> TotalCmd::Inc
Returns a =TotalCmd::Inc= singleton object for =$path=.
Loads =totalcmd.inc=, throws a =TotalCmd::Inc::Exception= on failure.

=cut
###############################################################################

my %tcmdinc;

sub GetTotalCmdInc {
    my $path = shift;
    return $tcmdinc{$path} if $tcmdinc{$path};

    $path = FindPath(
        $path // (),
        "%COMMANDER_PATH%/TOTALCMD.INC",
        "%LOCALAPPDATA%/TOTALCMD.INC",
        "%LOCALAPPDATA%/TotalCommander/TOTALCMD.INC",
    ) || throw TotalCmd::Inc::Exception("Can't find totalcmd.inc");

    # create object
    $tcmdinc{$path} = TotalCmd::Inc->new($path);
    # load data
    $tcmdinc{$path}->read()
        || throw TotalCmd::Inc::Exception("Error loading totalcmd.inc");
}


###############################################################################
=pod

---+++ GetTotalCmdIni([$path]) -> TotalCmd::Ini
Returns a =TotalCmd::Ini= singleton object for =$path=.
Tries to find =totalcmd.ini= if =$path= is undefined.
Loads =totalcmd.ini=, throws a =TotalCmd::Ini::Exception= on failure.

=cut
###############################################################################

my $tcmdini;

sub GetTotalCmdIni {
    my $path = shift;
    return $tcmdini if $tcmdini;

    $path = FindPath(
        $path // (),
        "%COMMANDER_INI%",
        "%APPDATA%/GHISLER/WINCMD.INI",
        "%USERPROFILE%/AppData/Roaming/GHISLER/WINCMD.INI",
        "%LOCALAPPDATA%/wincmd.ini",
        "%LOCALAPPDATA%/totalcmd.ini",
        "%LOCALAPPDATA%/TotalCommander/wincmd.ini",
        "%LOCALAPPDATA%/TotalCommander/totalcmd.ini",
    ) || throw TotalCmd::Ini::Exception("Can't find totalcmd.ini");

    # create object
    $tcmdini = TotalCmd::Ini->new($path);
    # load data
    $tcmdini->read()
        || throw TotalCmd::Ini::Exception("Error loading totalcmd.ini");
}

###############################################################################
=pod

---++ Object creation

---+++ new([$path]) -> TotalCmd::UsercmdIni
Returns a new =TotalCmd::UsercmdIni= object.

---+++ GetUsercmdIni([$path]) -> TotalCmd::UsercmdIni
Returns a =TotalCmd::UsercmdIni= singleton for =$path=.
Loads =usercmd.ini=, throws a =TotalCmd::UsercmdIni::Exception= on failure.

=cut
###############################################################################

my %usercmdini;

sub GetUsercmdIni {
    my $path = shift;
    return $usercmdini{$path} if $usercmdini{$path};

    $path = FindPath(
        $path // (),
        "%COMMANDER_PATH%/usercmd.ini",
        "%LOCALAPPDATA%/usercmd.ini",
        "%LOCALAPPDATA%/TotalCommander/usercmd.ini",
    ) || throw TotalCmd::UsercmdIni::Exception("Can't find usercmd.ini");

    # create object
    $usercmdini{$path} = TotalCmd::UsercmdIni->new($path);
    # load data
    $usercmdini{$path}->read()
        || throw TotalCmd::UsercmdIni::Exception("Error loading usercmd.ini");
}

1;
