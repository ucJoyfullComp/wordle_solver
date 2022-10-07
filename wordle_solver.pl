#!/usr/bin/env perl

use strict;
use warnings;
use English;


## n number : specify the number of letters in candidate word
## lp letter place : specify candidate has to have the letter at place
## ln letter : specify candidate must not have letter in word
## lz letter place : specify candidate must have letter anywhere but place

my $path_to_dictionary = "wordl_dict";
my $handle;
unless(open $handle, "<:encoding(utf8)", $path_to_dictionary) {
	print STDERR "could not open file '$path_to_dictionary': $!\n";
	# we return 'undefined', we could also 'die' or 'croak'
	return undef
}

chomp(my @words = <$handle>);

unless (close $handle) {
	# what does it mean if close yields an error and you are jest reading?
	print STDERR "Don't care error while closing '$path_to_dictionary': $!\n";
}

my $nchars;
my @myregex;

my $chars = "abcdefghijklmnopqrstuvwxyz";
my @tuck = $chars =~ /./sg;
my %map;
my $val = 0;
foreach my $key (@tuck) {
	$map{$key} = $val++;
}
my $nullchar = chr(ord('z')+1);

my @patterns;
my @localARGV = @ARGV;
my ($numn, $numlp, $numlz, $numln) = (0,0,0,0);

## filter words according to number of characters
for my $argidx (reverse 0..$#localARGV) {
	my @cmd = $localARGV[$argidx] =~ /./sg;
	my $params;
	if ($cmd[0] eq 'n') {
		if ($numn >= 1) {
			print STDERR "error: invalid number of parameters in CLI\n";
			print STDERR "\tcmds.pl n# [lpNC] [lnC...] [lzNC]\n";
			print STDERR "\t\tlp, ln, lz commands can repeat with limitations\n";
			exit(1);
		}
		my $n = int($cmd[1]);
		$nchars = $n;
		$numn++;
		my @temp;
		foreach my $word (@words) {
			if (length($word) == $n) {
				push @temp, $word;
			}
		}
		@words = @temp;
		undef @temp;
		for (my $i=0; $i<$n; $i++) {
			my @temp = $chars =~ /./sg;
			push @patterns, [ @temp ];
		}
		splice(@localARGV, $argidx, 1);
	}
}

## filter words according to specific letter has to be in word 
##  but must not be at the specified place.
foreach my $argidx (reverse 0..$#localARGV) {
	my @cmd = $localARGV[$argidx] =~ /./sg;
	my $params;
	if ($cmd[0] eq 'l') {
		if ($cmd[1] eq 'z') {
			my $patt;
			my @lzpat;
			my $place = int($cmd[2]);
			for my $idx (1..$nchars) {
				my @tstr;
				for my $iidx (1..$nchars) {
					$tstr[$iidx-1] = ".";
					if ($iidx == $place) {
						$tstr[$iidx-1] = "[^$cmd[3]]";
					}
				}
				if ($idx != $place) {
					$tstr[$idx-1] = "$cmd[3]";
					push @lzpat, join('', @tstr);
				}
			}
			$patt = join '|', @lzpat;
			push @myregex, $patt;
			splice(@localARGV, $argidx, 1);
		}
	}
}

## filter words according to specific letter has to be in specific location
foreach my $argidx (reverse 0..$#localARGV) {
	my @cmd = $localARGV[$argidx] =~ /./sg;
	my $params;
	if ($cmd[0] eq 'l') {
		if ($cmd[1] eq 'p') {
			$params = substr($localARGV[$argidx], 2);
			print("word must contain place|letter $params\n");
			my $idx = int($cmd[2])-1;
			foreach my $char (@{$patterns[$idx]}) {
				$char = $nullchar;
			}
			${$patterns[$idx]}[$map{$cmd[3]}] = lc($cmd[3]);
			splice(@localARGV, $argidx, 1);
		}
	}
}

## filter words according to a list of letters must not be anywhere in the word
foreach my $argidx (reverse 0..$#localARGV) {
	my @cmd = $localARGV[$argidx] =~ /./sg;
	my $params;
	if ($cmd[0] eq 'l') {
		if ($cmd[1] eq 'n') {
			$params = substr($localARGV[$argidx], 2);
			my @param = $params =~ /./sg;
			print("word must not contain the letters $params\n");
			for my $ii (0 .. $#patterns) {
				my $kk = $#{$patterns[$ii]}+1;
				print("place $ii has $kk candidates\n");
				if ($kk == 0) {
					print STDERR "unable to find words since criterion is 0 for char place $ii\n";
				}
				else {
					for my $jj (0 .. $#param) {
						${$patterns[$ii]}[$map{$param[$jj]}] = $nullchar;
					}
				}
			}
			splice(@localARGV, $argidx, 1);
		}
	}
}

## command line options are not legal - error message and usage message
if ($#localARGV >= 0) {
	print STDERR "unknown CLI arguments: [@localARGV]\n";
	print STDERR "error: invalid parameters in CLI\n";
	print STDERR "use:\tcmds.pl n# [lpNC] [lnC...] [lzNC]\n";
	print STDERR "\t\tlp, ln, lz commands can repeat with limitations\n";
	exit(1);
}

## resolving the regex filter for the cases for options lp ln
for my $tt (0 .. $#patterns) {
	my @ppar;
	@ppar = @{$patterns[$tt]};
	#print("[@ppar]:$#ppar\n");
	my @del_indexes = reverse(grep { $ppar[$_] eq $nullchar } 0..$#ppar);
	foreach my $index (@del_indexes) {
		splice(@ppar, $index, 1);
		#print("[@ppar]:$#ppar\n");
	}
	#print("[@ppar]:$#ppar\n");
	@{$patterns[$tt]} = @ppar;
}
my $regex = "";
for my $tt (0 .. $#patterns) {
	my $pattern = join '', @{ $patterns[$tt] };
	#print("[$pattern]");
	$regex = $regex . "[" . $pattern . "]";
}
## insert regex string (for options lp ln) to list of regex filters
unshift @myregex, $regex;
#print("\n");

## debug - print all regex filters
#foreach my $pati (@myregex) {
	#print("^$pati\$\n");
#}

## filter words in the dictionary according to the regex filters 
##  in the numeric order
foreach my $regexstr (@myregex) {
	$regexstr = "^" . $regexstr . "\$";
	my $re = qr/$regexstr/;
	foreach my $wordidx (reverse 0..$#words) {
		if ($words[$wordidx] !~ $re) {
			splice @words, $wordidx, 1;
		}
	}
}

## print resultant wordlist to standard output
foreach my $wordidx (0..$#words) {
	print("$words[$wordidx]\n");
}

## print short summary of the search and guess a word - to standard error
my $nwords = $#words+1;
print STDERR "number of words: $nwords\n";
print STDERR "candidate $words[int(rand ($nwords-1))]\n";
