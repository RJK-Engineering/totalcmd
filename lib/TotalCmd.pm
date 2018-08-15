=begin TML

---+ package TotalCmd

=cut

package TotalCmd;

use strict;
use warnings;

use Exception::Class (
    'Exception',
    'TotalCmd::Exception' =>
        { isa => 'Exception' },
    'TotalCmd::NotFoundException' =>
        { isa => 'TotalCmd::Exception' },
);

use Try::Tiny;

use TotalCmd::ButtonBar;
use TotalCmd::Utils qw(GetTotalCmdInc GetTotalCmdIni GetUsercmdIni);

###############################################################################
=pod

---++ Object attributes

Return object attribute value if called with no arguments, set object
attribute value and return the same value otherwise.

---+++ tcmdini([$tcmdini]) -> $tcmdini
=TotalCmd::Ini= object.
---+++ tcmdinc([$tcmdinc]) -> $tcmdinc
=TotalCmd::Inc= object.
---+++ usercmd([$usercmd]) -> $usercmd
=TotalCmd::UsercmdIni= object.

=cut
###############################################################################

use Class::AccessorMaker {
    tcmdini => undef,
    tcmdinc => undef,
    usercmd => undef,
}, "new_init";

my @barDirs;

###############################################################################
=pod

---++ Object creation

---+++ new(%attrs) -> $tcmd
Returns a new =TotalCmd= object.

=cut
###############################################################################

sub init {
    my $self = shift;

    $self->{_tcmdinc} = TotalCmd::Utils::GetTotalCmdInc($self->{tcmdinc});
    $self->{_tcmdini} = TotalCmd::Utils::GetTotalCmdIni($self->{tcmdini});
    $self->{_usercmd} = TotalCmd::Utils::GetUsercmdIni($self->{usercmd});

    SetBarDirs($ENV{COMMANDER_INI});
}

sub SetBarDirs {
    my @paths = @_;
    my @dirs;
    foreach (@paths) {
        next unless $_;
        if (-d) {
            s/\\*$//;       # remove trailing slashes
            push @dirs, $_;
            if (-d "$_\\bars") {
                push @dirs, "$_\\bars";
            }
        } else {
            s/\\[^\\]*$//;  # remove slashes and file portion
            if (-d) {
                push @dirs, $_;
                if (-d "$_\\bars") {
                    push @dirs, "$_\\bars";
                }
            }
        }
    }
    @barDirs = @dirs;
}

###############################################################################
=pod

---++ Commands

| *Command Source*    | *INI File [section]*   |
| User command        | usercmd.ini            |
| Start menu item     | totalcmd.ini [user]    |
| Directory menu item | totalcmd.ini [DirMenu] |
| Button              | bar file [Buttonbar]   |
| Internal            | -                      |

All methods return a single or an array of =TotalCmd::Command= objects.

---+++ getCommand($name) -> $command
Get command by name.
Throws =TotalCmd::NotFoundException= if command not found.

---+++ getNamedCommands() -> @commands or \@commands
Get UserCommands and Internal commands.

---+++ getCustomCommands() -> @commands or \@commands
Get StartMenuItems, DirMenuItems, UserCommands and Buttons.

---+++ getAllCommands() -> @commands or \@commands
Get StartMenuItems, DirMenuItems, UserCommands, Buttons and
internal commands.

=cut
###############################################################################

sub getCommand {
    my ($self, $name) = @_;
    my $cmd;
    if ($name =~ /^((?:(em)|(cm))_.*)/) {
        $cmd = $self->{_usercmd}->getCommandByName($1) if $2;
        $cmd = $self->{_tcmdinc}->getCommandByName($1) if $3;
    }
    return $cmd || throw TotalCmd::NotFoundException("Unknown command: $name");
}

sub getCustomCommands {
    my ($self) = @_;

    my @cmds = $self->getMenuItems('user');
    push @cmds, $self->getMenuItems('DirMenu');
    push @cmds, $self->getUserCommands;

    my @bars = $self->getButtonBars();
    foreach my $bar (@bars) {
        push @cmds, $self->getButtons($bar);
    }

    return wantarray ? @cmds : \@cmds;
}

sub getAllCommands {
    my ($self) = @_;

    my $cmds = $self->getCustomCommands;
    push @$cmds, @{$self->getInternalCommands};

    return wantarray ? @$cmds : $cmds;
}

###############################################################################
=pod

---+++ User commands

---++++ getUserCommand($nr) -> $command
Get user command.
Throws =TotalCmd::NotFoundException= if command not found.

---++++ getUserCommands() -> @commands or \@commands
Get user commands.

=cut
###############################################################################

sub getUserCommand {
    my ($self, $nr) = @_;
    $self->{_usercmd}->getCommand($nr)
        || throw TotalCmd::NotFoundException("Unknown command: $nr");
}

sub getUserCommands {
    shift->{_usercmd}->getCommands();
}

###############################################################################
=pod

---+++ Menu items

Two menus are available, "user" for the start menu,
"DirMenu" for the directory menu.

---++++ getMenuItem($menu, $nr) -> $command
Get menu item by item number.
Throws =TotalCmd::NotFoundException= if item not found.

---++++ getMenuItems($menu, [$submenuNr]) -> @commands or \@commands
Get menu items.
Get all items if =$item= is undefined.
Get root items if =$item= is =0=.
Throws =TotalCmd::Exception= if =$itemNr= is not a submenu.

