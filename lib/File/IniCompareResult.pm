package File::IniCompareResult;

use strict;
use warnings;
use PropertyListCompareResult;

use Class::AccessorMaker {
    sections => new PropertyListCompareResult(),
    properties => {}, # section => PropertyListCompareResult
};

1;
