#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Moveit.pm
#
#  DESCRIPTION:  Contains basic utility routines for the BUFRgruven routine
#                At least that's the plan
#
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  19.24.4
#      CREATED:  13 June 2019
#===============================================================================
#
package Moveit;
require 5.8.0;
use strict;
use warnings;
use English;


use if defined eval{require Time::HiRes;} >0,  "Time::HiRes" => qw(time);
use vars qw (%Bgruven $mesg); 
use Utils;


sub gruven {
#----------------------------------------------------------------------------------
#   Calls the various BUFR file processing routines
#----------------------------------------------------------------------------------
#
#  Bring in the Bgruven hash from main
#
%Bgruven = %main::Bgruven;

    if (%{$Bgruven{PROCESS}->{STATIONS}{process}}) {

        foreach my $type (keys %{$Bgruven{DATA}}) {

            &export($type) if @{$Bgruven{BINFO}->{EXPORT}{$type}};

        }
    }

return %Bgruven;
}


sub export {
#----------------------------------------------------------------------------------
#    Processes the BUFR files into GEMPAK sounding files
#----------------------------------------------------------------------------------
#
    my $type = shift;

    #  Get the list of placeholders for the filenames
    #
    my $ymd       = $Bgruven{PROCESS}->{DATE}{yyyymmdd};
    my $cc        = $Bgruven{PROCESS}->{DATE}{acycle};

    my @phs = ($ymd, $cc, "$Bgruven{BINFO}->{DSET}{dset}", "$Bgruven{BINFO}->{DSET}{model}");


    &Utils::modprint(0,2,96,1,1,sprintf("%5s  Exporting $type files to exotic locations",shift @{$Bgruven{GRUVEN}->{INFO}{rn}}));

    unless (@{$Bgruven{DATA}->{$type}}) {&Utils::modprint(0,9,96,1,2,"There are no $type files scheduled for transfer at this time."); return;}

    foreach my $exp (@{$Bgruven{BINFO}->{EXPORT}{$type}}) {

        #  Parse the string and populate the placeholders
        my ($meth,$host,$rdir) = split /\|/ => $exp;
        $rdir = &Utils::fillit($rdir,@phs);

        $meth = 'copy' if $meth =~ /^cp/i;

        if ($meth =~ /scp/i and ! $host) {&Utils::modprint(6,9,196,1,1,"Export method $meth for $type files missing hostname - Assuming $rdir on local host"); $meth = 'copy';}
        unless ($rdir) {&Utils::modprint(6,9,96,1,1,"Target directory missing for exporting $type files via $meth"); next;}
        unless ($meth) {&Utils::modprint(6,9,96,1,1,"Export method missing for $type files - Assuming local copy"); $meth = $host ? 'scp' : 'copy';}
        unless ($host or $meth eq 'copy') {&Utils::modprint(6,9,96,1,1,"Method $meth for $type files needs a remote host"); next;}

        for ($meth) {
            if (/http/i)  {&Utils::modprint(6,9,96,1,1,"HTTP(S) is not a supported method of exporting files");next;}
            if (/scp/i)   {&Method::put_scp($host,$rdir,$type);next;}
            if (/sftp/i)  {&Method::put_sftp($host,$rdir,$type);next;}
            if (/ftp/i)   {&Method::put_ftp($host,$rdir,$type);next;}
            if (/copy/i)  {&Method::put_copy($rdir,$type);next;}
        }
    }
    
    my $ct = gmtime();
    &Utils::modprint(0,9,144,1,2,"May all the fantasies of your $type files be realized");


return 1;
}



