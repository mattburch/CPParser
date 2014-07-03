CPParser
===

##Objective##

CPParser is a PERL framework designed to parse through and extract element details from the Check Point objects_5_0.C, policy.pf and netconf.C configuration files. The specific purpose of this framework is to provide similar functionality to [Ofiller and Odumper](http://www.cpshared.com/forums/files/ofiller_v2.4.tgz) but has the ability to parse the entire configuration file within a HASH object structure.

##CPPaser Functions##
````
object_parser('FileName')     # Parses object_5_0.C <FileName> and returns HASH reference
policy_parser('FileName')     # Parses policy.pf <FileName> and returns HASH reference
netconf_parser('FileName')    # Parses netconf.C <FileName> and returns HASH reference
get_object(HASH)              # Takes ref HASH and returns ref HASH default data set for %object || %gateway || %group_object
get_service(HASH)             # Takes ref HASH and returns ref HASH default data set for %service || %service_group
data_dump(HASH)               # Takes ref HASH and performs data_dumper
object_filler(HASH)           # Takes ref HASH and exports DBedit commands to create / update network objects
service_filler(HASH)          # Takes ref HASH and exports DBedit commands to create / update service objects
````

##Default Object HASH Structure##

````
%object = (
    'uid'       =>  'Object UID value',
    'ClassName' =>  'Object class name',
    'type'      =>  'Object type',
    'color'     =>  'Object Color',
    'ipaddr'    =>  'IP Address',
    'netmask'   =>  'Netmask (if defined || undef)',
    'firstip'   =>  'First IP Address for Range (if defined || undef)',
    'lastip'    =>  'Last IP Address for Range (if defined || undef)',
    'autonat'   =>  'Automatic NAT (if defined || undef)',
    'comments'  =>  'Object comments (if defined || undef)'
);

%gateway = (
    'uid'       =>  'Object UID value',
    'ClassName' =>  'Object class name',
    'type'      =>  'Object type',
    'color'     =>  'Object Color',
    'main_ip'   =>  'Main IP Address',
    'comments'  =>  'Object comments (if defined || undef)',
    'enc_uid'   =>  'Encryption Group UID (if defined || undef)',
    'enc_grp'   =>  'Encryption Group Name (if defined || undef)'
    'interfaces'    =>  {
        'ifname'        =>  'Interface Name',
        'ipaddr'        =>  'Interface IP Address',
        'netmask'       =>  'Interface Netmask',
        'antispoof'     =>  'AntiSpoofing Enabled',
        'spoof_type'    =>  'AntiSpoof type',
        'dmz_net'       =>  'AntiSpoof DMZ Net (if defined || undef)',
        'wan_net'       =>  'AntiSpoof WAN Net (if defined || undef)',
        'netaccess'     =>  'AntiSpoof Group Name (if defined || undef)',
        'uid'           =>  'AntiSpoof Group UID (if defined || undef)'
    },
);

%group_object = (
    'uid'       =>  'Object UID value',
    'ClassName' =>  'Object class name',
    'type'      =>  'Object type',
    'color'     =>  'Object Color',
    'comments'  =>  'Object comments (if defined || undef)'
    'members'   =>  {
        'uid'   =>  'Object UID value',
        'name'  =>  'Object Name value' 
    },
);

%service_object = (
    'uid'               =>  'Object UID value',
    'ClassName'         =>  'Object class name',
    'type'              =>  'Object type',
    'color'             =>  'Object Color',
    'port'              =>  'Object Port #',
    'src_port'          =>  'Object SRC Port (if defined || undef)',
    'icmp_code'         =>  'Object ICMP Code (if defined || undef)',
    'icmp_type'         =>  'Object ICMP Type (if defined || undef)',
    'uuid'              =>  'Object UUID (if defined || undef)',
    'comments'          =>  'Object Comments (if defined || undef)',
    'include_in_any'    =>  'Object marked to match for ANY',
    'dOBJ'              => 'Identify if object is CP default'
);

%service_group = (
    'uid'       =>  'Object UID value',
    'ClassName' =>  'Object class name',
    'type'      =>  'Object type',
    'color'     =>  'Object Color',
    'comments'  =>  'Object comments (if defined || undef)'
    'members'   =>  {
        'uid'   =>  'Object UID value',
        'name'  =>  'Object Name value' 
    },
);
````

##Execution Examples##

Parse all class 'C' network objects.
```perl
[:pc:///
my $data = object_parser('objects_5_0.C');

my %objects = get_object($data->{'network_objects'});

foreach my $i (keys %objects) {
    if ( defined $objects{$i}{'netmask'} && $objects{$i}{'netmask'} eq '255.255.255.0' ) {
        print "$i\t$objects{$i}{'ipaddr'}\t$objects{$i}{'netmask'}\n";
    }
}
````

Parse all network objects with 255.255.255.255 netmask.
````perl
my $data = object_parser('objects_5_0.C');

my %objects = get_object($data->{'network_objects'});

foreach my $i (keys %objects) {
    if ( defined $objects{$i}{'netmask'} && $objects{$i}{'netmask'} eq '255.255.255.255' ) {
        print "$i\t$objects{$i}{'ipaddr'}\t$objects{$i}{'netmask'}\n";
    }
}
````

Parse and export cluster objects.
````perl
my $data = object_parser('objects_5_0.C');

my %objects = get_object($data->{'network_objects'});

data_dump($objects{'Corporate-Cluster-1'});
````

Compare two policy databases from different policy servers
````perl
my $data = object_parser('ORG-objects_5_0.C');
my $new = object_parser('objects_5_0.C');

my %objects = compare_obj($data->{'network_objects'},$new->{'network_objects'});

data_dump(\%objects);
````

Compare two policy databases that have been build in VM. the UID object values should mostly be the same.
````perl
#
# Database Compare routine
#
my $data = object_parser('LIVE-objects_5_0.C');
my $data2 = object_parser('LAB-objects_5_0.C');

my %objects = compare_obj($data->{'network_objects'},$data2->{'network_objects'});
my %services = compare_service($data->{'services'},$data2->{'services'});

foreach my $i (keys %objects) {
    print "\n***\t\t\t***\n";
    print "***\t$i\t***\n";
    print "***\t\t\t***\n\n";
    data_dump($objects{$i});
}
````

Export commands for dbedit import.
````perl
my $data = object_parser('ORG-objects_5_0.C');
my $new = object_parser('objects_5_0.C');

my %objects = compare_obj($data->{'network_objects'},$new->{'network_objects'});
my %services = compare_service($data->{'services'},$new->{'services'});

filler(\%objects,'network_objects');
filler(\%services,'services');
````
