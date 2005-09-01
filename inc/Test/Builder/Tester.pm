#line 1 "inc/Test/Builder/Tester.pm - /usr/local/share/perl/5.8.4/Test/Builder/Tester.pm"
package Test::Builder::Tester;

use strict;
use vars qw(@EXPORT $VERSION @ISA);
$VERSION = "1.01";

use Test::Builder;
use Symbol;
use Carp;

#line 47

####
# set up testing
####

my $t = Test::Builder->new;

###
# make us an exporter
###

use Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(test_out test_err test_fail test_diag test_test line_num);

# _export_to_level and import stolen directly from Test::More.  I am
# the king of cargo cult programming ;-)

# 5.004's Exporter doesn't have export_to_level.
sub _export_to_level
{
      my $pkg = shift;
      my $level = shift;
      (undef) = shift;                  # XXX redundant arg
      my $callpkg = caller($level);
      $pkg->export($callpkg, @_);
}

sub import {
    my $class = shift;
    my(@plan) = @_;

    my $caller = caller;

    $t->exported_to($caller);
    $t->plan(@plan);

    my @imports = ();
    foreach my $idx (0..$#plan) {
        if( $plan[$idx] eq 'import' ) {
            @imports = @{$plan[$idx+1]};
            last;
        }
    }

    __PACKAGE__->_export_to_level(1, __PACKAGE__, @imports);
}

###
# set up file handles
###

# create some private file handles
my $output_handle = gensym;
my $error_handle  = gensym;

# and tie them to this package
my $out = tie *$output_handle, "Test::Tester::Tie", "STDOUT";
my $err = tie *$error_handle,  "Test::Tester::Tie", "STDERR";

####
# exported functions
####

# for remembering that we're testing and where we're testing at
my $testing = 0;
my $testing_num;

# remembering where the file handles were originally connected
my $original_output_handle;
my $original_failure_handle;
my $original_todo_handle;

my $original_test_number;
my $original_harness_state;

my $original_harness_env;

# function that starts testing and redirects the filehandles for now
sub _start_testing
{
    # even if we're running under Test::Harness pretend we're not
    # for now.  This needed so Test::Builder doesn't add extra spaces
    $original_harness_env = $ENV{HARNESS_ACTIVE};
    $ENV{HARNESS_ACTIVE} = 0;

    # remember what the handles were set to
    $original_output_handle  = $t->output();
    $original_failure_handle = $t->failure_output();
    $original_todo_handle    = $t->todo_output();

    # switch out to our own handles
    $t->output($output_handle);
    $t->failure_output($error_handle);
    $t->todo_output($error_handle);

    # clear the expected list
    $out->reset();
    $err->reset();

    # remeber that we're testing
    $testing = 1;
    $testing_num = $t->current_test;
    $t->current_test(0);

    # look, we shouldn't do the ending stuff
    $t->no_ending(1);
}

#line 190

sub test_out(@)
{
    # do we need to do any setup?
    _start_testing() unless $testing;

    $out->expect(@_)
}

sub test_err(@)
{
    # do we need to do any setup?
    _start_testing() unless $testing;

    $err->expect(@_)
}

#line 231

sub test_fail
{
    # do we need to do any setup?
    _start_testing() unless $testing;

    # work out what line we should be on
    my ($package, $filename, $line) = caller;
    $line = $line + (shift() || 0); # prevent warnings

    # expect that on stderr
    $err->expect("#     Failed test ($0 at line $line)");
}

#line 274

sub test_diag
{
    # do we need to do any setup?
    _start_testing() unless $testing;

    # expect the same thing, but prepended with "#     "
    local $_;
    $err->expect(map {"# $_"} @_)
}

#line 323

sub test_test
{
   # decode the arguements as described in the pod
   my $mess;
   my %args;
   if (@_ == 1)
     { $mess = shift }
   else
   {
     %args = @_;
     $mess = $args{name} if exists($args{name});
     $mess = $args{title} if exists($args{title});
     $mess = $args{label} if exists($args{label});
   }

    # er, are we testing?
    croak "Not testing.  You must declare output with a test function first."
	unless $testing;

    # okay, reconnect the test suite back to the saved handles
    $t->output($original_output_handle);
    $t->failure_output($original_failure_handle);
    $t->todo_output($original_todo_handle);

    # restore the test no, etc, back to the original point
    $t->current_test($testing_num);
    $testing = 0;

    # re-enable the original setting of the harness
    $ENV{HARNESS_ACTIVE} = $original_harness_env;

    # check the output we've stashed
    unless ($t->ok(    ($args{skip_out} || $out->check)
                    && ($args{skip_err} || $err->check),
                   $mess))
    {
      # print out the diagnostic information about why this
      # test failed

      local $_;

      $t->diag(map {"$_\n"} $out->complaint)
	unless $args{skip_out} || $out->check;

      $t->diag(map {"$_\n"} $err->complaint)
	unless $args{skip_err} || $err->check;
    }
}

#line 384

sub line_num
{
    my ($package, $filename, $line) = caller;
    return $line + (shift() || 0); # prevent warnings
}

#line 432

my $color;
sub color
{
  $color = shift if @_;
  $color;
}

#line 481

1;

####################################################################
# Helper class that is used to remember expected and received data

package Test::Tester::Tie;

##
# add line(s) to be expected

sub expect
{
    my $self = shift;
    $self->[2] .= join '', map { "$_\n" } @_;
}

##
# return true iff the expected data matches the got data

sub check
{
    my $self = shift;

    # turn off warnings as these might be undef
    local $^W = 0;

    $self->[1] eq $self->[2];
}

##
# a complaint message about the inputs not matching (to be
# used for debugging messages)

sub complaint
{
    my $self = shift;
    my ($type, $got, $wanted) = @$self;

    # are we running in colour mode?
    if (Test::Builder::Tester::color)
    {
      # get color
      eval "require Term::ANSIColor";
      unless ($@)
      {
	# colours

	my $green = Term::ANSIColor::color("black").
	            Term::ANSIColor::color("on_green");
        my $red   = Term::ANSIColor::color("black").
                    Term::ANSIColor::color("on_red");
	my $reset = Term::ANSIColor::color("reset");

	# work out where the two strings start to differ
	my $char = 0;
	$char++ while substr($got, $char, 1) eq substr($wanted, $char, 1);

	# get the start string and the two end strings
	my $start     = $green . substr($wanted, 0,   $char);
	my $gotend    = $red   . substr($got   , $char) . $reset;
	my $wantedend = $red   . substr($wanted, $char) . $reset;

	# make the start turn green on and off
	$start =~ s/\n/$reset\n$green/g;

	# make the ends turn red on and off
	$gotend    =~ s/\n/$reset\n$red/g;
	$wantedend =~ s/\n/$reset\n$red/g;

	# rebuild the strings
	$got    = $start . $gotend;
	$wanted = $start . $wantedend;
      }
    }

    return "$type is:\n" .
           "$got\nnot:\n$wanted\nas expected"
}

##
# forget all expected and got data

sub reset
{
    my $self = shift;
    @$self = ($self->[0]);
}

###
# tie interface
###

sub PRINT  {
    my $self = shift;
    $self->[1] .= join '', @_;
}

sub TIEHANDLE {
    my $class = shift;
    my $self = [shift()];
    return bless $self, $class;
}

sub READ {}
sub READLINE {}
sub GETC {}
sub FILENO {}

1;
