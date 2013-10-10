#! C:\perl\bin\perl
use strict;
use warnings;
no autovivification;
#no autovivification qw(exists store delete fetch strict); #kill if vivification

#
# routine to eliminate stupid vivification checks
#
sub check_hash {
   my( $hash, $keys ) = @_;

   return unless @$keys;

   foreach my $key ( @$keys ) {
       return 0 unless eval { exists $hash->{$key} };
       $hash = $hash->{$key};
       }

   return 1;
}

#
# routine to return HASH value without vivification
#
sub check_hash_value {
   my( $hash, $sub, $keys ) = @_;

   return unless @$keys;

   foreach my $key ( @$keys ) {
       return 0 unless eval { exists $hash->{$key} };
       $hash = $hash->{$key};
       }

   return $hash->{$sub};
}
   
#
#	Take in hash ref and dump contents in \t format
#
sub data_dump {
	my $ref = shift;
	my @list = @_;
	
	# If $ref is empty, we're reading an empty hash. Return undef.
	#return undef unless ref $ref eq 'HASH';
	
	if (ref $ref eq 'HASH') {
		foreach my $k (sort (keys %{$ref})) {
			my $length = $#list +1 ;
			
			print "\t" x $length;

			if (ref ${$ref}{$k} eq 'HASH') { 
				print "$k\n";
				push(@list,$k);
				
				# If $k is a header, call recursive.
				data_dump($ref->{$k},@list); 
				# decrease @list length once keys have been printed
				shift(@list);
			}
			elsif (ref ${$ref}{$k} eq 'ARRAY') {
				print "$k\n";
				push(@list,$k);

				# If $k is a header, call recursive.
				data_dump(@{$ref}{$k},@list); 
				# decrease @list length once keys have been printed
				shift(@list);
			}
			else { 
				if ( ${$ref}{$k} ) { print "$k => ${$ref}{$k}\n"; }
				else {  print "$k => undef\n"; }
			}
			
		}
	}
	else { 
		my $length = $#list +1;

		foreach (@{$ref}) {
			if (defined $_) { print "\t" x $length, "$_\n"; }
			else { print "\t" x $length, "NULL\n"; }
		}
	}
	return;	
}

#
# filler routine to add members to a group object
#
sub filler_addmember {
	my $ref = shift;
	my $table = shift;
	
	foreach my $obj (keys %{$ref}) {
		foreach my $member (@{$ref->{$obj}}) {
			print "addelement $table $obj \'\' $table:$member\n";
		}
		print "update $table $obj\n";
	}
	
}

#
# filler routine to rename objects
#
sub filler_rename {
	my $ref = shift;
	my $table = shift;
	
	foreach my $i (keys %{$ref}) {
		print "rename $table $ref->{$i}->{'orgname'} $ref->{$i}->{'newname'}\n";
		print "update $table $i\n";
	}
}

#
# filler routine to modify objects
#
sub filler_modify {
	my $ref = shift;
	my $table = shift;

	my %ignoropt = ( "uid"	=>	'', 
					"dOBJ"	=>	'', 
					"ClassName"	=>	'', 
					"type"	=>	'');
	
	foreach my $i (keys %{$ref}) {
		foreach my $field (keys %{$ref->{$i}->{'new'}}){
			if ($ref->{$i}->{'new'}->{$field} && 
			 check_hash($ref->{$i}->{'new'},[$field]) &&
			 !(exists $ignoropt{$field})) {
				print "modify $table $i $field $ref->{$i}->{'new'}->{$field}\n";
			}
		}
		print "update $table $i\n";
	}
	
}

#
# filler routine to create new objects / groups
#
sub filler_new {
	my $ref = shift;
	my $table = shift;
	my %groups;

	my %ignoropt = ( "uid"	=>	'', 
					"dOBJ"	=>	'', 
					"ClassName"	=>	'', 
					"type"	=>	'',
					"name"	=>	''
					);
	
	# Create all object types prior to creating group objects
	foreach my $i ( keys %{$ref} ) {
		if ($ref->{$i}->{'type'} eq 'group') { 
			$groups{$i} = $ref->{$i}; 
		}
		else {
			print "create $ref->{$i}->{'ClassName'} $i\n";
			
			foreach my $y ( keys %{$ref->{$i}} ) {
				if ( exists $ignoropt{$y} || 
						undef ~~ $ref->{$i}->{$y} || 
						$ref->{$i}->{$y} eq '' ) {
					next;
				} else {
					print "modify $table $i $y $ref->{$i}->{$y}\n";
				}
			}
			
			print "update $table $i\n";
		}
	}
	
	# Create group objects
	foreach my $i ( keys %groups ) {
		print "create $ref->{$i}->{'ClassName'} $i\n";
		print "modify $table $i color $ref->{$i}->{'color'}\n";
		
		if ( $ref->{$i}->{'comments'} && $ref->{$i}->{'comments'} ne '') {
			print "modify $table $i comments $ref->{$i}->{'comments'}\n";
		}
		
		foreach my $k ( keys %{$groups{$i}{'members'}} ) {
			print "addelement $table $i \'\' $table:$groups{$i}{'members'}{$k}{'name'}\n";
		}
		
		print "update $table $i\n";
	}
}

