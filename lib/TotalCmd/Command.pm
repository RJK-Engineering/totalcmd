=begin TML

---+ package TotalCmd::Command
A Total Commander command.

---++ Example

<verbatim>
use TotalCmd::Command;
use Try::Tiny;

my $cmd = new TotalCmd::Command(
    menu => "Name",
    cmd => "cmd",
    param => "/c dir %P%N",
);

try {
    $cmd->execute(
        {
            source => "C:\\",
            target => undef,
            sourceSelection => [],
            targetSelection => [],
        },
        sub {
            my $args = shift;
            printf "%s %s\n", $cmd->cmd, $args;
            system "$cmd->{cmd} $args";
        }
    );
} catch {
    if ( $_->isa('TotalCmd::Command::UnsupportedParameterException') ) {
        warn sprintf "Unsupported parameter: %s", $_->parameter();
    } elsif ( $_->isa('TotalCmd::Command::ListFileException') ) {
        warn sprintf "%s: %s", $_->error, $_->path();
    } elsif ( $_->isa('TotalCmd::Command::NoFileException') ) {
        warn sprintf "%s: %s", $_->error, $_->path();
    } elsif ( $_->isa('TotalCmd::Command::NoShortNameException') ) {
        warn sprintf "%s: %s", $_->error, $_->path();
    } elsif ( $_->isa('TotalCmd::Command::Exception') ) {
        warn $_->error(). ".";
    } else {
        die $_;
    }
};
</verbatim>

=cut

package TotalCmd::Command;

use strict;
use warnings;

use File::Spec::Functions qw(rel2abs splitpath catpath);
use TotalCmd::Utils; # qw(TempFile);
use Win32; # qw(GetShortPathName);

use Exception::Class (
    'Exception',
    'TotalCmd::Command::Exception' =>
        { isa => 'Exception' },
    'TotalCmd::Command::UnsupportedParameterException' =>
        { isa => 'TotalCmd::Command::Exception',
          fields => ['parameter'] },
    'TotalCmd::Command::InsufficientDataException' =>
        { isa => 'TotalCmd::Command::Exception' },
    'TotalCmd::Command::ListFileException' =>
        { isa => 'TotalCmd::Command::Exception',
          fields => ['path'] },

    'TotalCmd::Command::NoSourceException' =>
        { isa => 'TotalCmd::Command::InsufficientDataException' },
    'TotalCmd::Command::NoTargetException' =>
        { isa => 'TotalCmd::Command::InsufficientDataException' },

    'TotalCmd::Command::NoFileException' =>
        { isa => 'TotalCmd::Command::InsufficientDataException',
          fields => ['path'] },
    'TotalCmd::Command::NoSourceFileException' =>
        { isa => 'TotalCmd::Command::NoFileException' },
    'TotalCmd::Command::NoTargetFileException' =>
        { isa => 'TotalCmd::Command::NoFileException' },

    'TotalCmd::Command::NoShortNameException' =>
        { isa => 'TotalCmd::Command::InsufficientDataException',
          fields => ['path'] },
    'TotalCmd::Command::NoSourceShortNameException' =>
        { isa => 'TotalCmd::Command::NoShortNameException' },
    'TotalCmd::Command::NoTargetShortNameException' =>
        { isa => 'TotalCmd::Command::NoShortNameException' },

    'TotalCmd::Command::NoSelectionException' =>
        { isa => 'TotalCmd::Command::InsufficientDataException' },
    'TotalCmd::Command::NoSourceSelectionException' =>
        { isa => 'TotalCmd::Command::NoSelectionException' },
    'TotalCmd::Command::NoTargetSelectionException' =>
        { isa => 'TotalCmd::Command::NoSelectionException' },
);

###############################################################################
=pod

---++ Object creation

---+++ new(%attrs) -> TotalCmd::Command

---++ Object attributes

Return object attribute value if called with no arguments, set object
attribute value and return the same value otherwise.

---+++ name($name) -> $name

Name (=cm_*=, =em_*=).

---+++ number($number) -> $number

Number (=totalcmd.inc=).

---+++ button([$button]) -> $button
Icon resource string.
Format:
First icon  = "filename",
second icon = "filename,1"
(icon numbers start at 0)

---+++ cmd([$cmd]) -> $cmd
Command string.

