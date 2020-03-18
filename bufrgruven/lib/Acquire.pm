#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Acquire.pm
#
#  DESCRIPTION:  Contains basic utility routines for the BUFRgruven routine
#                At least that's the plan
#
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  20.09.2
#      CREATED:  25 February 2020
#===============================================================================
#
package Acquire;
require 5.8.0;
use strict;
use warnings;
use English;


use vars qw (%Bgruven $mesg);

sub bufr {
#----------------------------------------------------------------------------------
#   Calls the various initialization routines and returns the %Bgruven hash
#----------------------------------------------------------------------------------
#
#  Bring in the Bgruven hash from main
#
%Bgruven = %main::Bgruven;

    &stations    or &Love::died($mesg); #  Reconcile requested stations with those in station list

    &acquire     or &Love::died($mesg); #  Initialize directories and other stuff

return %Bgruven;
}


sub stations {
#----------------------------------------------------------------------------------
#  Complete the initial settings before attempting to acquire BUFR files
#----------------------------------------------------------------------------------
#
    my $dset  = $Bgruven{BINFO}->{DSET}{dset};
    my $ymd   = $Bgruven{PROCESS}->{DATE}{yyyymmdd}; chomp $ymd;
    my $cc    = $Bgruven{PROCESS}->{DATE}{acycle};

    #  Populate the date, time, and model placeholders in LOCFIL
    #
    $Bgruven{BINFO}->{DSET}{locfil} = &Utils::fillit($Bgruven{BINFO}->{DSET}{locfil},$ymd,$cc,$dset,'MOD');

    #  Delete any files in the local working directory that are greater than 2 days old.
    #
    &Utils::mkdir($Bgruven{GRUVEN}->{DIRS}{bufdir});
    opendir DIR => $Bgruven{GRUVEN}->{DIRS}{bufdir};
    foreach (readdir(DIR)) {next if /^\./; &Utils::rm("$Bgruven{GRUVEN}->{DIRS}{bufdir}/$_") if -M "$Bgruven{GRUVEN}->{DIRS}{bufdir}/$_" > 2;}
    closedir DIR;

    &Utils::modprint(0,2,96,1,1,sprintf("%5s  Determining which BUFR files need to be acquired",shift @{$Bgruven{GRUVEN}->{INFO}{rn}}));

    &Utils::modprint(1,11,114,1,1,"The \"--monolithic\" flag was passed. You're going for the whole kielbasa!") if $Bgruven{GRUVEN}->{OPTS}{mono};

    if (@{$Bgruven{PROCESS}->{STATIONS}{invld}}) {
        &Utils::modprint(6,9,104,1,0,sprintf("Hey, station %-5s is not in station list - $Bgruven{BINFO}->{DSET}{stntbl}",$_)) foreach @{$Bgruven{PROCESS}->{STATIONS}{invld}};
        &Utils::modprint(0,9,104,1,1,' ');
    }

    #  Return if all the requested stations are invalid
    #
    unless (%{$Bgruven{PROCESS}->{STATIONS}{valid}}) {$mesg = "There are no valid stations in your list!"; return;}

    #  Get the list of BUFR files to download and process
    #
    #  For SREF stations it is possible that a subset of the member BUFR files will be
    #  available when BUFRgruven is run.  Should a new SREF member become available 
    #  following the acquisition and processing of a SREF station then ALL available
    #  members must be processed again. Otherwise, only those new members  will be 
    #  included in the GEMPAK and BUFKIT files.
    #
    #  It is assumed that the user wants BUFKIT data to reflect all currently available
    #  SREF members for a station. Thus, the default behaviour is to process ALL 
    #  available members whenever a new member becomes available. If the user wishes 
    #  to suspend processing until ALL members become available then see the comments
    #  at the bottom of the acquire subroutine.
    #
    %{$Bgruven{PROCESS}->{STATIONS}{process}} = ();
    %{$Bgruven{PROCESS}->{STATIONS}{acquire}} = ();

    #  Make an initial loop through all the requested stations and model/members. Create 
    #  a list that will be check against to determine whether ALL the files for a station
    #  and data set have been downloaded and processed previously. 
    #  

    #  There is a problem when the --monolithic flag is passed in that when the BUFR file was 
    #  downloaded previously, there is no way to know whether the stations requested represent
    #  a new or old list. If old, then they may have been already processed into BUFKIT files
    #  but that is an unknown at this point.  Regardless, the valid station loop below will
    #  be executed for each station with the same locfil as the result.
    #  
    my %n2p=();
    foreach my $stnm (sort { $a <=> $b } keys %{$Bgruven{PROCESS}->{STATIONS}{valid}}) {
        $n2p{$stnm}=0;
        foreach my $mod (@{$Bgruven{BINFO}->{DSET}{members}{order}} ? @{$Bgruven{BINFO}->{DSET}{members}{order}} : @{$Bgruven{BINFO}->{DSET}{model}}) {
            my $locfil;
            for ($locfil = $Bgruven{BINFO}->{DSET}{locfil}) {s/STNM/$stnm/g; s/MOD|MEMBER/$mod/g; $_="$Bgruven{GRUVEN}->{DIRS}{bufdir}/$locfil";}
            $n2p{$stnm}=1 unless -s $locfil;
        }
    }

    #  Note that from the previous block, if $n2p{$stnm}=0 then all BUFR files for station 
    #  and data set were downloaded and processed previously. If a single member or BUFR
    #  file for a station/data set is missing then $n2p{$stnm}=1 and ALL the previously 
    #  downloaded and processed BUFR files for that station/data set will be scheduled
    #  for processing provided that any missing BUFR files are acquired.
    #

    #  When processing a monolithic file it must be assumed that all the stations are new
    #  and will handle whether to do any actual processing in the subroutines to follow.
    #
    foreach my $mod (@{$Bgruven{BINFO}->{DSET}{members}{order}} ? @{$Bgruven{BINFO}->{DSET}{members}{order}} : @{$Bgruven{BINFO}->{DSET}{model}}) {
        foreach my $stnm (sort { $a <=> $b } keys %{$Bgruven{PROCESS}->{STATIONS}{valid}}) {
            my $locfil;
            for ($locfil = $Bgruven{BINFO}->{DSET}{locfil}) {s/STNM/$stnm/g; s/MOD|MEMBER/$mod/g; $_="$Bgruven{GRUVEN}->{DIRS}{bufdir}/$locfil";}
            &Utils::rm($locfil) if $Bgruven{GRUVEN}->{OPTS}{forced};
            $Bgruven{PROCESS}->{STATIONS}{acquire}{$mod}{$stnm} = $locfil unless -s $locfil;
            $Bgruven{PROCESS}->{STATIONS}{process}{$mod}{$stnm} = $locfil if $Bgruven{GRUVEN}->{OPTS}{mono};
            $Bgruven{PROCESS}->{STATIONS}{process}{$mod}{$stnm} = $locfil if -s $locfil and ($Bgruven{GRUVEN}->{OPTS}{forcep} or $n2p{$stnm});
        }
    }

return 1;
}