#
# Export object properties to create DBedit commands for object creation
#
sub filler {
	my $ref = shift;
	my $table = shift;
	my %groups;
	
	# Object options to ignore for DBedit

	if (ref $ref ne 'HASH') { die "Error: filler() requires ref of type HASH\n"; }
	unless ($table) { die "Error: filler() requires Objects_5_0.C table be supplied\n"; }
	
	if ($ref->{'rename'}) {
		filler_rename($ref->{'rename'},$table);
	}
	if ($ref->{'update'}) {
		filler_modify($ref->{'update'},$table);
	}
	if ($ref->{'addmember'}) {
		filler_addmember($ref->{'addmember'},$table);
	}
	if ($ref->{'new'}) {
		filler_new($ref->{'new'},$table);
	}
}

#
# Collects HASH values for gateway objects from data_parser
#
sub gateway_data {
	my $ref = shift;
	my %data;
	
	if (ref $ref ne 'HASH') { die "Error: gateway_data() requires ref of type HASH\n"; }
	
	%data = (
		'uid'		=>	$ref->{'AdminInfo'}->{'chkpf_uid'},
		'ClassName'	=>	$ref->{'AdminInfo'}->{'ClassName'},
		'type'		=>	$ref->{'type'},
		'color'		=>	$ref->{'color'},
		'main_ip'	=>	$ref->{'ipaddr'},
		'comments'	=>	$ref->{'comments'},
		'enc_uid'	=>	$ref->{'manual_encdomain'}->{'Uid'},
		'enc_grp'	=>	$ref->{'manual_encdomain'}->{'Name'},
	);
	
	foreach my $i (keys %{$ref->{'interfaces'}}) {
		%{$data{'interfaces'}{$i}} = (
			'ifname'		=>	$ref->{'interfaces'}->{$i}->{'officialname'},
			'ipaddr'		=>	$ref->{'interfaces'}->{$i}->{'ipaddr'},
			'netmask'		=>	$ref->{'interfaces'}->{$i}->{'netmask'},
			'antispoof'		=>	$ref->{'interfaces'}->{$i}->{'antispoof'},
			'spoof_type'	=>	$ref->{'interfaces'}->{$i}->{'netaccess'}->{'access'},
			'dmz_net'		=>	$ref->{'interfaces'}->{$i}->{'netaccess'}->{'dmz'},
			'wan_net'		=>	$ref->{'interfaces'}->{$i}->{'netaccess'}->{'leads_to_internet'},
			'netaccess'		=>	$ref->{'interfaces'}->{$i}->{'netaccess'}->{'allowed'}->{'Name'} || $ref->{'interfaces'}->{$i}->{'netaccess'}->{'OBJREF1'}->{'Name'},
			'uid' 			=>	$ref->{'interfaces'}->{$i}->{'netaccess'}->{'allowed'}->{'Uid'} || $ref->{'interfaces'}->{$i}->{'netaccess'}->{'OBJREF1'}->{'Uid'}
		);
	}
	
	return %data;
}

#
# Collects HASH values for group objects from data_parser
#
sub group_data {
	my $ref = shift;
	my %data;
	
	if (ref $ref ne 'HASH') { die "Error: group_data() requires ref of type HASH\n"; }
	
	%data = (
			'uid'		=>	$ref->{'AdminInfo'}->{'chkpf_uid'},
			'ClassName'	=>	$ref->{'AdminInfo'}->{'ClassName'},
			'type'		=>	$ref->{'type'},
			'color'		=>	$ref->{'color'},
			'comments'	=>	$ref->{'comments'}
		);
	foreach my $i (keys %{$ref}) {
		if ($i =~ /OBJREF/) {
			%{$data{'members'}{$i}} = (
				'uid'	=>	$ref->{$i}->{'Uid'},
				'name'	=>	$ref->{$i}->{'Name'}
			);
		}
	}
	
	return %data;
}

