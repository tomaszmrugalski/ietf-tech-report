#!/usr/bin/env perl
#
# Copyright (c) 2012 IETF Trust and the persons identified as
# authors of the code.  All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
#
# Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in
# the documentation and/or other materials provided with the
# distribution.
#
# Neither the name of Internet Society, IETF or IETF Trust, nor the
# names of specific contributors, may be used to endorse or promote
# products derived from this software without specific prior written
# permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
# CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS
# BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
# TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
# OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
#  Author:  Alan DeKok <aland@freeradius.org>
#
use Getopt::Std;

%drafts = {};			# information about the draft
%rfc = {};			# information about the RFC
%search = {};			# option: search for drafts using these RFCs
%opts = {};			# command-line options
%wgs = {};			# working groups to ignore
%tech = {};			# named technologies

getopts('r:W:', \%opts);

# The arguments are just a list of RFCs to look for.
#
# -r 2865,2866,3179
foreach (split(/,/,$opts{'r'})) {
    $search{$_}++;
}

# Get the list of named technologies
open FILE, "<tech.txt";
while (<FILE>) {
    next if (/^\s*#/);
    s/#.*$//;
    $_ =~ m/^(.*)\s+([\d,]+)$/;

    $name = $1;
    $list = $2;

    foreach $doc (split /,/,$list) {
	$tech{$name}{$doc}++;
    }
}
close FILE;

# Replace technology name by list of RFCs.
foreach $ref (keys %search) {
    next if ($ref =~ /^\d+/);
    undef $search{$ref};

    foreach $doc (keys %{$tech{$ref}}) {
	$search{$doc}++;
    }
}

# A list of Working groups to exclude.  It's a good idea to exclude the
# working groups generating the drafts.  We presume that people in the WG
# already know that the drafts exist.
#
# -W radext,dime
foreach (split(/,/,$opts{'W'})) {
    $wgs{$_} = 0;
}

# Open the list of active internet drafts.
open FILE, "<internet-drafts/all_id.txt" or die "Can't open all_id.txt\n";
while (<FILE>) {
  $_ =~ /^(draft-ietf-.*)\s+\d{4}-\d{2}-\d{2}\s+(.*)$/;
  $doc = $1;
  $state = $2;

  $doc =~ /draft-ietf-([^-]+)-/;
  $wg = $1;

  # Ignore drafts which have been published as RFCs
  next if ($state =~ /^RFC/);

  # Ignore certain WGs.  i.e. ignore RADEXT references to RADIUS rfcs.
  if (defined $wgs{$wg}) {
      next if ($wgs{$wg} == 0);
  }

  # cache the state of the draft.
  $drafts{$doc}{'state'} = $state;
}

close FILE;

#
#  Root through all of the drafts, finding the documents they reference.
#
foreach $doc (keys %drafts) {
    # Ignore ones which no longer exist.
    open FILE, "<internet-drafts/$doc.txt" or next;
    $state = 0;

#    print "? $doc\n";

   while (<FILE>) {
       # Ignore everything until we find the "Normative References" section.
       if ($state == 0) {
	   next unless (/^\d/);
	   next unless (/\s*normative references\s*$/i);
	   $state = 1;
	   next;
       }

       # In the "normative references" section.
       if ($state == 1) {
	   # Stop processing the file if we see another section
	   last if (/^\d/);

	   # Look for [RFC2865]
	   if (/\[RFC(\d+)\]/) {
	       $drafts{$doc}{'normative'}{$1}++;
	       $rfc{$1}{$doc}++;
#	       print "$doc --> $1\n";
	       next;
	   }

	   # Or maybe "RFC 2865,"
	   if (/RFC (\d+),/) {
	       $drafts{$doc}{'normative'}{$1}++;
	       $rfc{$1}{$doc}++;
#	       print "$doc --> $1\n";
	       next;
	   }
       }
    }

    close FILE;
}

# For each RFC we're interested in, print out the list of drafts
# which reference ANY
foreach $doc (keys %search) {
    # print out each draft that has a normative reference to the RFC
    foreach $ref (keys %{$rfc{$doc}}) {

	# Unless we've already printed it out, via a reference to
	# another RFC.
	next if ($drafts{$ref}{'printed'});

	$drafts{$ref}{'printed'} = 1;
	$padding = 50 - length($ref);

	print $ref, ' ' x $padding, $drafts{$ref}{'state'}, "\n";
    }
}

exit 0;
