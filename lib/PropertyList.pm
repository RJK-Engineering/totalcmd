package PropertyList;

use strict;
use warnings;
use PropertyListCompareResult;

sub new {
    my $self = bless {}, shift;
    $self->{props} = shift // {};
    return $self;
}

sub hash {               $_[0]{props}  }
sub names {       keys %{$_[0]{props}} }
sub size { scalar keys %{$_[0]{props}} }
sub isEmpty {     keys %{$_[0]{props}} == 0 }
sub values {    values %{$_[0]{props}} }
sub clear {              $_[0]{props} = {} }

sub has {
    exists $_[0]{props}{$_[1]};
}

sub get {
    my $props = $_[0]{props};
    exists $props->{$_[1]} || return;
    return $props->{$_[1]};
}

sub set {
    my ($self, $prop, $val) = @_;
    $self->{props}{$prop} = $val;
}

sub remove {
    my ($self, $prop) = @_;
    delete $self->{props}{$prop};
}

sub update {
    my ($self, $props, %opts) = @_;
    $opts{overwrite} ||= sub {0};
    $opts{new} ||= sub {1};
    $opts{equal} ||= sub {};

    while (my ($p, $v) = each %$props) {
        my $ev = $self->{props}{$p};
        if (defined $ev) {
            if (defined $v && $ev eq $v) {
                $opts{equal}->($p, $v);
                next;
            } else {
                next unless $opts{overwrite}->($p, $v, $ev);
            }
        } else {
            next unless $opts{new}->($p, $v);
        }
        $self->{props}{$p} = $v;
    }
    return $self;
}

sub equals {
    my ($self, $props) = @_;

    while (my ($p, $v) = each %$props) {
        my $ev = $self->{props}{$p};
        if (defined $ev) {
            if (! defined $v || $ev ne $v) {
                return 0;
            }
        } else {
            return 0;
        }
    }
    return 1;
}

# compare(PropertyList, %opts)
sub compare {
    my ($left, $right, %opts) = @_;
    $opts{cmp} ||= sub { shift eq shift }; # compare function
    $opts{orderLeft}  ||= [ $left->names  ]; # processing order
    $opts{orderRight} ||= [ $right->names ];
    $opts{skip} ||= sub {};

    # create result object when wanted by caller
    my $res = $opts{result}; # result object provided
    if (! $res && defined wantarray) { # return value wanted
        $res = new PropertyListCompareResult();
    }

    # setup callbacks
    my @opts = qw(left right intersection equal unequal different);
    foreach my $opt (@opts) {
        my $sub = $opts{$opt} ||= sub {};
        # add push if result wanted
        if ($res) {
            $opts{$opt} = sub {
                push @{$res->{$opt}}, $_[0];
                $sub->(@_);
            }
        }
    }

    $left  = $left->{props};
    $right = $right->{props};
    foreach my $prop (@{$opts{orderLeft}}) {
        next if $opts{skip}->($prop);
        if (defined $right->{$prop}) {
            if ($opts{cmp}) {
                if ($opts{cmp}->($left->{$prop}, $right->{$prop})) {
                    $opts{equal}->($prop);
                } else {
                    $opts{unequal}->($prop);
                    $opts{different}->($prop);
                }
            }
            #~ $opts{union}->($prop);
            $opts{intersection}->($prop);
        } else {
            $opts{left}->($prop);
            #~ $opts{union}->($prop);
            #~ $opts{difference}->($prop);
            $opts{different}->($prop) if $opts{cmp};
        }
    }

    foreach my $prop (@{$opts{orderRight}}) {
        next if $opts{skip}->($prop);
        if (not defined $left->{$prop}) {
            $opts{right}->($prop);
            #~ $opts{union}->($prop);
            #~ $opts{difference}->($prop);
            $opts{different}->($prop) if $opts{cmp};
        }
    }

    return $res;
}

1;