#
# Collects HASH values for network objects from data_parser
#
sub object_data {
	my $ref = shift;
	my %data;

	if (ref $ref ne 'HASH') { die "Error: object_data() requires ref of type HASH\n"; }
	
	%data = (
		'uid'		=>	$ref->{'AdminInfo'}->{'chkpf_uid'},
		'ClassName'	=>	$ref->{'AdminInfo'}->{'ClassName'},
		'type'		=>	$ref->{'type'},
		'color'		=>	$ref->{'color'},
		'ipaddr'	=>	$ref->{'ipaddr'},
		'netmask'	=>	$ref->{'netmask'},
		'firstip'	=>	$ref->{'ipaddr_first'},
		'lastip'	=>	$ref->{'ipaddr_last'},
		'autonat'	=>	$ref->{'NAT'},
		'comments'	=>	$ref->{'comments'}
	);
	
	return %data;
}

#
# Collects HASH values for service objects from data_parser
#
sub service_data {
	my $ref = shift;
	my %data;

	if (ref $ref ne 'HASH') { die "Error: service_data() requires ref of type HASH\n"; }
	
	%data = (
		'uid'				=>	$ref->{'AdminInfo'}->{'chkpf_uid'},
		'ClassName'			=>	$ref->{'AdminInfo'}->{'ClassName'},
		'type'				=>	$ref->{'type'},
		'color'				=>	$ref->{'color'},
		'port'				=>	$ref->{'port'},
		'src_port'			=>	$ref->{'src_port'},
		'icmp_code'			=>	$ref->{'icmp_code'},
		'icmp_type'			=>	$ref->{'icmp_type'},
		'uuid'				=>	$ref->{'uuid'},
		'comments'			=>	$ref->{'comments'},
		'include_in_any'	=>	$ref->{'include_in_any'}
	);
	
	# idenify if service object is a CP default
	if ($ref->{'AdminInfo'}->{'Deleteable'} && $ref->{'AdminInfo'}->{'Deleteable'} eq 'false') {
		$data{'dOBJ'} = 'true';
	}
	
	return %data;
}

#
# Initiates sub routines to pull service / network object HASH values from data_parser
#
sub get_data {
	my $ref = shift;
	my $option = shift;
	my %objects;
	
	unless (ref $ref ~~ /HASH|REF/) { die "Error: get_data() requires ref of type HASH || REF\n"; }
	
	if ( ref $ref eq 'HASH' ) {
		foreach my $k (keys %{$ref}) {
			$ref->{$k}->{'type'} =~ tr/A-Z/a-z/;
			
			if ($ref->{$k}->{'type'} =~ /gateway_cluster|cluster_member|gateway/) {
				%{$objects{$k}} = gateway_data($ref->{$k});
			}
			elsif ($ref->{$k}->{'type'} eq 'group') {
				%{$objects{$k}} = group_data($ref->{$k});
			}
			elsif ( $option eq 'object' ) {
				%{$objects{$k}} = object_data($ref->{$k});
			}
			elsif ( $option eq 'service' ) {
				%{$objects{$k}} = service_data($ref->{$k});
			}
		}
	}
	elsif ( ref $ref eq 'REF' ) {
		$$ref->{'type'} =~ tr/A-Z/a-z/;
		
		if ($$ref->{'type'} =~ /gateway_cluster|cluster_member|gateway/) {
			return gateway_data($$ref);
		}
		elsif ($$ref->{'type'} eq 'group') {
			return group_data($$ref);
		}
		elsif ( $option eq 'object' ) {
			return object_data($$ref);
		}
		elsif ( $option eq 'service' ) {
			return service_data($$ref);
		}
	}
	
	return %objects;
}

#
# Returns 1 if compare references do not match
#
sub compare {
	my $ref = shift;
	my $ref2 = shift;
	
	if ( $ref ) {
		if ( $ref2 ) {
			if ( $ref ne $ref2 ) { return 1; }
			else { return 0; }
		} else { return 1; }
	}
	elsif ( $ref2 ) { return 1; } 
	else { return 0; }
}