---++++ getSubmenus($menu) -> @commands or \@commands
Get submenus.

---++++ saveMenu($menu, $items)
Throws =TotalCmd::Exception=.

=cut
###############################################################################

sub getMenuItem {
    my ($self, $menu, $number) = @_;
    $self->{_tcmdini}->getMenuItem($menu, $number)
        || throw TotalCmd::NotFoundException("Unknown command: $number");
}

sub getMenuItems {
    my ($self, $menu, $submenuNr) = @_;
    $self->{_tcmdini}->getMenuItems($menu, $submenuNr);
}

sub getSubmenus {
    my ($self, $menu) = @_;
    $self->{_tcmdini}->getSubmenus($menu);
}

sub saveMenu {
    my ($self, $menu, $items) = @_;
    $self->{_tcmdini}->setMenu($menu, $items);
    $self->{_tcmdini}->write("a.ini");
}

###############################################################################
=pod

---+++ Butons

See also: getButtonBars()

---++++ getButton($barName, $nr) -> $command
Throws =TotalCmd::NotFoundException= if bar or command not found.

---++++ getButtons($barName) -> @commands or \@commands
Throws =TotalCmd::NotFoundException= if bar not found.

=cut
###############################################################################

sub getButton {
    my ($self, $barName, $nr) = @_;
    return $self->getButtons($barName)->[$nr - 1]
        || throw TotalCmd::NotFoundException("Unknown command: $nr");
}

sub getButtons {
    my ($self, $barName) = @_;

    my $file;
    foreach (@barDirs) {
        my $path = "$_\\$barName.bar";
        if (-f $path) {
            $file = $path;
            last;
        }
    }
    $file || throw TotalCmd::NotFoundException("Unknown bar: $barName");

    my $ini = new File::Ini($file)->read;
    return $ini->getHashList(
        'Buttonbar', 'number', { source => "Button:$barName" }
    );
}

sub getAllButtons {
    my $self = shift;
    my @cmds;
    foreach my $bar (@{$self->getButtonBars}) {
        push @cmds, $self->getButtons($bar);
    }
    return wantarray ? @cmds : \@cmds;
}

###############################################################################
=pod

---++ Other methods

---+++ getCommandCategories() -> @names or \@names
Get command category names.

---+++ getShortcuts() -> ( $key => $commandName ) or { $key => $commandName }
Get shortcuts.

---+++ getCommandKeys() -> ( $commandName => \@keys  ) or { $commandName => \@keys  }
Get shortcuts.

---+++ getButtonBar([$name]) -> $buttonBar
Get new TotalCmd::ButtonBar, load =$name.bar= file if =$name= is specified.

---+++ getButtonBars() -> @names or \@names
Get button bar names.

=cut
###############################################################################

sub getCommandCategories {
    shift->{_tcmdinc}->categories();
}

sub getShortcuts {
    shift->{_tcmdini}->getShortcuts();
}

sub getCommandKeys {
    my ($self) = @_;
    my %shortcuts;
    while (my ($shortcut, $name) = each %{$self->getShortcuts}) {
        push @{$shortcuts{$name}}, $shortcut;
    }
    wantarray ? %shortcuts : \%shortcuts;
}

sub getButtonBar {
    my ($self, $name) = @_;
    $name || return new TotalCmd::ButtonBar();
    my $bar;
    @barDirs || die "No bar directories defined";
    foreach my $dir (@barDirs) {
        my $path = "$dir\\$name.bar";
        next unless -e $path;
        $bar = new TotalCmd::ButtonBar($path);
    }
    unless ($bar) {
        $barDirs[0] || die "Directory name missing";
        -d $barDirs[0] || die "Not a directory: $barDirs[0]";
        $bar = new TotalCmd::ButtonBar("$barDirs[0]\\$name.bar");
    }
    return $bar;
}

sub getButtonBars {
    my ($self) = @_;

    my @bars;
    foreach (@barDirs) {
        opendir(my $dh, $_)
            || throw TotalCmd::Exception("$_: $!");
        push @bars, (grep { s/\.bar$//i } readdir $dh);
    }

    return wantarray ? @bars : \@bars;
}

###############################################################################
=pod

---+++ Internal commands

---++++ getInternalCommand($nr) -> $command
Get internal command.
Throws =TotalCmd::NotFoundException= if command not found.

---++++ getCategoryName([$categoryNr]) -> $name
Get name of category =$categoryNr=.
Throws =TotalCmd::NotFoundException= if category not found.

---++++ getInternalCommands([$categoryNr]) -> @commands or \@commands
Get commands in category =$categoryNr= if defined.
Get all internal commands if =$categoryNr= is undefined.
Throws =TotalCmd::NotFoundException= if category not found.

=cut
###############################################################################

sub getInternalCommand {
    my ($self, $nr) = @_;
    $self->{_tcmdinc}->getCommand($nr)
        || throw TotalCmd::NotFoundException("Unknown command: $nr");
}

sub getCategoryName {
    my ($self, $categoryNr) = @_;
    my @cats = $self->{_tcmdinc}->categories();
    return $cats[$categoryNr-1]
        // throw TotalCmd::NotFoundException("Unknown category: $categoryNr");
}

sub getInternalCommands {
    my ($self, $categoryNr) = @_;
    my $c = $self->{_tcmdinc}->getCommands($categoryNr)
        // throw TotalCmd::NotFoundException("Unknown category: $categoryNr");
    return wantarray ? @$c : $c;
}

1;
