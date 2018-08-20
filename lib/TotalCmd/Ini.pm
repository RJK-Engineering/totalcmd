=begin TML

---+ package TotalCmd::Ini
Total Commander INI file functionality.

---++ INI sections

---+++ History (numbered)

<verbatim>
[Command line history]
[MkDirHistory] names of created dirs
[RightHistory] rhs path
[LeftHistory] lhs path
[SearchName] file search "Search for"
[SearchIn] file search "Search in"
[SearchText] general search (Ctrl+F / F3)
[Selection] file selection
[RenameTemplates] multi-rename "Rename mask: file name"
[RenameSearchFind] multi-rename "Search for"
[RenameSearchReplace] multi-rename "Replace with"
</verbatim>

---+++ Saved settings (not all)

<verbatim>
[searches] search settings
    [name]_SearchFor, [name]_SearchIn, [name]_SearchText, [name]_SearchFlags
[rename] rename settings
    [name]_name, [name]_ext, [name]_search, [name]_replace, [name]_params
[CustomFields] custom columns
    Widths[i], Headers[i], Contents[i], Options[i],
[Colors] (saved search name, color)
    ColorFilter[i], ColorFilter[i]Color
</verbatim>

---+++ Menu

Submenus start with =menu[i]=-[name]= and end with =menu[i]=--=.

<verbatim>
[user] start menu
    menu[i], cmd[i], param[i], path[i], key[i]
[DirMenu] directory hotlist
    menu[i], cmd[i]
</verbatim>

---+++ Other

<verbatim>
[1024x600 (8x16)]
[1024x768 (8x16)]
[1152x864 (8x16)]
[1280x1024 (8x16)]
[1280x800 (8x16)]
[1366x768 (8x16)]
[1600x1200 (8x16)]
[640x480 (8x16)]
[800x600 (8x16)]

[left]
[right]
[lefttabs]
[righttabs]

[ContentPlugins]
[FileSystemPlugins]
[Lister]
[ListerPlugins]
[Packer]
[PackerPlugins]

[Associations]
[Buttonbar]
[Configuration]
[Confirmation]
[General]
[Layout]
[PrintDir]
[Shortcuts]
[SplitPerFile]
[Tabstops]
[TweakWC]
</verbatim>

=cut

package TotalCmd::Ini;

use v5.16; # enables fc feature
use strict;
use warnings;

use File::Ini;
use TotalCmd::Search;

use Exception::Class (
    'Exception',
    'TotalCmd::Exception' =>
        { isa => 'Exception' },
    'TotalCmd::Ini::Exception' =>
        { isa => 'TotalCmd::Exception' },
    'TotalCmd::Ini::SubmenuException' =>
        { isa => 'TotalCmd::Ini::Exception' },
);

my $UserMenuNumberStart = 700;

###############################################################################
=pod

---++ Constructor

---+++ new($path) -> TotalCmd::Ini
Returns a new =TotalCmd::Ini= object.

=cut
###############################################################################

sub new {
    my $self = bless {}, shift;
    $self->{path} = shift;
    $self->{ini} = new File::Ini($self->{path});
    $self->{searches} = {};          # name => Search
    return $self;
}

###############################################################################
=pod

---++ INI file

---+++ read([$path]) -> TotalCmd::Ini
Read data from file. Returns false on failure, callee on success.

---+++ write([$path]) -> TotalCmd::Ini
Write data to file. Returns false on failure, callee on succes.

=cut
###############################################################################

sub read {
    my $self = shift;
    $self->{ini}->read(shift);

    # $self->_loadSearches();

    return $self;
}

sub write {
    my $self = shift;
    return $self if $self->{ini}->write(shift);
}

###############################################################################
=pod

---++ Menu items

Two menus are available, "user" for the start menu,
"DirMenu" for the directory menu.

---+++ getMenuItem($nr) -> $command
Get menu item by item number.

---+++ getMenuItems([$submenuNr]) -> @commands or \@commands
Get menu items.
Get all items if =$submenuNr= is undefined.
Get root items if =$submenuNr= is =0=.

---+++ getSubmenus($menu) -> @commands or \@commands
Get submenus.

---+++ _getSubmenu($items, $itemNr) -> @commands or \@commands
Get submenu items.
Get root items if =$item= is =0=.
Throws =TotalCmd::Ini::SubmenuException= if =$itemNr= is not a submenu.

=cut
###############################################################################

sub getMenuItem {
    my ($self, $menu, $number) = @_;
    my $items = $self->getMenuItems($menu);
    return $items->[$number-1];
}

sub getMenuItems {
    my ($self, $menu, $submenuNr) = @_;
    my @items = $self->{ini}->getHashList($menu, {
        key => 'number',
        defaultHash => { source => $menu eq 'user' ? 'StartMenu' : $menu },
    });
    if (defined $submenuNr) {
        @items = $self->_getSubmenu(\@items, $submenuNr);
    }
    return wantarray ? @items : \@items;
}

sub getSubmenus {
    my ($self, $menu) = @_;
    my @items;
    foreach (@{$self->getMenuItems($menu)}) {
        push @items, $_ if $_->{menu} =~ /^-[^-]/;
    }
    return wantarray ? @items : \@items;
}

