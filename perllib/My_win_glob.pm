# Provides wildcard globbing for Windows.  That feature is supported
# directly by Perl as of Perl 5.2 or some such, so this module is for
# older Perls running on Windows.
#
# John Kerl
# 2001/02/06

# ================================================================
# Copyright (c) 2001 John Kerl.
# kerl.john.r@gmail.com
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to permit
# persons to whom the Software is furnished to do so, subject to the
# following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN
# NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
# DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
# OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
# USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place, Suite 330, Boston, MA  02111-1307  USA
# ================================================================


package My_win_glob;
require Exporter;

@ISA = qw(Exporter);
@EXPORT = qw(my_win_glob);

sub my_win_glob {

	my $verbose     = 0;

	my @input_args  = @_;
	my @output_args = ();
	my @pre_list    = ();
	my @post_list   = ();
	my $sep         = ("-" x 72) . "\n";
	my $num_expansions_attempted = 0;
	my $num_expansions_succeeded = 0;

	foreach $input_arg (@input_args) {
		print $sep if $verbose;
		print "ARG: $input_arg\n" if $verbose;

		# See if the current argument has any wildcards to glob.
		if (($input_arg =~ m/.*\*.*/) || ($input_arg =~ m/.*\?.*/)) {
			$num_expansions_attempted++;

			# Replace multiple backslashes with a single backslash.
			$input_arg =~ s/\\+/\\/g;

			# Split path up into its directory components.
			my @arg_parts = split /\\/, $input_arg;

			# If absolute path (beginning with "\"), then result starts with a "\" too.
			if ($input_arg =~ m/^\\/) {
				@pre_list = ("\\");
				shift @arg_parts;
			}
			# If absolute path (beginning with "X:\" where X is the name of an NT
			# drive), then result starts with a "X:\" too.
			elsif ($input_arg =~ m/^[a-z]:\\/i) {
				@pre_list = ($input_arg =~ m/^([a-z]:\\)/i);
				shift @arg_parts;
			}
			# If relative path, then result starts with empty string.
			else {
				@pre_list = ("");
			}

			my $num_arg_parts = @arg_parts;
			my $i = 0;

			foreach $arg_part (@arg_parts) {
				print "\nPART $arg_part\n" if $verbose;

				# Turn wildcard syntax into regular-expression syntax.
				# E.g. "*" becomes ".*", "?" becomes ".", "." becomes "\."

				my $re_arg_part = $arg_part;
				$re_arg_part =~ s/\?/@/g;
				$re_arg_part =~ s/\./\\./g;
				$re_arg_part =~ s/@/./g;
				$re_arg_part =~ s/\*/.*/g;
				$re_arg_part = "^" . $re_arg_part . "\$";
				$re_arg_part = lc $re_arg_part; # lc for case insensitivity.

				print "RE: $re_arg_part\n" if $verbose;

				# Read directory at current level, filtering for current wildcard.
				# pre_list may contain wildcards; post_list will be the result of
				# filtering based on those wildcards.

				print "Pre list: (@pre_list)\n" if $verbose;

				@post_list = ();
				for my $pre (@pre_list) {
					my $dirname;
					if ($pre eq "") {
						$dirname = ".";
					}
					else {
						$dirname = $pre;
					}

					# Skip non-directories.  E.g. suppose the pattern is *\*\*, and
					# we're on the middle *.  Also suppose the filesystem has files
					# a\b\c, a\b\d, a\m.  The m entry in directory a is of no
					# interest since it is not a subdirectory and so couldn't
					# possibly yield a third-level result.

					next unless -d $dirname;

					# Read all entries in the current directory.

					opendir(DIR_HANDLE, $dirname)
						or die "Can't open directory $dirname: $!\n";
					my @all_ents = readdir(DIR_HANDLE);
					closedir DIR_HANDLE;

					# Filter out ".", ".." and any entries not matching the wildcard
					# pattern.  Push any filtered entries onto the post list.

					@filt_ents = ();
					for my $ent (@all_ents) {
						next if (($ent eq ".") and ($arg_part ne "."));
						next if (($ent eq "..") and ($arg_part ne ".."));
						# lc for case insensitivity.
						next unless ((lc $ent) =~ m/$re_arg_part/);
						push @filt_ents, $pre . $ent;
					}
					push @post_list, @filt_ents;

					print "  $pre/$arg_part/ -> (@filt_ents)\n" if $verbose;
				}

				print "Post list: (@post_list)\n" if $verbose;

				# Include \ between path components, unless on the last component.
				if (++$i < $num_arg_parts) {
					for my $post (@post_list) {
						$post .= "\\";
					}
				}

				# Prepare for the next pass.
				@pre_list = @post_list;
			}
			if (@post_list > 0) {
				$num_expansions_succeeded++;
			}
		}
		else {
			# Arguments that do not contain any wildcard characters are passed
			# straight through with no attempt to compare them against the contents
			# of the filesystem.
			if ($verbose) {
				$, = " ";
				print "Pushing input arg $input_arg onto post list @post_list\n";
			}
			@post_list = ($input_arg);
		}

		# Push the results of globbing the current argument onto the list of
		# results of globbing all arguments.
		push @output_args, @post_list;
	}

	if ($verbose) {
		$, = " ";
		print "OUTPUT: @output_args\n";
	}
	print $sep if $verbose;

	if (($num_expansions_attempted > 0) && ($num_expansions_succeeded == 0)) {
		print "No match.\n";
		unshift @output_args, 0;
	}
	else {
		unshift @output_args, 1;
	}

	return @output_args;
}

1;