#
# Reindex Database objects based on UUID value
#
sub uidindex {
	my $ref = shift;
	my %index;
	
	#if (ref $ref ne 'REF') { die "Error: uiddex() requires $ref of ref type REF\n"; }
	if ( check_hash($ref,['uid']) ) {
		$index{$ref->{'uid'}} = $ref->{'name'};
	}
	else {
		foreach my $i ( keys %{$ref} ) {
			unless ( exists $index{$ref->{$i}->{'AdminInfo'}->{'chkpf_uid'}} ) {
				$index{$ref->{$i}->{'AdminInfo'}->{'chkpf_uid'}} = $ref->{$i};
			}
		}
	}
	
	return %index;
}

sub newmember {
	my %orggrp = group_data(shift);
	my %newgrp = group_data(shift);
	my (@members,%uidref);
	
	foreach my $member ( keys %{$orggrp{'members'}} ) {
		%uidref = uidindex($orggrp{'members'}{$member});
	}
	
	foreach my $i ( keys %{$newgrp{'members'}} ) {
		unless ( check_hash(\%uidref,[$newgrp{'members'}{$i}{'uid'}]) || exists $orggrp{'members'}{$i}) {
			push(@members,$newgrp{'members'}{$i}{'name'});
		}
		
	}
	
	return @members;
}

sub proptest {
	my $reforg = shift;
	my $refimp = shift;
	my $option = shift;

	$refimp->{'type'} =~ tr/A-Z/a-z/;
	$reforg->{'type'} =~ tr/A-Z/a-z/;
	
	if ($option eq 'object') {
		if ( compare($refimp->{'type'},$reforg->{'type'}) || 
		compare($refimp->{'color'},$reforg->{'color'}) || 
		compare($refimp->{'ipaddr'},$reforg->{'ipaddr'}) || 
		compare($refimp->{'netmask'},$reforg->{'netmask'}) || 
		compare($refimp->{'firstip'},$reforg->{'firstip'}) || 
		compare($refimp->{'lastip'},$reforg->{'lastip'}) || 
		compare($refimp->{'autonat'},$reforg->{'autonat'})) {
			return 1;
		}
	}
	elsif ($option eq 'service') {
		if ( compare($refimp->{'type'},$reforg->{'type'}) ||
		compare($refimp->{'color'},$reforg->{'color'}) ||
		compare($refimp->{'port'},$reforg->{'port'}) ||
		compare($refimp->{'src_port'},$reforg->{'src_port'}) ||
		compare($refimp->{'icmp_code'},$reforg->{'icmp_code'}) ||
		compare($refimp->{'icmp_type'},$reforg->{'icmp_type'}) ||
		compare($refimp->{'include_in_any'},$reforg->{'include_in_any'})) {
			return 1;
		}
	}
	
	return 0;
}

#
# Update original object database to accomodate for offline object development
# Use case: database object updates performed as a result VM policy modifications
#
sub dataupdate {
	my $reforg = shift;
	my $refimp = shift;
	my $option = shift;
	my %objects;
	
	#if (ref $reforg ne 'HASH') { die "Error: validate() requires $reforg of ref type HASH\n"; }
	if (ref $refimp ne 'HASH') { die "Error: validate() requires $refimp of ref type HASH\n"; }
	
	my %uidref = uidindex($reforg);
	
	foreach my $import (keys %{$refimp}) {
		my $uid = $refimp->{$import}->{'AdminInfo'}->{'chkpf_uid'};

		if ($refimp->{$import}->{'type'} =~ /gateway_cluster|cluster_member|gateway/) {
			next;
		}

		if (check_hash(\%uidref,[$uid])) {
			if ( check_hash(\%uidref,[$uid,'AdminInfo','name']) && 
			 check_hash_value(\%uidref,'name',[$uid,'AdminInfo']) ne $import ) {
				%{$objects{'rename'}{$import}} = (
					'orgname'	=>	$uidref{$uid}->{'AdminInfo'}->{'name'},
					'newname'	=>	$import
				);
			}
			if ( proptest($uidref{$uid},$refimp->{$import},$option) ) {
				if ( $refimp->{$import}->{'type'} eq 'group' ) {
					%{$objects{'update'}{$import}} = get_object(\$refimp->{$import},$option);
				}
				else {
					%{$objects{'update'}{$import}} = get_data(\$refimp->{$import},$option);
				}
			}
			elsif ( $refimp->{$import}->{'type'} eq 'group' ) {
				#check members
				my @members = newmember($reforg->{$import},$refimp->{$import});
				if ( @members ) {
					@{$objects{'addmember'}{$import}} = @members;
				}
			}
		}
		elsif ( check_hash($reforg,[$import])) {
			if ( proptest($reforg->{$import},$refimp->{$import},$option) ) {
				if ( $refimp->{$import}->{'type'} eq 'group' ) {
					%{$objects{'update'}{$import}} = get_object(\$refimp->{$import},$option);
				}
				else {
					%{$objects{'update'}{$import}} = get_data(\$refimp->{$import},$option);
				}
			}
			elsif ( $refimp->{$import}->{'type'} eq 'group' ) {
				#check members
				my @members = newmember($reforg->{$import},$refimp->{$import});
				if ( @members ) {
					@{$objects{'addmember'}{$import}} = @members;
				}
			}
		}
		else {
			%{$objects{'new'}{$import}} = get_data(\$refimp->{$import},$option);
		}

	
	}
	
	return %objects;
	
}