sub _getSubmenu {
    my ($self, $items, $itemNr) = @_;
    if ($itemNr) {
        $items->[$itemNr-1] &&
            $items->[$itemNr-1]->{menu} =~ /^-[^-]/
            || throw TotalCmd::Ini::SubmenuException("Not a submenu");

        $items = [ @$items[$itemNr..@$items-1] ];
    }

    my @items;
    while (my $o = shift @$items) {
        if ($o->{menu} =~ /^--$/) {         # submenu end
            last;
        } elsif ($o->{menu} =~ /^-(.*)/) {  # submenu start
            push @items, $o;
            $self->_getSubmenu($items);
        } else {
            push @items, $o;
        }
    }
    return @items;
}

sub setMenu {
    my ($self, $menu, $items) = @_;
    $self->{ini}->setHashList($menu, $items, [qw(menu cmd param path key)]);
}

###############################################################################
=pod

---++ INI Sections

---+++ getSection($section) -> %hash or \%hash

---+++ getShortcuts() -> %shortcuts or \%shortcuts
Get =$keyCombo => $commandName= hash.

---++++ getColors() -> \@colors
=@colors= - List of { Color => $color, Search => $search }

---++++ setColors(\@colors) -> $self
=@colors= - List of { Color => $color, Search => $search }
=$self= - This TotalCmd::Ini object

=cut
###############################################################################

sub getSection {
    my ($self, $section) = @_;
    return $self->{ini}->getSection($section);
}

sub getShortcuts {
    my ($self) = @_;
    my $shortcuts = $self->{ini}->getSection('Shortcuts');
    return wantarray ? %$shortcuts : $shortcuts;
}

sub getColors {
    my ($self, $otherProps) = @_;
    return $self->{ini}->getHashListRHS("Colors", {
        key => "nr",
        name => "ColorFilter",
        defaultKey => "Search",
        otherProps => $otherProps,
    });
}

sub setColors {
    my ($self, $colors) = @_;

    my (%otherProps, @keys);
    $self->{ini}->getHashListRHS("Colors", {
        name => "ColorFilter",
        otherProps => \%otherProps,
        otherPropsKeys => \@keys,
    });

    $self->{ini}->clearSection("Colors");
    foreach (@keys) {
        $self->{ini}->set("Colors", $_, $otherProps{$_});
    }

    my $i = 1;
    foreach (@$colors) {
        $self->{ini}->set("Colors", "ColorFilter${i}", $_->{Search});
        $self->{ini}->set("Colors", "ColorFilter${i}Color", $_->{Color});
    } continue {
        $i++;
    }

    return $self;
}

###############################################################################
=pod

---+++ history($section) -> @history or \@history
---+++ addToHistory($section, $text) -> ProperyList
---+++ searches() -> %searches or \%searches
---+++ nonSpecialSearches() -> @searches
List of non special searches sorted by name.
---+++ getSearch($name) -> TotalCmd::Search
---+++ fileTypes() -> @types or \@types
---+++ getFileTypes($filename) -> @types or \@types
---+++ matchFileType($type, $filename) -> $boolean
---+++ inCategory($filename, $category) -> $boolean
---+++ _loadSearches()
---+++ report()

=cut
###############################################################################

sub history {
    my ($self, $section) = @_;
    $self->{ini}->getList($section);
}

sub addToHistory {
    my ($self, $section, $text) = @_;
    my $h = $self->{ini}->getList($section);

    pop @$h;
    unshift @$h, $text;
    $self->{ini}->setList($section, $h);
}

sub searches {
    my $self = shift;
    return wantarray ?
        values %{$self->{searches}} : $self->{searches};
}

sub searchNames {
    my $self = shift;
    return keys %{$self->{searches}};
}

sub nonSpecialSearches {
    my $self = shift;
    return
        map { $self->{searches}{$_} }
        sort { fc $a cmp fc $b }
        grep { ! /^(?:attr|category|dirs|type):/ }
        keys %{$self->{searches}};
}

sub getSearch {
    my ($self, $name) = @_;
    return $self->{searches}{$name};
}

sub fileTypes {
    my $self = shift;
    return @TotalCmd::Search::fileTypes;
}

sub getFileTypes {
    my ($self, $filename) = @_;
    return TotalCmd::Search::GetFileTypes($filename);
}

sub matchFileType {
    my ($self, $type, $filename) = @_;
    my $types = $self->getFileTypes($filename);
    return grep { $_ eq $type } @$types;
}

sub inCategory {
    my ($self, $filename, $category) = @_;
    my $types = $self->getFileTypes($filename);
    foreach (@$types) {
        return 1 if $self->{categoryIdx}{$category}{$_};
    }
    return 0;
}

sub _loadSearches {
    my $self = shift;
    my %s = $self->{ini}->getHashes('searches', { key => 'name' });
    foreach (values %s) {
        $self->{searches}{$_->{name}} = new TotalCmd::Search(%$_);
    }
}

sub report {
    my $self = shift;
    local $, =  " ";
    print scalar keys %{$self->{fileTypeIdxByExt}}, " extensions\n";
    print sort keys %{$self->{fileTypeIdxByExt}}, "\n";
    print scalar keys %{$self->{fileTypeIdxByName}}, " filenames\n";
    print sort keys %{$self->{fileTypeIdxByName}}, "\n";
}

1;
