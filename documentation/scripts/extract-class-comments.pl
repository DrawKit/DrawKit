#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use IO::All -utf8;

=pod DESCRIPTION
Given a source code file, look for a likely class comment.
=cut

while(my $file_path = shift) {

	my $original_contents < io($file_path);

	$_ = $original_contents;
	# http://ostermiller.org/findcomment.html
	my @comments = m!/\*(?:.|[\r\n])*?\*/!g;
	if (scalar(@comments) > 1) {
		print $file_path.":\n";
		print $comments[-1];
	}
}
