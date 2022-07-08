#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Files.pm
#
#  DESCRIPTION:  Contains basic utility routines for the BUFRgruven routine
#                At least that's the plan
#
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  21.19.4
#      CREATED:  13 May 2021
#===============================================================================
#
package Files;
require 5.8.0;
use strict;
use warnings;
use English;


sub unpack {
#----------------------------------------------------------------------------------
#  this routine unpacks files compressed in gzip, bzip, or bzip2 format
#  The packed files are passed as a list and he routine used for unpacking
#  is determined by the file extention.  A list of unpacked file is returned.
#----------------------------------------------------------------------------------
#
use File::stat;
use POSIX qw(ceil);

    my @unpackd=();

    my @packd = @_;

    return @unpackd unless @packd;

    my $rout = $packd[0] =~ /(.gz)$/  ?  &Utils::findcmd('gunzip')   :
               $packd[0] =~ /(.bz2)$/ ?  &Utils::findcmd('bunzip2')  :
               $packd[0] =~ /(.bz)$/  ?  &Utils::findcmd('bunzip2')  : 0;

    unless ($rout) {&Utils::modprint(6,11,96,0,1,"Unknown file compression suffix ($packd[0]) - Return"); return @unpackd;}

    foreach my $zfile (@packd) {
       next unless ((my $file = $zfile) =~ s/(.gz)$|(.bz2)$|(.bz)$//g);
       system "$rout $zfile > /dev/null 2>&1";
       unless (-s $file) {&Utils::modprint(6,14,96,1,2,"Problem unpacking $zfile"); next;}
       push @unpackd => $file;
   }

return @unpackd;
}