#
# Check-List
# Compair new items from $refimp against $reforg and returns the new items
# 
# To-Do validate does not scan to identify diff name for same IP but flags as new object
sub validate {
	my $reforg = shift;
	my $refimp = shift;
	my $option = shift;
	my %objects;
	
	if (ref $reforg ne 'HASH') { die "Error: validate() requires $reforg of ref type HASH\n"; }
	if (ref $refimp ne 'HASH') { die "Error: validate() requires $refimp of ref type HASH\n"; }
	
	foreach my $import (keys %{$refimp}) {
		
		if  ( exists $reforg->{$import} ) {
			$refimp->{$import}->{'type'} =~ tr/A-Z/a-z/;
			$reforg->{$import}->{'type'} =~ tr/A-Z/a-z/;
			
			if ($refimp->{$import}->{'type'} =~ /gateway_cluster|cluster_member|gateway/) {
				next;
			}
			elsif ($refimp->{$import}->{'type'} eq 'group') {
				my (%newgrp, %orggrp);
				%newgrp = get_data(\$refimp->{$import},$option);
				%orggrp = get_data(\$reforg->{$import},$option);
				
				foreach my $i (keys %{$newgrp{'members'}}) {
					my $count=1;
					foreach my $k (keys %{$orggrp{'members'}}) {
						if ($orggrp{'members'}{$k}{'name'} eq $newgrp{'members'}{$i}{'name'}) {
							last;
						}
						elsif ( $count == scalar(keys %{$orggrp{'members'}})) {
							%{$objects{'newgrp-member'}{$import}{$newgrp{'members'}{$i}{'name'}}} = 
							get_data(\$refimp->{$newgrp{'members'}{$i}{'name'}},$option);
						}
						$count++;
					}
				}
			}
			elsif ($option eq 'object') {
				if ( compare($refimp->{$import}->{'type'},$reforg->{$import}->{'type'}) || 
				compare($refimp->{$import}->{'color'},$reforg->{$import}->{'color'}) || 
				compare($refimp->{$import}->{'ipaddr'},$reforg->{$import}->{'ipaddr'}) || 
				compare($refimp->{$import}->{'netmask'},$reforg->{$import}->{'netmask'}) || 
				compare($refimp->{$import}->{'firstip'},$reforg->{$import}->{'firstip'}) || 
				compare($refimp->{$import}->{'lastip'},$reforg->{$import}->{'lastip'}) || 
				compare($refimp->{$import}->{'autonat'},$reforg->{$import}->{'autonat'})) {
					%{$objects{'update'}{$import}{'org'}} = get_data(\$reforg->{$import},$option);
					%{$objects{'update'}{$import}{'new'}} = get_data(\$refimp->{$import},$option);
				}
			}
			elsif ($option eq 'service') {
				if ( compare($refimp->{$import}->{'type'},$reforg->{$import}->{'type'}) ||
				compare($refimp->{$import}->{'color'},$reforg->{$import}->{'color'}) ||
				compare($refimp->{$import}->{'port'},$reforg->{$import}->{'port'}) ||
				compare($refimp->{$import}->{'src_port'},$reforg->{$import}->{'src_port'}) ||
				compare($refimp->{$import}->{'icmp_code'},$reforg->{$import}->{'icmp_code'}) ||
				compare($refimp->{$import}->{'icmp_type'},$reforg->{$import}->{'icmp_type'}) ||
				compare($refimp->{$import}->{'include_in_any'},$reforg->{$import}->{'include_in_any'})) {
					%{$objects{'update'}{$import}{'org'}} = get_data(\$reforg->{$import},$option);
					%{$objects{'update'}{$import}{'new'}} = get_data(\$refimp->{$import},$option);
				}
			}
		}
		else {
			%{$objects{'new'}{$import}} = get_data(\$refimp->{$import},$option);
		}
	}

	return %objects;
}

