# Python_Unpickler.pm - parse Python cPickle format data
#
# Copyright (C) 2002, IronPort Systems.  All rights reserved.
# $Revision: 1.2 $

package Python_Unpickler;


# due reference to the following:
#   the first part is adapted from the python distro 'marshal.c'
#   the second part is adapted from the python distro 'pickle.py'

use IO::Handle '_IONBF';
use IO::String ;

my $STACK_MARKER = "~PRIVATE_MARK~";
$NONE = "~NONE~";
$USPT = "~UNSUPPORTED~";

# ~~ Broken: This should be using BigNum package ~~
sub to_bignum 
{
	my $s=shift; 
	return $USPT; 
}

sub append 
{
	my $self = shift;
	my @rest = @_;
	push @{$self->{STACK}}, @rest;
}

my %DFMT = 
	( '(' => 'stack-insert-mark',
	  '.' => 'exception',
	  '0' => 'stack-pop',
	  '1' => 'stack-pop-till-mark',
	  '2' => 'stack-dup-top',
	  'I' => 'read-asc-integer',
	  'J' => 'read-bin-int32',
	  'K' => 'read-bin-int8',
	  'M' => 'read-bin-int16',
	  'L' => 'read-asc-long',
	  'F' => 'read-asc-float', 
	  'G' => 'read-bin-float',
	  'N' => 'dummy-None',
	  'S' => 'read-asc-string',
	  'T' => 'read-bin-string-long',
	  'U' => 'read-bin-string-short',
	  'P' => 'read-persistent (broken)',
	  'Q' => 'read-bin-persistent (broken)',
	  'd' => 'stack-to-hashtable',
	  '}' => 'stack-insert-empty-hashtable',
	  'g' => 'read-get-int',
	  'h' => 'read-bin-get-int8',
	  'j' => 'read-bin-get-int32',
	  'l' => 'stack-to-list',
	  ']' => 'stack-to-empty-list',
	  'p' => 'stack-put-int',
	  'q' => 'stack-put-bin-int8',
	  'r' => 'stack-put-bin-int32',
	  't' => 'stack-to-tuple',
	  ')' => 'stack-to-empty-tuple',
	  's' => 'stack-set-hash-elem',
	  'u' => 'stack-set-hash-elem-list',
	  'V' => 'stack-read-unicode-16',
	  'X' => 'stack-read-utf-8',
	  'a' => 'stack-set-list-elem',
	  'e' => 'stack-set-list-elem-list',
	  'c' => 'read-global-value (broken)',
	  'b' => 'read-build-object (partial)',
	  'o' => 'read-object (partial)',
	  'R' => 'stack-reduce-elems (broken)', 
	  'i' => 'read-instance (partial)', 
	  );

sub get_marker_position
{
	my $self = shift;

	# local vars
	my $pos = $#{$self->{STACK}};
	
	# find the marker, assumes marker is in stack.
	while ($self->{STACK}->[$pos] ne $STACK_MARKER && $pos >= 0) { $pos--; }
	return $pos;
}

sub p_read_integer
{
	my $self = shift;
	my $line = $self->p__read_line();
	$self->append($line)
}

sub p_read_binary_int8
{
	my $self = shift;
	my $val = $self->p__read_byte();
	$self->append($val);
}

sub p_read_binary_int16
{
	my $self = shift;
	my $short = $self->p__read_short();
	$self->append($short);
}

sub p_read_binary_int32
{
	my $self = shift;
	my $val = $self->p__read_long();
	$self->append($val);
}

sub p_read_long
{
	my $self = shift;
	my $line = $self->p__read_line();
	$self->append($line)
}

sub p_read_get
{
	my $self = shift;
	my $loc = $self->p__read_line();
	my $val = $self->{MEMO}->[$loc];
	$self->append($val);
}

sub p_read_put
{
	my $self = shift;
	my $loc = $self->p__read_line();
	my $val = $self->p_stack_pop();
	$self->{MEMO}->[$loc] = $val;
	$self->append($val);
}