sub acquire {
#----------------------------------------------------------------------------------
#  Go and get get the BUFR files
#----------------------------------------------------------------------------------
#
use List::Util qw(shuffle);
use Method;
use Data::Dumper; $Data::Dumper::Sortkeys = 1;

    my @missmbrs=();

    foreach my $meth (shuffle keys %{$Bgruven{PROCESS}->{SOURCES}}) {

        foreach my $host (shuffle keys %{$Bgruven{PROCESS}->{SOURCES}{$meth}}) {

            my $rfile = $Bgruven{PROCESS}->{SOURCES}{$meth}{$host};

            #  Create hash of BUFR files and location on remote host
            #
            my %bufrs=();

            foreach my $mod (sort keys %{$Bgruven{PROCESS}->{STATIONS}{acquire}}) {
                
                #  Add some lines to eliminate the possibility that $mod is an empty string or consists
                #  of all spaces.
                #
                $mod =~ s/ //g;
                next unless $mod;

                foreach my $stnm (sort {$a <=> $b} keys %{$Bgruven{PROCESS}->{STATIONS}{acquire}{$mod}}) {

                    #  Add some lines to eliminate the possibility that $stnm is an empty string or consists
                    #  of all spaces.
                    #
                    $stnm =~ s/ //g;
                    next unless $stnm;

                    if (-s $Bgruven{PROCESS}->{STATIONS}{acquire}{$mod}{$stnm}) {
                        push @{$Bgruven{DATA}->{BUFR}} => $Bgruven{PROCESS}->{STATIONS}{acquire}{$mod}{$stnm};
                        $Bgruven{PROCESS}->{STATIONS}{process}{$mod}{$stnm} = $Bgruven{PROCESS}->{STATIONS}{acquire}{$mod}{$stnm}; next;
                    }
                    (my $rf = $rfile) =~ s/STNM/$stnm/g; $rf =~ s/MOD|MEMBER/$mod/g;
                    $bufrs{$Bgruven{PROCESS}->{STATIONS}{acquire}{$mod}{$stnm}} = $rf;
                }
            }

            #  Attempt to aquire the BUFR files
            #
            if (%bufrs) {
                &Method::https($host,%bufrs) if $meth =~ /https$/i;
                &Method::http($host,%bufrs)  if $meth =~ /http$/i;
                &Method::copy($host,%bufrs)  if $meth =~ /nfs/i;
                &Method::ftp($host,%bufrs)   if $meth =~ /ftp/i;
            }


            #  Test whether all files were acquired
            #

            #  31 July 2013  - There is a problem in that there should not be any process'n going on if
            #                  none of the targeted BUFR file were acquired.  Currently, if one or more
            #                  BUFR files are missing on the server, Bgruven will continue to process
            #                  the previously downloaded files even when no new BUFR files were acquired,
            #                  which just ain't right.
            #                  
            #
            
            my %missing =();
            @missmbrs   =();
            foreach my $mod (sort keys %{$Bgruven{PROCESS}->{STATIONS}{acquire}}) {
                foreach my $stnm (sort {$a <=> $b} keys %{$Bgruven{PROCESS}->{STATIONS}{acquire}{$mod}}) {
                    if (-s $Bgruven{PROCESS}->{STATIONS}{acquire}{$mod}{$stnm}) {
                        $Bgruven{PROCESS}->{STATIONS}{newbufrs}++;
                        push @{$Bgruven{DATA}->{BUFR}} => $Bgruven{PROCESS}->{STATIONS}{acquire}{$mod}{$stnm};
                        $Bgruven{PROCESS}->{STATIONS}{process}{$mod}{$stnm} = $Bgruven{PROCESS}->{STATIONS}{acquire}{$mod}{$stnm}; next;
                    }
                    $missing{$mod}{$stnm} = $Bgruven{PROCESS}->{STATIONS}{acquire}{$mod}{$stnm};
                    push @missmbrs => $stnm;
                }
            }

            %{$Bgruven{PROCESS}->{STATIONS}{acquire}} = %missing;
            
            unless (%missing) {&Utils::modprint(0,9,96,1,2,"All requested BUFR files have arrived safely. Let's do it again!"); return 1;}
        }

    }

    if ($Bgruven{GRUVEN}->{OPTS}{debug}) {
        open DEBUGFL => ">$Bgruven{GRUVEN}->{DIRS}{debug}/acquire.debug.$$";
        my $dd = Dumper \%Bgruven; $dd =~ s/    / /mg;print DEBUGFL $dd;
        close DEBUGFL;
    }

    #  This code should eliminate the processing of SREF stations when there is one or more
    #  members missing.
    #
    #  Uncomment the following to change the behaviour such that SREF stations will not be 
    #  processed until all members exist locally on the system.
    #
#   foreach my $mod (sort keys %{$Bgruven{PROCESS}->{STATIONS}{process}}) {
#       foreach my $stn (&Utils::rmdups(@missmbrs)) {delete $Bgruven{PROCESS}->{STATIONS}{process}{$mod}{$stn} if exists $Bgruven{PROCESS}->{STATIONS}{process}{$mod}{$stn};}
#   }
    $Bgruven{PROCESS}->{STATIONS}{newbufrs} ? &Utils::modprint(0,9,96,1,2,"Hey, hey, looky what I found, a BUFR!  I'm back in action!") 
                                            : &Utils::modprint(0,9,96,1,2,"Sorry about your BUFR files. I'll do a better job next time!");


return 1;
}
