#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use IO::All -utf8;

=pod DESCRIPTION
Given a source code file, move public comments to header in doxygen format.
=cut

while(my $file_path = shift) {

	# Skip unless file is an Objective-C source file...
	next unless ($file_path =~ /\.m$/);
	
	print "[extract] $file_path\n";

	my $original_contents < io($file_path);
	my $stripped_contents = '';

	# Divide input into source and comment blocks
	my @content_parts;
	my $comment;
	my $code;
	foreach my $line (split(/\n/,$original_contents)) {
		if ($line =~ /^\/{3}/) {
			# comment
			$comment .= $line."\n";
			
			# push prior code, if any
			if ($code) {
				push(@content_parts,$code);
				$code = undef;
			}			
		} else {
			# code
			$code .= $line."\n";

			# push prior comment, if any
			if ($comment) {
				push(@content_parts,$comment);
				$comment = undef;
			}
		}
	}
	if ($comment) {
		push(@content_parts,$comment);
		$comment = undef;
	}
	if ($code) {
		push(@content_parts,$code);
		$code = undef;
	}
	#print Dumper(\@content_parts);

	# Iterate over each part
	my @comments;
	my $preceding_comment;
	foreach my $original_block (@content_parts) {

		# Special case the file header
		if ($original_block =~ /\/+\s+This software is released/) {
			$stripped_contents .= <<__HEADER;
/**
 * \@author Graham Cox, Apptree.net
 * \@author Graham Miln, miln.eu
 * \@author Contributions from the community
 * \@date 2005-2013
 * \@copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */
__HEADER
		
		}
		# Is this content a comment?
		elsif ($original_block =~ /^\/{3}/m) {
			 
			 my $comment = &extract_comment($original_block);
			 push(@comments,$comment);
			 $preceding_comment = $comment; # track comment as needing a method
			 
		} else {
			# ...not a comment block, likely a method
			
			if ($preceding_comment) {
				
				# Look for a method for the preceding comment
				if (($original_block =~ /^(?<method>[-+] \(.*)$/m) or # Obj-C
					($original_block =~ /^(?<method>(?:static )?\S+\s+\S+\(.*)$/m)) { # C
										
#					print Dumper($preceding_comment)." ... ";
					print $+{method}."\n";

					$preceding_comment->{'signature'} = $+{method};
					$preceding_comment = undef;
				}	
			}
			
			$stripped_contents .= $original_block;
		}
	}
	
	# Open corresponding header
	my $header_path = $file_path;
	$header_path =~ s/\.m/\.h/;
	# ...skip if header does not exist
	next unless -e $header_path;
	
	print "[insert] $header_path\n";
	my $header_contents < io($header_path);

	# Replace the header
	my @header_contents = split(/\n/m,$header_contents);
	while($header_contents[0] =~ /^\/{3}/) {
		shift(@header_contents);
	}

	$header_contents = <<__HEADER;
/**
 * \@author Graham Cox, Apptree.net
 * \@author Graham Miln, miln.eu
 * \@author Contributions from the community
 * \@date 2005-2013
 * \@copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */
__HEADER
	$header_contents .= join("\n",@header_contents);
	
	my @remaining_comments;	
	foreach my $comment (@comments) {
		my $signature = $comment->{'signature'};
		die(Dumper($comment)) unless(defined($signature));
		if ($header_contents =~ /\Q$signature\E/m) {
			print "Found: $signature\n";
			
			$header_contents = $` . "\n".$comment->{'doxygen'}."\n" . $& . $';
		} else {
			push(@remaining_comments,$comment);
		}
	}
		
	print "[insert] $file_path\n";

	my @missing_comments;	
	foreach my $comment (@comments) {
		my $signature = $comment->{'signature'};
		die(Dumper($comment)) unless(defined($signature));
		
		if ($stripped_contents =~ /\Q$signature\E/m) {
			print "Found: $signature\n";
			
			$stripped_contents = $` . "\n".$comment->{'doxygen'}."\n" . $& . $';
		} else {
			push(@missing_comments,$comment);
		}
	}
	
#	print Dumper(\@missing_comments);
#	exit 1;
	
	warn("[WARNING] $file_path missing comments matches for ".Dumper(\@missing_comments)) if (scalar(@missing_comments) > 0);
	
	$header_contents =~ s/\n\n+/\n\n/gm;
	$stripped_contents =~ s/\n\n+/\n\n/gm;
	
	$header_contents .= "\n" if ($header_contents !~ /\n\n$/);
	$stripped_contents .= "\n" if ($stripped_contents !~ /\n\n$/);
	
	io($header_path) < $header_contents;
	io($file_path) < $stripped_contents;
}

=pod extract_comment
=cut
sub extract_comment {
	my($original_comment) = @_;
		
	# Strip off the prefix slashes and whitespace
	$original_comment =~ s/^\/{3}\s+//gm;
	
	# Parse comment in hash
	my %text_for;
	my $current_tag;
	foreach my $line (split(/\n/m,$original_comment)) {
		# ...skip blank lines unless parsing block tag
		next unless ($current_tag or $line =~ /\S/);
		next if ($line =~ /\/+/);
		next if ($line =~ /\/{3}\*+/);
			
		# ...match tag and text line
		if ($line =~ /^(?<tag>\w+):\s+(?<text>.+?)$/) {
			$current_tag = $+{tag};
			$text_for{$current_tag} .= $+{text};
		}
		# match text line
		elsif ($line =~ /^(?<text>.+)$/) {
		
			# deal with missing tags
			$current_tag = 'notes' if (not defined($current_tag));		
			$text_for{$current_tag} .= "\n".$+{text};
		}
	}

	# Sub-parse parameters
	if (exists($text_for{'parameters'})) {
		my @parameters;
		# ...split by line
		foreach my $parameter (split(/\n/,$text_for{'parameters'})) {
			if ($parameter =~ /^<(?<parameter>.+)> (?<text>.+)$/) {
				push(@parameters,{'label' => $+{parameter},'text' => $+{text}});
			}
		}
		$text_for{'parameters'} = \@parameters;
		delete($text_for{'parameters'}) if (scalar(@parameters) == 0);
	}
	
	# Remove empty tags, except parameters	
	my @remove_tag;
	foreach my $tag (keys(%text_for)) {
		next if ($tag eq 'parameters');
		push(@remove_tag,$tag) if ($text_for{$tag} =~ /^\s+/)
	}
	delete($text_for{$_}) foreach (@remove_tag);
	# ...special case remove 'result'
	delete($text_for{'result'}) if ((exists($text_for{'result'})) and ($text_for{'result'} eq 'none'));

	# rewrite parsed comment block as doxygen
	
##	print Dumper(\%text_for);

	my @rewritten_comment;
	
	push(@rewritten_comment,'@brief '.ucfirst($text_for{'description'})) if (exists($text_for{'description'}));
	push(@rewritten_comment,"\@note\n".ucfirst($text_for{'notes'})) if (exists($text_for{'notes'}));
	foreach my $parameter (@{$text_for{'parameters'}}) {
		push(@rewritten_comment,'@param '.$parameter->{'label'}.' '.$parameter->{'text'});
	}
	push(@rewritten_comment,'@return '.$text_for{'result'}) if (exists($text_for{'result'}));
	
	if (exists($text_for{'scope'})) {
		push(@rewritten_comment,'@public') if ($text_for{'scope'} =~ /public/);
		push(@rewritten_comment,'@private') if ($text_for{'scope'} =~ /private/);
	}
	
	# Wrap rewritten content as a comment block
	my $rewritten_comment = join("\n",@rewritten_comment);
	$rewritten_comment =~ s/\n/\n * /gm;
	$rewritten_comment = "/** ".$rewritten_comment."\n */";
	
	$text_for{'doxygen'} = $rewritten_comment;
	
	$text_for{'original'} = $original_comment;
	
##	print "$rewritten_comment";
	
	return \%text_for;
}