sub p_read_binary_get8
{
	my $self = shift;
	my $loc = $self->p__read_byte();
	my $val = $self->{MEMO}->[$loc];
	$self->append($val);
}

sub p_read_binary_put8
{
	my $self = shift;
	my $loc = $self->p__read_byte();
	my $val = $self->p_stack_pop();
	$self->{MEMO}->[$loc] = $val;
	$self->append($val);
}

sub p_read_binary_get32
{
	my $self = shift;
	my $loc = $self->p__read_long();
	my $val = $self->{MEMO}->[$loc];
	$self->append($val);
}


sub p_read_binary_put32
{
	my $self = shift;
	my $loc = $self->p__read_long();
	my $val = $self->p_stack_pop();
	$self->{MEMO}->[$loc] = $val;
	$self->append($val);
}

sub p_read_string
{
	my $self = shift;
	my $line = $self->p__read_line();

	if ($line =~ /^([\'\"])(.*)\1$/) { $line = $2; }
	# print ".. Appending line $line\n";
	$self->append($line);
}

sub p_read_binary_string
{
	# print "BINARY_STRING\n";
	my $self = shift;
	my $word = $self->p__read_long();
	# print "Word is $word\n";
	my $string = $self->p__read_string($word);
	$self->append($string);
}

sub p_read_short_binary_string
{
	# print "SHORT_BINARY_STRING\n";
	my $self = shift;
	my $val = $self->p__read_byte();
	my $string = $self->p__read_string($val);
	$self->append($string);
}

sub p_read_float
{
	my $self = shift;
	my $line = $self->p__read_line();
	$self->append($line)
}

sub p_read_binary_float
{
	my $self = shift;
	my $double = $self->p__read_double();
	# printf "Double is $double or %f \n", $double;
	$self->append($double)
}

sub p_stack_pop
{
	my $self = shift;
	my $val = pop @{$self->{STACK}};
	return $val;
}

sub p_stack_pop_mark
{
	my $self = shift;
	my $mark_pos = $self->get_marker_position();
	my @tail = splice @{$self->{STACK}}, $mark_pos;
	shift @tail;
	return \@tail;
}

sub p_stack_dup
{
	my $self = shift;
	my $ssize = $#{$self->{STACK}};
	my $end = $self->{STACK}->[$ssize];

	$self->append($end);
}

sub p_stack_pop_exception
{
	my $self = shift;
	my $val = p_stack_pop();
	$self->{STOP} = 1;
	$self->{STOP_VAL} = $val;
}

sub p_stack_set_marker
{
	my $self = shift;
	$self->append($STACK_MARKER);
}

sub p_stack_set_none
{
	my $self = shift;
	$self->append($NONE);
}

# not supported?
sub p_read_perid
{
	my $self = shift;
	my $pid_asc = $self->p__read_line();
	# Broken: pid_asc should be finnessed into an object
	$self->append($pid_asc);
}

sub p_read_binary_perid
{
	my $self = shift;
	my $pid = $self->p_stack_pop();
	# Broken: pid should be finnessed into an object
	$self->append($pid);
}

sub p_read_unicode
{
	# print "READ UNICODE\n";
	my $self = shift;
	my $u16_string = $self->p__read_line();
	$self->append($u16_string);
}

sub p_read_utf8
{
	# print "READ UTF\n";
	my $self = shift;
	my $word = $self->p__read_long();
	my $utf_string = $self->p__read_string($word);
	$self->append($utf_string);
}

sub p_stack_set_empty_list
{
	my $self = shift;
	my @arr;
	$self->append(\@arr);
}

sub p_stack_set_empty_hash
{
	my $self = shift;
	my %hash;
	$self->append(\%hash);
}

sub p_stack_to_list
{
	my $self = shift;
	my $mark_pos = $self->get_marker_position();

	my $tref = $self->p_stack_pop_mark();
	$self->{STACK}->[$mark_pos] = $tref;
}

sub p_stack_to_hash
{
	my $self = shift;
	my $mark_pos = $self->get_marker_position();
	my %hash;
	my ($idx, $key, $val);

	my @tail = splice @{$self->{STACK}}, $mark_pos;
	shift @tail;

	my $item_count = $#tail;
	for ($idx = 0; $idx < $item_count; $idx += 2) {
		$key = $tail[$idx];
		$val = $tail[$idx+1];
		$hash{$key} = $val;
	}

	$self->append(\%hash);
}

sub p_stack_set_dict_item
{
	my $self = shift;
	my $val = $self->p_stack_pop();
	my $key = $self->p_stack_pop();
	my $href = $self->p_stack_pop();

	$href->{$key} = $val;
	$self->append($href);
}

sub p_stack_set_dict_items
{
	my ($idx, $key, $val, $tlen);

	my $self = shift;
	my $mark_pos = $self->get_marker_position();
	my $href = $self->{STACK}->[$mark_pos - 1];
	my @tail = splice @{$self->{STACK}}, $mark_pos;
	shift @tail;

	$tlen = $#tail;
	for ($idx = 0; $idx < $tlen; $idx += 2) {
		$key = $tail[$idx];
		$val = $tail[$idx+1];
	}
}

sub p_stack_set_list_item
{
	my $self = shift;
	my $val = $self->p_stack_pop();
	my $arr = $self->p_stack_pop();

	push @$arr, $val;
	$self->append($arr);
}

sub p_stack_set_list_items
{
	my $self = shift;
	my $mark_pos = $self->get_marker_position();
	my $arr = $self->{STACK}->[$mark_pos - 1];
	my @tail = splice @{$self->{STACK}}, $mark_pos;
	shift @tail;
	my $val;

	foreach $val (@tail) {
		push @$arr, $val;
	}
}

sub p_read_global
{
	my $self = shift;
	my $mod = $self->p__read_line();
	my $nam = $self->p__read_line();
	my $cls = {};
	$cls->{'__type__'} = 'CLASS';
	$cls->{'__scope__'} = 'GLOBAL';
	$cls->{'__module__'} = $mod;
	$cls->{'__name__'} = $nam;

	$self->append($cls);
}

sub p_stack_set_build
{
	my $self = shift;
	my $arr = $self->p_stack_pop();
	my $object = $self->p_stack_pop();
	my ($key, $val, $idx);
	
	my $alen = $#{$arr};
	for ($idx = 0; $idx < $alen; $idx += 2)
	{
		$key = $arr->[$idx];
		$val = $arr->[$idx+1];
		$object->{'__dict__'}->{$key} = $val;
	}

	$self->append($object);
}

sub p_stack_set_object
{
	my $self = shift;
	my $mark_pos = $self->get_marker_position();

	my ($junk, $cls, @args) = splice @{$self->{STACK}}, $mark_pos;
	my %obj = 
		( '__dict__' => {},
		  '__args__' => \@args,
		  '__class__' => $cls,
		  '__type__' => 'OBJECT',
		  '__scope__' => $cls->{'__scope__'},  # not quite sure about this.
		  );

	$self->append(\%obj);
}

sub p_stack_reduce
{
	my $self = shift;
	my $args = $self->p_stack_pop();
	my $func = $self->p_stack_pop();
	unshift @$args, $func;
	$self->append($args);
}

sub p_stack_set_instance
{
	my $self = shift;
	my $mark_pos = $self->get_marker_position();
	my ($junk, @args) = splice @{$self->{STACK}}, $mark_pos;

	my $mod = $self->p__read_line();
	my $nam = $self->p__read_line();
	my $cls = "unimplemented: $mod/$nam";

	my %obj = 
		( '__dict__' => {},
		  '__args__' => \@args,
		  '__class__' => $cls,
		  '__module__' => $mod,
		  );

	$self->append(\%obj);
}

sub p__read_line
{
	my $self = shift;
	my $str = $self->{HANDLE}->getline();
	chomp($str);
	return $str;
}

sub p__read
{
	my $self = shift;
	my $bytes = shift;
	my $ret;
	$self->{HANDLE}->read($ret, $bytes);
	return $ret;
}

sub p__read_string
{
	my $self = shift;
	my $bytes = shift;
	$self->{HANDLE}->read($tmp, $bytes);
	return $tmp;
}

sub p__read_char
{
	my $self = shift;
	my $str = $self->p__read(1);
	return $str;
}

sub p__read_signed_byte
{
	my $self = shift;
	my $byte = $self->p__read(1);
	my $val = unpack("c", $byte);
	return $val;
}

sub p__read_byte
{
	my $self = shift;
	my $byte = $self->p__read(1);
	my $val = unpack("C", $byte);
	return $val;
}

sub p__read_short
{
	my $self = shift;
	my $short = $self->p__read(2);
	my $val = unpack("v", $short);
	return $val;
}

sub p__read_long
{
	my $self = shift;
	my $word = $self->p__read(4);
	my ($d, $c, $b, $a) = unpack("C4", $word);
	return $a << 24 | $b << 16 | $c << 8 | $d;
}

sub p__read_double
{
	my $self = shift;
	my $str = $self->p__read(8);
	
	my @bytes = unpack("C*", $str);
	my ($sign, $exp) = (0, 0);
	my ($fhi, $flo) = (0.0, 0.0);
	my $res;

	$sign = ($bytes[0] >> 7) & 0x01;
	$exp  = ($bytes[0] & 0x7F) << 4;
	$exp |= ($bytes[1] >> 4) & 0x0F;

	$fhi  = ($bytes[1] & 0x0F) << 24;
	$fhi |= ($bytes[2] & 0xFF) << 16;
	$fhi |= ($bytes[3] & 0xFF) << 8;
	$fhi |= ($bytes[4] & 0xFF);

	$flo  = ($bytes[5] & 0xFF) << 16;
	$flo |= ($bytes[7] & 0xFF) << 8;
	$flo |= ($bytes[8] & 0xFF);

	$res = $fhi + ($flo / 16777216.0);
	$res /= 268435456.0;

	if ($exp == 0) { $exp = -1022; }
	else           { $res += 1.0; $exp -= 1023; }

	$res = $res * (2**$exp);
	if ($sign) { $res = -$res;}

	# printf "Floating value is %f\n", $res;
	return  $res;
}

sub clear 
{
	$self = shift;
	# $self->{HANDLE}->close()
	delete $self->{HANDLE};
	delete $self->{STACK};
	delete $self->{MSTREAM};
	delete $self->{STOP};
	delete $self->{STOP_VAL};

	$self->{INDEX} = 0;
	$self->{MSTREAM} = [];
	$self->{STACK} = [];
	$self->{MEMO} = [];
}

sub unpickle_string 
{
	my $self = shift;
	my $string = shift;

	$self->clear();
	$self->{HANDLE} = new IO::String($string);
	$self->{HANDLE}->setvbuf("", _IONBF ,0);
	$self->p_read_stream();
	$self->{HANDLE}->close();
	return $self->{STACK};
}

sub unpickle_file 
{
	my $self = shift;
	my $fname = shift;

	$self->clear();
	$self->{HANDLE} = new IO::File;
	$self->{HANDLE}->open("< $fname");
	$self->{HANDLE}->setvbuf("", _IONBF ,0);
	$self->p_read_stream();
	$self->{HANDLE}->close();
	return $self->{STACK};
}

sub new 
{
	my $proto = shift;
	my $class = ref ($proto) || $proto;

	$self->{MSTREAM} = [];
	$self->{STACK} = [];
	$self->{INDEX} = 0;

	bless $self, $class;
	return $self;
}

# pickle formats
my %PFMT = 
	( '(' => \&p_stack_set_marker,
	  '.' => \&p_stack_pop_exception,
	  '0' => \&p_stack_pop,
	  '1' => \&p_stack_pop_mark,
	  '2' => \&p_stack_dup,
	  'I' => \&p_read_integer,
	  'J' => \&p_read_binary_int32,
	  'K' => \&p_read_binary_int8,
	  'M' => \&p_read_binary_int16,
	  'L' => \&p_read_long,
	  'F' => \&p_read_float,
	  'G' => \&p_read_binary_float,
	  'N' => \&p_stack_set_none,
	  'S' => \&p_read_string,
	  'T' => \&p_read_binary_string,
	  'U' => \&p_read_short_binary_string,
	  'P' => \&p_read_perid,             # does not work:
	  'Q' => \&p_read_binary_perid,      # does not work?
	  'd' => \&p_stack_to_hash,
	  '}' => \&p_stack_set_empty_hash,
	  'g' => \&p_read_get,
	  'h' => \&p_read_binary_get8,
	  'j' => \&p_read_binary_get32,
	  'l' => \&p_stack_to_list,
	  ']' => \&p_stack_set_empty_list,
	  'p' => \&p_read_put,
	  'q' => \&p_read_binary_put8,
	  'r' => \&p_read_binary_put32,
	  't' => \&p_stack_to_list,
	  ')' => \&p_stack_set_empty_list,
	  's' => \&p_stack_set_dict_item,
	  'u' => \&p_stack_set_dict_items,
	  'V' => \&p_read_unicode,
	  'X' => \&p_read_utf8,
	  'a' => \&p_stack_set_list_item,
	  'e' => \&p_stack_set_list_items,
	  'c' => \&p_read_global,            # unsupported
	  'b' => \&p_stack_set_build,        # [mostly] unsupported
	  'o' => \&p_stack_set_object,       # [mostly] unsupported
	  'R' => \&p_stack_reduce,           # unsupported
	  'i' => \&p_stack_set_instance,     # [mostly] unsupported
	                                     # 'I01' => TRUE,
	                                     # 'I00' => FALSE,
	  );

sub p_read_stream
{
	my $self = shift;
	my $char;

	while (1) {
		$self->{INDEX} ++;
		$char = $self->p__read_char();

		if (defined $PFMT{$char}) { 
			# print $self->{INDEX}, ". ", $char, " => ", $DFMT{$char}, "\n";
			&{$PFMT{$char}}($self)
		}
		else { last; }
	}
}

# package Main;
# use String::Multibyte;

sub dump_table
{
	my $href = shift;

	print "The table contains:\n";
	foreach my $key (keys %$href) {
		print " $key => ", $href->{$key}, "\n";
	}
}

sub dump_array
{
	my $arr = shift;
	my $old = $,;

	$, = ", ";
	print "The array contains: ";
	print @$arr;
	print "\n";
	$, = $old;
}

sub test1
{
	my $up = new Python_Unpickler();
	my $up2 = new Python_Unpickler();

	# A ascii integers
	my $test_string = "I123456\nI23\nI12\n";
	my $J = $up->unpickle_string($test_string);
	dump_array($J);

	# B binary integers
	my $test_string2 = pack("aNanaCaC", 
							'J', 12345, 
							'M', 123,
							'K', 12,
							'K', 255);
	my $K = $up2->unpickle_string($test_string2);
	dump_array($K);

	# C floating point numbers
	my $test_string3 = "F12.232432234\n" . pack("ad", 'G', 12.29793279);
	my $L = $up2->unpickle_string($test_string3);
	dump_array($L);
}

sub test2
{
	my $up = new Python_Unpickler();

	# D put,binput,get,binget
	#   'put' reads an int and places the next element from the
	#   stack into that position in the memo array.  'get' reads
	#   position from the memory array and places that elemn on 
	#   the stack.
	#   
	#   Place three ints on stack, and reverse them ...

	#  put three elems on stack
	my $test_string  = "I123456\nI23\nI12\n";
	#  remove from stack and place on memo board
	my $place_memo   = "p0\n0" . pack("aCaaNa", 'q', 1, '0', 'r', 2, '0');
	my $replace_memo = "g0\n" . pack("aCaN", 'h', 1, 'j', 2);

	my $string = $test_string . $place_memo . $replace_memo;

	my $M = $up->unpickle_string($string);
	my $N = $up->unpickle_string($test_string);
	dump_array($N);
	dump_array($M);
}

# test dup, mark
sub test3
{
	my $up = new Python_Unpickler();
	my $s1  = "I0\n22(I12\n22222";
	my $s2  = $s1 . "1";

	my $T = $up->unpickle_string($s1);
	my $U = $up->unpickle_string($s2);
	dump_array($T);
	dump_array($U);

	my $s3  = "I14\n(I123456\n222l]";
	my $V = $up->unpickle_string($s3);
	dump_array($V);

	my $s4  = "I14\n(I123456\n222t)";
	my $W = $up->unpickle_string($s4);
	dump_array($W);
}

# list elem and list-elems
sub test4
{
	my $up = new Python_Unpickler();

	my $s1 = "]I1\naI2\na";
	my $A = $up->unpickle_string($s1);
	dump_array($A->[0]);
	# 1 2

	my $s2 = "](I1\nI2\nI3\nI4\nI5\ne";
	my $B = $up->unpickle_string($s2);
	dump_array($B);
	dump_array($B->[0]);
	# 1 2 2 2 5

	my $h1 = "}I1\nI2\nsI3\nI4\ns";
	my $C = $up->unpickle_string($h1);
	dump_table($C->[0]);

	my $h2 = "}(I1\nI2\nI3\nI4\nI5\nI6\nu";
	my $D = $up->unpickle_string($h2);
	dump_table($D->[0]);

	my $h3 = "}(I1\nI2\nI3\nI4\nI5\nI6\nd";
	my $E = $up->unpickle_string($h3);
	dump_table($E->[0]);
	dump_table($E->[1]);
}

sub test5
{

	my $up = new Python_Unpickler();

	my $s1 = "SAlphabet soup\nSsing-song\nNSCheese\n";
	my $A = $up->unpickle_string($s1);
	dump_array($A);

	my $str = "abcdefghijklmnopstuvwyz";
	my $len = length $str;
	my $s2 = 'T' . pack "Na" . $len, $len, $str;
	my $B = $up->unpickle_string($s2);
	dump_array($B);

	$str = "abcdef";
	$len = length $str;
	my $s3 = 'U' . pack "Ca" . $len, $len, $str;
	my $C = $up->unpickle_string($s3);
	dump_array($C);

	my $nb = pack ("x");
	my $u16 = $nb . join ($nb, split //, "1234567890");
	print "u16 is $u16 len is ", length $u16, "\n";
	my $D = $up->unpickle_string("V$u16\n");
	dump_array($D);
	print ". Len is ", length $D->[0], "\n";

	my $raw="\xc3\xa1s\xc3\xa1bcc\xc3\xa7a\xc3\xa1\xc3\xa0auu"
		. "\xc3\xa1\xc3\xa4\xc3\x9c";
	my $rln = length $raw;
	my $code = pack("aNa${rln}", 'X', $rln, $raw);
	my $E = $up->unpickle_string($code);
	
	if ($raw eq $E->[0]) {
		print "UTF test okay.\n";
	} else {
		my $el = length $E->[0];
		print "Raw len is $rln\n";
		print "UTF recovered len is $el\n";
	}

}

# broken items
sub test6
{
	# persistent ident stuff.
	my $up = new Python_Unpickler();
	my $pasc = "P123456\n";  # try to load persid '123456'
	my $pbin = "I123456\nQ"; # try to load persid from stack top.
	my $ar = $up->unpickle_string($pasc . $pbin);
	dump_array($ar);

	# global class stuff.
	my $gtxt = "cmodule\nname\n";
	$ar = $up->unpickle_string($gtxt);
	dump_array($ar);
	dump_table($ar->[0]);

	# object stuff
	my $args = "](I1\nI2\nI3\nI4\nI5\ne";
	my $otxt = "(" . $gtxt . $args . "o";
	my $ar2 = $up->unpickle_string($otxt);
	dump_array($ar2);
	dump_table($ar2->[0]);

	# build object continued ...
	my $elems= "](Sname1\nSval1\nSname2\nSval2\ne";
	my $btxt = $otxt . $elems . "b";
	my $ar3 = $up->unpickle_string($btxt);
	dump_array($ar3);
	dump_table($ar3->[0]);
	dump_table($ar3->[0]->{'__dict__'});

	# inst object ...
	my $elist= "(Sarg1\nSarg2\nSarg3\nSarg4\n";
	my $itxt = "SFirst Elem\n" 
		. $elist . 'i'
		. "Module\n"
		. "Name\n"
		. "SThird Elem\n";
	my $ar4 = $up->unpickle_string($itxt);
	dump_array($ar4);
	dump_table($ar4->[1]);
	dump_array($ar4->[1]->{'__args__'});

	# reduce ...
	my $reduce = "Sshould be a callable\n" . $elems . "R";
	my $ar5 = $up->unpickle_string($reduce);
	dump_array($ar5->[0]);
	
}

sub test7
{
    # create test using python to produce test input ...
    # 
    # import pickle, sys
    # P = pickle.Pickler(sys.stdout, True);
    # P.save_int(12345)
    # P.save_int(1234567890)
    # P.save_float(1.23)
	
	my ($txt, $ar, $val);
	my $up = new Python_Unpickler();

	# 12345
	$txt = "M90";
	$ar = $up->unpickle_string($txt);
	$val = $ar->[0];
	# save_int() {short-method}  12345
	if ($val == 12345) { printf "Test 7.1 passes\n"; }
	else               { printf "Test 7.1 fails, val is %x\n", $val; }

	# save_int() 1234567890
	$txt = pack ("s*", 0xd24a, 0x9602, 0x0049);
	$ar = $up->unpickle_string($txt);
	$val = $ar->[0];
	if ($val == 1234567890) { printf "Test 7.2 passes\n"; }
	else                    { printf "Test 7.2 fails, val is %x\n", $val; }
	# dump_array($ar);

	# save_float() 1.23
	$txt = pack ("s*", 0x3f47, 0xaef3, 0x7a14, 0x47e1, 0x00ae);
	$ar = $up->unpickle_string($txt);
	$val = $ar->[0];
	my $t1 = sprintf("%f", 1.23);
	my $t2 = sprintf("%f", $val);

	if ($t1 eq $t2) { printf "Test 7.3 passes\n"; }
	else            { printf "Test 7.3 fails, val is %f\n ($t1, $t2)", $val; }
}

sub test8
{
	my ($txt, $ar, $val);
	my $up = new Python_Unpickler();

	$txt = pack("s*", 
      0x4a28, 0x8890, 0x3db4, 0x934d, 0x4d50, 0x0387, 0x324d, 0x4b26,
      0x5500, 0x751b, 0x6573, 0x3172, 0x3332, 0x7740, 0x6d75, 0x7570,
      0x2e73, 0x7269, 0x6e6f, 0x6f70, 0x7472, 0x632e, 0x6d6f, 0x0171,
      0x1c55, 0x2e35, 0x2e31, 0x2032, 0x202d, 0x6142, 0x2064, 0x6564,
      0x7473, 0x6e69, 0x7461, 0x6f69, 0x206e, 0x6f68, 0x7473, 0x0271,
      0x0355, 0x3030, 0x7130, 0x5d03, 0x0471, 0x715d, 0x2805, 0x004b,
      0x1855, 0x3639, 0x3635, 0x7740, 0x6d75, 0x7570, 0x2e73, 0x7269,
	  0x6e6f, 0x6f70, 0x7472, 0x632e, 0x6d6f, 0x0671, 0x004b, 0x6174);
      # 0x7174, 0x2e07);

	$ar = $up->unpickle_string($txt);
	dump_array($ar);
	dump_array($ar->[8]);
	dump_array($ar->[9]);
	dump_array($ar->[10]);
	dump_array($ar->[11]);
}

sub test9
{
	my ($txt, $ar, $val);
	my $up = new Python_Unpickler();

	$txt = pack ("s*", 0x904a, 0xffff, 0x00ff);
	$ar = $up->unpickle_string($txt);
	dump_array($ar);
}

# test7();
test8();
# test9();

1;
