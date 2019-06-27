#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Moveit.pm
#
#  DESCRIPTION:  Contains the calls the export routines to move all the data
#                At least that's the plan
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  11.0
#      CREATED:  06/28/2011 10:31:20 PM
#     REVISION:  ---
#===============================================================================
#
package Moveit;
require 5.8.0;
use strict;
use warnings;
use English;
use Time::HiRes qw (time);
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
#  If you are using Perl version 5.10 or higher then comment out the "use Switch 'Perl6'"
#  statement and uncomment the use feature "switch" line.
#
use Switch 'Perl6';      #  < Perl V5.10
#use feature "switch";   #  For Perl V5.10 and above

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
        unless ($rdir) {&Utils::modprint(6,9,96,1,1,"Target directory missing for exporting $type files via $meth"); next;}
        unless ($meth) {&Utils::modprint(6,9,96,1,1,"Export method missing for $type files - Assuming local copy"); $meth = $host ? 'scp' : 'copy';}
        unless ($host or $meth eq 'copy') {&Utils::modprint(6,9,96,1,1,"Method  $meth for $type files needs a remote host"); next;}
        $host = 'local' unless $host;

        given ($meth) {
            when (/http/i)  {&Utils::modprint(6,9,96,1,1,"HTTP is not a supported method of exporting files");next;}
            when (/scp/i)   {&Method::put_scp($host,$rdir,$type);}
            when (/sftp/i)  {&Method::put_sftp($host,$rdir,$type);}
            when (/ftp/i)   {&Method::put_ftp($host,$rdir,$type);}
            when (/copy/i)  {&Method::put_copy($rdir,$type);}
        }
    }
    
    my $ct = gmtime();
    &Utils::modprint(0,9,144,1,2,"May all the exotic destinations of your $type files be realized");


return 1;
}



