package PropertyListCompareResult;

use Class::AccessorMaker {
    left => [],         # left and ! right
    right => [],        # right and ! left

    #~ union => [],        # left or right
    intersection => [], # left and right
    #~ difference => [],   # left xor right

    # compared
    equal => [],        # (intersection) and equal
    unequal => [],      # (intersection) and unequal
    different => [],    # (difference) + (unequal)
};

sub hasDifferences { @{$_[0]->different} > 0 }
sub hasNoDifferences { @{$_[0]->different} == 0 }

1;