---+++ param([$param]) -> $param
Parameter string.

---+++ path([$path]) -> $path
Start path.

---+++ iconic([$iconic]) -> $iconic
Window size: 1 = minimize, -1 = maximize.

---+++ menu([$menu]) -> $menu
Description/tooltip/title.

---+++ key([$key]) -> $key
Shortcut key defined with a command.

---+++ shortcuts([\@shortcuts]) -> \@shortcuts
Shortcut keys defined in Options > Misc.

=cut
###############################################################################

use Class::AccessorMaker {
    source => undef,    # Inc/StartMenu/DirMenu/User/Button
    name => undef,      # name (cm_*, em*)
    number => undef,    # number (totalcmd.inc)
    button => undef,    # icon
                        # first icon  = "filename"
                        # second icon = "filename,1"
                        # (icon numbers start at 0)
    cmd => undef,       # command
    param => undef,     # parameters
    path => undef,      # start path
    iconic => undef,    # 1 = minimize, -1 = maximize
    menu => undef,      # description/tooltip/title
    key => undef,       # shortcut key (command config)
    shortcuts => [],    # shortcut keys (Options > Misc)
};

my $directoryParams = 'PpTt';
my $filenameParams = 'NnMm';
my $fileParams = $filenameParams. 'OoEe';
my $shortParams = 'ptnmoesr';

my $sourceParams = 'PpNnOoEe';
my $targetParams = 'TtMm';
my $listFileParams = 'LlFfDd';
my $sourceArgsParams = 'Ss';
my $targetArgsParams = 'Rr';
my $argsParams = $sourceArgsParams.$targetArgsParams;
my $allParams = $sourceParams.$targetParams.$listFileParams.$argsParams;
my $modifierParams = 'ZzX';

###############################################################################
=pod

---++ Other object methods

---+++ execute($opts, $callback)
Calls =$callback= with command arguments after parameter substitution
using =$opts=.
Throws whatever =getParams()= throws.

=cut
###############################################################################

sub execute {
    my ($self, $opts, $callback) = @_;

    if ($self->{param}) {
        my $params = $self->getParams($opts);
        my $argStr = $self->getArgStr($params);
        $callback->($argStr);
        $self->finish($params);
    } else {
        $callback->("");
    }
}

###############################################################################
=pod

---+++ getParams($opts) -> \%params
Get parameter values.