sub data_parser {
	my $file = shift;
	my $option = shift;
	
	open OBJECT, "<$file" or die "Can't open file $!";
	
	my @header;   
	my %database;
	my $objref = 0;
	
	while (<OBJECT>) {
		my ($name, $setting, $null) = ();
		my %list = ();

		my $original = $_;

		# strip whitespace & line return
		$_ =~ s/[\r\n]//g;
		$_ =~ s/[\t+]//g;
		if ($option eq 'netconf') { $_ =~ s/[\s+]//g; }
		
		if ($option eq 'policy') { next unless $_ =~ /^[:\)]/; }
		
		if ($_ eq '' || $_ eq '(' || $_ eq ': ()') { next; }
		
		if ($_ =~ /^:/ || ( $_ =~ /\(conf/ && $option eq 'netconf' )) {
			#identify identified names (\w+|.+)
			$name = $1 if $_ =~ /:(.*?)\s/;
			if ( $_ !~ /\(/ ) { 
				$name = $1 if $_ =~ /: (.*)/; 
				$setting = '';
				$null = 1;
			}
			#
			# identify setting value for $name
			# if () setting set to undef
			if ($_ =~ /\)(?!\")/) { 
				if ($_ =~ /\((.*?)\)/) { 
					$setting = ($1 eq '') ? undef : $1;
				}
				else { $setting = 'NULL'; }
			}
			elsif ($_ =~ /\((.+)/) { 
				$setting = $1; 
				
				# identify group member references
				
				if ($setting =~ /Reference/ && $option =~ /object/) { 
					$objref++; 
					$name = "OBJREF$objref"; 
				}
				elsif ($setting =~ /route|conn/ && $option =~ /netconf/) { 
					$objref++; 
					$name = "$setting$objref"; 
				}
				unless ($name) { $name = $setting; }
			}
			#unless ( defined $setting ){ $setting = 'HEAD'; }
			
			#identified NULL values
			unless (defined $name) { $name = "$header[$#header]_$setting"; }

			#identify open headers
			if ($_ !~ /\)(?!\")/ &! defined $null ) { 
				( my $class = $name ) =~ tr/a-z/A-Z/;

				unless ( @header ) {
					$database{$name} = {} unless exists $database{$name};
					push(@header,[ \$database{$name} => $name ]);
				}
				else {
					${$header[$#header][0]}->{$name} = {} unless exists ${$header[$#header][0]}->{$name};
					push(@header,[ \${$header[$#header][0]}->{$name} => $name ]);
				}
			}
		}
				
		if ($_ eq ')' ) { 
		
			# set $objref = 0 if group object is parsed
			if ($header[$#header]) {
				if ($header[$#header-1][1] =~ /network_objects|services|interfaces|routes|conns/ ) { 
					$objref = 0; 
				}
			}
			pop(@header); 
		}
		else { 
			unless ( @header ) { $database{$name} = $setting; }
			elsif ( $header[$#header][1] eq $name ) { next; }
			else { ${$header[$#header][0]}->{$name} = $setting; }
		}
	}
	close (OBJECT);
	return (\%database);
}

#############################
# Main subroutine calls to execute script fuctions
#############################
# Read and parse a object_5_0.C file
sub object_parser {
	return data_parser($_[0],'object');
}

# Read and parse a policy.pf file
sub policy_parser {
	return data_parser($_[0],'policy');
}

# Read and parse a netconf.C file
sub netconf_parser {
	return data_parser($_[0],'netconf');
}

# Dump default object settings for an object HASH
sub get_object {
	return get_data($_[0],'object');
}

# Dump default service settings for an service HASH
sub get_service {
	return get_data($_[0],'service');
}

# Compare two object HASH references
# $_[0] is original database $_[1] is new database file
sub compare_obj {
	return validate($_[0],$_[1],'object');
}

# Compare two service HASH references
# $_[0] is original database $_[1] is new database file
sub compare_service {
	return validate($_[0],$_[1],'service');
}

# VM database comparison were UIDs will be the same
# $_[0] is original database $_[1] is new database file
sub update_database_obj {
	return dataupdate($_[0],$_[1],'object');
}

# VM database comparison were UIDs will be the same
# $_[0] is original database $_[1] is new database file
sub update_database_srv {
	return dataupdate($_[0],$_[1],'service');
}

# Export Dbedit commands to update and add new objects
sub object_filler {
	filler ($_[0],'network_objects');
}

# Export Dbedit commands to update and add new objects
sub service_filler {
	filler ($_[0],'services');
}
