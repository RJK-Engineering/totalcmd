=begin TML

---+ package TotalCmd::ButtonBar

=cut

package TotalCmd::ButtonBar;

use strict;
use warnings;

use File::Ini;

###############################################################################
=pod

---++ Object creation

---+++ new([$file]) -> TotalCmd::ButtonBar
Returns a new =TotalCmd::ButtonBar= object.
Opional path to bar =$file=.

=cut
###############################################################################

sub new {
    my $self = bless {}, shift;
    $self->{file} = shift;
    $self->{buttons} = [];
    return $self;
}

sub file {
    $_[0]->{file};
}

###############################################################################
=pod

---++ Object methods

---+++ addButton($self, $command, $iconFile, $iconNr, $iconic)
Add button.

---+++ write()
Write bar file.

=cut
###############################################################################

sub addButton {
    my ($self, $command) = @_;

    my $tooltip;
    if ($command->{shortcuts}) {
        $tooltip = "[$command->{shortcuts}] ";
        $tooltip .= $command->{menu} // "";
    }

    push @{$self->{buttons}}, {
        button => $command->{button} // "",
        cmd => $command->{cmd},
        param => $command->{param},
        path => $command->{path},
        iconic => $command->{iconic} || 0,
        menu => $command->{menu} || $tooltip,
    };
}

sub write {
    my ($self, $file) = @_;
    @{$self->{buttons}} || return;

    my $ini = new File::Ini($self->{file});
    my $section = 'Buttonbar';
    my @keys = qw(button cmd param path iconic menu);

    $ini->setHashList($section, $self->{buttons}, \@keys);
    $ini->prepend($section, 'Buttoncount', scalar @{$self->{buttons}});
    $ini->write($file);
}

1;