Throws:%BR%
(additional =[[https://metacpan.org/pod/Exception::Class][Exception::Class]]= fields between parenthesis)
   * =TotalCmd::Command::Exception=
      * =TotalCmd::Command::UnsupportedParameterException= (parameter)
      * =TotalCmd::Command::ListFileException= (path)
      * =TotalCmd::Command::InsufficientDataException=
         * =TotalCmd::Command::NoSourceException=
         * =TotalCmd::Command::NoTargetException=
         * =TotalCmd::Command::NoFileException= (path)
            * =TotalCmd::Command::NoSourceFileException=
            * =TotalCmd::Command::NoTargetFileException=
         * =TotalCmd::Command::NoShortNameException= (path)
            * =TotalCmd::Command::NoSourceShortNameException=
            * =TotalCmd::Command::NoTargetShortNameException=
         * =TotalCmd::Command::NoSelectionException=
            * =TotalCmd::Command::NoSourceSelectionException=
            * =TotalCmd::Command::NoTargetSelectionException=

=cut
###############################################################################

sub getParams {
    my ($self, $opts) = @_;
    my %params;

    if ($self->{param} && $self->{param} =~ /%/) {
        if ($self->{param} =~ /[^%]%([^%$allParams$modifierParams])/) {
            throw TotalCmd::Command::UnsupportedParameterException(
                error => "Unsupported parameter: $1",
                parameter => $1,
            );
        }
    } else {
        return \%params;
    }

    # under cursor
    my $source = $opts->{source} // $opts->{sourceSelection}[0];
    my $target = $opts->{target} // $opts->{targetSelection}[0];

    # selections in list files
    $params{sourceListFile} = $opts->{sourceList};
    $params{targetListFile} = $opts->{targetList};

    # source parameters
    my ($long, $short, $dir, $file, $name, $extension);
    if ($self->{param} =~ /%[$sourceParams]/) {
        if (defined $source) {
            ($source, $short) = GetPaths($source);
            ($dir, $file, $name, $extension) = ParsePath($source);

            $params{P} = $dir;
            if ($file ne '') {
                $params{N} = $file;
                $params{O} = $name;
                $params{E} = $extension;
            } elsif ($self->{param} =~ /%[$fileParams]/) {
                throw TotalCmd::Command::NoSourceFileException(
                    error => "No source file specified",
                    path => $source,
                );
            }

            if ($short) {
                ($dir, $file, $name, $extension) = ParsePath($short);
                $params{p} = $dir;
                if ($file ne '') {
                    $params{n} = $file;
                    $params{o} = $name;
                    $params{e} = $extension;
                }
            } elsif ($self->{param} =~ /%[$shortParams]/) {
                throw TotalCmd::Command::NoSourceShortNameException(
                    error => "Source short name could not be determined",
                    path => $source,
                );
            }
        } else {
            throw TotalCmd::Command::NoSourceException("No source specified");
        }
    }

    # source selection as list file parameters
    if (my $listType = ($self->{param} =~ /%([$listFileParams])/)) {
        if ($opts->{sourceList}) {
            # load list file
            #~ $params{sourceListFile}, @{$opts->{sourceSelection}} = loadList($opts->{sourceList});
        } elsif ($opts->{sourceSelection}) {
            # create list file
            my $fh;
            ($fh, $params{sourceListFile}) = TotalCmd::Utils::TempFile();
            if ($fh) {
                print $fh "$_\n" foreach @{$opts->{sourceSelection}};
                close $fh;
            } elsif (defined $params{sourceListFile}) {
                throw TotalCmd::Command::ListFileException(
                    error => "Could not create temp list file",
                    path => $params{sourceListFile},
                );
            } else {
                throw TotalCmd::Command::Exception(
                    error => "Could not get temp list file path",
                );
            }
        } else {
            throw TotalCmd::Command::NoSourceSelectionException(
                "No source selection specified");
        }

        if ($params{sourceListFile}) {
            $params{$_} = $params{sourceListFile} foreach split //, $listFileParams;
        }
    }

    # source selection as arguments parameters
    if ($self->{param} =~ /%[$sourceArgsParams]/) {
        if ($opts->{sourceSelection}) {
            foreach (@{$opts->{sourceSelection}}) {
                ($long, $short) = GetPaths($_);
                ($dir, $file) = ParsePath($long);

                push @{$params{S}},
                    defined $params{P} && $dir ne $params{P} ?
                        "$params{P}$file" : $file;

                if ($short) {
                    ($dir, $file) = ParsePath($short);
                    push @{$params{s}},
                        defined $params{p} && $dir ne $params{p} ?
                            "$params{p}$file" : $file;
                } elsif ($self->{param} =~ /%[$shortParams]/) {
                    throw TotalCmd::Command::NoSourceShortNameException(
                        error => "Source short name could not be determined",
                        path => $_,
                    );
                }
            }
        } else {
            throw TotalCmd::Command::NoSourceSelectionException(
                "No source selection specified");
        }
    }

    # target selection as arguments parameters
    if ($self->{param} =~ /%[$targetArgsParams]/) {
        if ($opts->{targetSelection}) {
            foreach (@{$opts->{targetSelection}}) {
                ($long, $short) = GetPaths($_);
                ($dir, $file) = ParsePath($long);

                push @{$params{R}},
                    defined $params{T} && $dir ne $params{T} ?
                        "$params{T}$file" : $file;

                if ($short) {
                    ($dir, $file) = ParsePath($short);
                    push @{$params{r}},
                        defined $params{t} && $dir ne $params{t} ?
                            "$params{t}$file" : $file;
                } elsif ($self->{param} =~ /%[$shortParams]/) {
                    throw TotalCmd::Command::NoTargetShortNameException(
                        error => "Target short name could not be determined",
                        path => $_,
                    );
                }
            }
        } else {
            throw TotalCmd::Command::NoTargetSelectionException(
                "No target selection specified");
        }
    }

    # target parameters
    if ($self->{param} =~ /%[$targetParams]/) {
        # second argument is target if no list param
        $target //= shift @ARGV if $self->{param} !~ /%[$listFileParams$sourceArgsParams]/;

        if (defined $target) {
            ($target, $short) = GetPaths($target);
            ($dir, $file) = ParsePath($target);

            $params{T} = $dir;
            if ($file ne '') {
                $params{M} = $file;
            } elsif ($self->{param} =~ /%[$fileParams]/) {
                throw TotalCmd::Command::NoTargetFileException(
                    error => "No target file specified",
                    path => $source,
                );
            }

            if ($short) {
                ($dir, $file) = ParsePath($short);
                $params{t} = $dir;
                $params{m} = $file if $file ne '';
            } elsif ($self->{param} =~ /%[$shortParams]/) {
                throw TotalCmd::Command::NoTargetShortNameException(
                    error => "Target short name could not be determined",
                    path => $source,
                );
            }
        } else {
            throw TotalCmd::Command::NoTargetException("No target specified");
        }
    }

    return \%params;
}

###############################################################################
=pod

---+++ getArgStr($params) -> $argString
Returns parameter string with parameters substituted which can be
used for command execution.

=cut
###############################################################################

sub getArgStr {
    my ($self, $params) = @_;

    my $quote = sub {
        $_[0] =~ /\s/ ? qq("$_[0]") : $_[0];
    };

    my $s = "";
    my $param = $self->{param};

    while ($param =~ s/
        (?<text> .*?) %
        (?:
              (?<dir1>  [$directoryParams]) % (?<file1> [$filenameParams])
            | (?<dir2>  [$directoryParams]) % (?<args1> [$argsParams])
            |           [$modifierParams]   % (?<dir3>  [$directoryParams])
            | (?<file2> [$filenameParams])
            | (?<args2> [$argsParams])
            | (?<any>   [$allParams])
            | (?<pct>   %)
            | (?<other> .)
        ) //x
    ) {
        $s .= $+{text};
        if ($+{dir1}) {
            $s .= $quote->($params->{$+{dir1}}. $params->{$+{file1}});
        } elsif ($+{dir2}) {
            my $dir = $params->{$+{dir2}};
            my $files = $params->{$+{args1}};
            $s .= join " ", map { $quote->($dir. $_) } @$files;
        } elsif ($+{dir3}) {
            $s .= $params->{$+{dir3}};
        } elsif ($+{file2}) {
            $s .= $quote->($params->{$+{file2}});
        } elsif ($+{args2}) {
            my $files = $params->{$+{args2}};
            $s .= join " ", map { $quote->($_) } @$files;
        } elsif ($+{any}) {
            $s .= $params->{$+{any}};
        } elsif ($+{pct}) {
            $s .= '%';
        } else {
            throw TotalCmd::Command::UnsupportedParameterException($+{other});
        }
    }
    return $s. $param;
}

###############################################################################
=pod

---+++ finish($params)
Removes temp files.

=cut
###############################################################################

sub finish {
    my ($self, $params) = @_;
    if ($params->{sourceListFile}) {
        unlink $params->{sourceListFile}
        ||
        throw TotalCmd::Command::ListFileException(
            error => "$!",
            path => $params->{sourceListFile},
        );
    }
}

###############################################################################
=pod

---++ Class methods

---+++ GetPaths($path) -> ($longPath, $shortPath)
Returns absolute long and short path names. Converts a relative path
to an absolute path and makes sure a directory name ends with a =\=.

=cut
###############################################################################

sub GetPaths {
    my $isDir = $_[0] =~ /[\/\\]$/;
    my $long = rel2abs($_[0]);
    my $short = Win32::GetShortPathName($long);
    if ($isDir || -d $long) {
        $long .= "\\";
        $short .= "\\";
    }
    return ($long, $short);
}

###############################################################################
=pod

---+++ ParsePath($path) -> ($dir, $file, $name, $extension)
   * =$path= - full path to a file or a directory
   * =$dir= - full path to directory part
   * =$file= - filename part
   * =$name= - filename without extension
   * =$extension= - filename extension

=cut
###############################################################################

sub ParsePath {
    my ($volume, $directories, $file) = splitpath($_[0]);
    my $dir = catpath($volume, $directories, '');
    my ($name, $extension) = ($file =~ /^(.+)\.([^\.]+)$/);
    $name //= $file;
    $extension //= '';
    return ($dir, $file, $name, $extension);
}

1;
