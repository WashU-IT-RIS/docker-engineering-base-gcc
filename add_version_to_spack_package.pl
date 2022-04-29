#!/usr/local/bin/perl

=head1 DESCRIPTION
yum install -y perl perl-CPAN make gcc
cpan install YAML::XS

$0 packages.yaml new_packages.yaml
=cut

use YAML::XS (qw(LoadFile DumpFile));

my $config = LoadFile($ARGV[0]);

=cut

packages:
  tcl:
    buildable: false
    externals:
    - spec: tcl@8.6
      prefix: /usr
=cut

for my $package (keys %{$config->{packages}}){
    my $info = `yum info $package`;
    if($info =~ /Version     : (\S+)/) { 
       $version = $1;
       $config->{packages}->{$package}->{externals}->[0]->{spec} =~ s/$packages\@.*/$packages\@$version/;
    }
}

DumpFile($ARGV[1], $config);
