#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Time.pm
#
#  DESCRIPTION:  Contains basic date and time routines for bufrgruven
#                At least that's the plan
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  11.0
#      CREATED:  06/28/2011 10:31:20 PM
#     REVISION:  ---
#===============================================================================
#
package Time;
require 5.8.0;
use strict;
use warnings;
use English;
use Time::Local;


sub compute_date {
#----------------------------------------------------------------------------------
#  This routine takes in a date string and offset (seconds) and calculates the
#  date. It returns a string YYYYMMSSMNSS.
#----------------------------------------------------------------------------------
#
    my ($date, $offset) = @_;

    #  Make sure no confusion with character strings
    #
    $date   += 0;
    $offset += 0;

    my $ctime  = &epocs($date) + $offset;
    my @time   = gmtime($ctime);
    my $string = &date2str($time[5]+1900,$time[4]+1,$time[3],$time[2],$time[1],$time[0]);

return $string;
}


sub epocs {
#----------------------------------------------------------------------------------
#  This routine accepts a date/time string YYYYMMDDHH[MN[SS]] and calculates
#  the number of seconds since the epoc.
#----------------------------------------------------------------------------------
#
    my $date = shift;
    my @list = &str2date($date);
    my $secs = timegm($list[5],$list[4],$list[3],$list[2],$list[1]-1,$list[0]-1900);

return $secs;
}


sub dateprnt {
#---------------------------------------------------------------------------------
#  This routine accepts YYYYMMDDHH[MM][SS] and returns a nice date/time
#  suitable for framing.
#
#  In:  2008062417[00][00]
#  Out: Tue Jun 24 17:00:00 2008 UTC
#---------------------------------------------------------------------------------
#
    my $date = shift;
    my @list = &str2date($date);
    my $string = gmtime(timegm($list[5],$list[4],$list[3],$list[2],$list[1]-1,$list[0]-1900));

return "$string UTC";
}


sub str2date {
#-------------------------------------------------------------------------------------
#  This routine takes a date/time string, formatted as YYYYMMDDHH[MN[SS]], parses the
#  year, month, day, hour, and second values, and then returns a list containing the
#  date/time values. Missing values are padded with "00"s since these are assumed.
#
#  Input: YYYYMMDDHH[MN[SS]]
#
#  Out  : ($yyyy, $mm, $dd, $hh, $mn, $ss) = @list
#-------------------------------------------------------------------------------------
#
    my @list=();

    my $date = shift;

    if (length $date < 8) {
        my $mesg = "Improper date ($date) in EMS_time::str2date";
        &EMS_util::emsprint(3,9,82,1,1,$mesg);
        return @list;
    }

    for ($date) {
        @list = $_ =~ /^(\d\d\d\d)(\d\d)(\d\d)$/                   if /^(\d\d\d\d)(\d\d)(\d\d)$/;
        @list = $_ =~ /^(\d\d\d\d)(\d\d)(\d\d)(\d\d)$/             if /^(\d\d\d\d)(\d\d)(\d\d)(\d\d)$/;
        @list = $_ =~ /^(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)$/       if /^(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)$/;
        @list = $_ =~ /^(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)$/ if /^(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)$/;
    }

    for my $i (0 .. 5) {$list[$i] = "00" unless $list[$i];}

return @list;
}


sub date2str {
#-------------------------------------------------------------------------------------
#  This routine takes a list containing a date/time and returns a string
#  formatted as YYYYMMDDHH[MN[SS]].
#
#  Input: @list = ($yyyy, $mm, $dd, $hh, $mn, $ss)
#
#  Out  : $string = YYYYMMDDHH[MN[SS]]
#-------------------------------------------------------------------------------------
#
    my @list = @_;

    if (scalar @list < 4) {
        my $mesg = "Missing values in date/time list (@list) in EMS_time::date2str";
        &EMS_util::emsprint(3,9,144,1,1,$mesg);
        return;
    }

    foreach (@list) {$_ = sprintf("%02d", $_);}

    my $string = join '' => @list; $string += 0;

return $string;
}


