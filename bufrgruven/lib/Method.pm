#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Method.pm
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
package Method;
require 5.8.0;
use strict;
use warnings;
use English;



use if defined eval{require Time::HiRes;} >0,  "Time::HiRes" => qw(time);
use File::stat;
use vars qw (%Bgruven $mesg); 

use Files;


sub http {
#----------------------------------------------------------------------------------
#  This routine download the requested files to the local system via http.
#  If necessary, the files will be unpacked and a list of downloaded files
#  is returned that can be compared to that requested. In the event of a
#  problem an empty list will be returned.
#----------------------------------------------------------------------------------
#
%Bgruven = %Acquire::Bgruven;

    my @afiles=();

    my ($host, %files) = @_;

    my $ver = $ENV{VERBOSE};

    #  Locate the curl and wget commands
    #
    my %rhttp = ();
    my @routs = qw(curl wget);
    foreach my $rout (@routs) {$rhttp{$rout} = &Utils::findcmd($rout);}

    unless ($rhttp{curl} or $rhttp{wget}) {
        $mesg = "Could not find either \"curl\" or \"wget\" routines on your system, which are required to ".
                "download files via http. Since these routines are available with most Linux distributions ".
                "it is likely that were left out during the OS install."; $ENV{VERBOSE} = 1;
        &Utils::modprint(3,11,96,2,1,$mesg);
        $ENV{VERBOSE} = $ver;
        return;
    }

    &Utils::modprint(0,11,96,1,2,"Initiating HTTP connection to $host");

    for my $lfile (sort keys %files) {

        my $rfile = $files{$lfile};
        my $ufile = $lfile;  # Unpacked filename in case file is compressed on remote server
        my $rsize = 0;

        #  Before continuing, we need to address the condition where the files on the remote
        #  system and packed, as indicated by a ".bz2", ".gz", or ".bz" extention. If the
        #  user wants them unpacked on the local side then the LOCFIL entry will have the
        #  suffix removed; however, the suffix must be added temporarily to the local
        #  file before the unpacking can occur.
        #
        if ($rfile =~ /(.gz)$|(.bz2)$|(.bz)$/) {
            $lfile = "$lfile\.gz"  if $rfile =~ /(.gz)$/;
            $lfile = "$lfile\.bz"  if $rfile =~ /(.bz)$/;
            $lfile = "$lfile\.bz2" if $rfile =~ /(.bz2)$/;
        }

        &Utils::modprint(5,13,256,0,0,sprintf ("Checking if available %s ",$rfile));

        #  Try next file if not available
        #
        unless ($rsize = &available('http',$host,$rfile)) {&Utils::modprint(0,1,96,0,1,"- Not currently available"); next;}
        
        #  Continue if available
        #
        &Utils::modprint(0,1,96,0,1,sprintf("- Available (%s mb)",&Utils::kbmb($rsize)));

        &Utils::modprint(5,13,256,0,0,sprintf ("Attempting to acquire %s ",$rfile));

        my $secs = time();
        my $log  = "$Bgruven{GRUVEN}->{DIRS}{logs}/download_http.log.$$";


        system($rhttp{wget} ? "$rhttp{wget} -a $log -L -nv --connect-timeout=30 --read-timeout=1200 -t 3 -O $lfile http://$host$rfile" :
                              "$rhttp{curl} -s -f --connect-timeout 30 --max-time 1200  http://$host$rfile -o $lfile >& $log");

        my $status = $? >> 8; &Love::int_handle if $status == 2;

        $secs = time() - $secs; $secs = 0.5 unless $secs;

        if ($status or ! -e $lfile) {
            my $reason    = $rhttp{wget} ? &WgetExitCodes($status) : &CurlExitCodes($status);
            $status       = "$status, $reason" if $reason;
            $ENV{VERBOSE} = 1;
            &Utils::modprint(0,1,96,0,2,"- Failed ($status)");
            &Utils::modprint(0,16,256,0,2,'Problem with remote host or local file system?') unless $reason;
            system "cat $log >> $Bgruven{GRUVEN}->{DIRS}{logs}/failed_download_http.log";
            &Utils::rm($lfile); next;
        }
        &Utils::rm($log);


        #  The file exists so interrogate it
        #
        my $sf = stat($lfile); 
        my $lsize = $sf->size; $lsize =~ tr/,|\.//d; $lsize+=0;

        unless ($lsize) { 
            &Utils::modprint(0,1,96,0,2,"- Zero Byte File", "File size on local system is zero bytes. Problem with remote host or local file system?");
            &Utils::rm($lfile); next;
        }
        
        if ($lsize == $rsize) {
            my $lsmb = &Utils::kbmb($lsize); 
            my $mbps = $lsmb*100/$secs; $mbps = sprintf("%.2f",$mbps*0.01);
            my $sm = $Bgruven{GRUVEN}->{INFO}{sm}[int rand @{$Bgruven{GRUVEN}->{INFO}{sm}}]; 
            &Utils::modprint(0,1,96,0,2,sprintf("- %-23s ($mbps mb/s)","\"$sm\""));
        } else {
            my $lsmb = &Utils::kbmb($lsize);
            my $rsmb = &Utils::kbmb($rsize);
            &Utils::modprint(0,1,96,0,2,"- Size mismatch - $rsmb mb (remote) Vs. $lsmb mb (local)");
            &Utils::rm($lfile); next;
        }

        ($lfile ne $ufile) ? push @afiles => &Files::unpack($lfile) : push @afiles => $ufile;
    }
    
return @afiles;
}


sub https {
#----------------------------------------------------------------------------------
#  This routine download the requested files to the local system via https.
#  If necessary, the files will be unpacked and a list of downloaded files
#  is returned that can be compared to that requested. In the event of a
#  problem an empty list will be returned.
#----------------------------------------------------------------------------------
#
%Bgruven = %Acquire::Bgruven;

    my @afiles=();

    my ($host, %files) = @_;

    my $ver = $ENV{VERBOSE};

    #  Locate the curl and wget commands
    #
    my %rhttp = ();
    my @routs = qw(curl wget);
    foreach my $rout (@routs) {$rhttp{$rout} = &Utils::findcmd($rout);}

    unless ($rhttp{curl} or $rhttp{wget}) {
        $mesg = "Could not find either \"curl\" or \"wget\" routines on your system, which are required to ".
                "download files via https. Since these routines are available with most Linux distributions ".
                "it is likely that were left out during the OS install."; $ENV{VERBOSE} = 1;
        &Utils::modprint(3,11,96,2,1,$mesg);
        $ENV{VERBOSE} = $ver;
        return;
    }

    &Utils::modprint(0,11,96,1,2,"Initiating HTTPS connection to $host");


    for my $lfile (sort keys %files) {

        my $rfile = $files{$lfile};
        my $ufile = $lfile;  # Unpacked filename in case file is compressed on remote server
        my $rsize = 0;

        #  Before continuing, we need to address the condition where the files on the remote
        #  system and packed, as indicated by a ".bz2", ".gz", or ".bz" extention. If the
        #  user wants them unpacked on the local side then the LOCFIL entry will have the
        #  suffix removed; however, the suffix must be added temporarily to the local
        #  file before the unpacking can occur.
        #
        if ($rfile =~ /(.gz)$|(.bz2)$|(.bz)$/) {
            $lfile = "$lfile\.gz"  if $rfile =~ /(.gz)$/;
            $lfile = "$lfile\.bz"  if $rfile =~ /(.bz)$/;
            $lfile = "$lfile\.bz2" if $rfile =~ /(.bz2)$/;
        }

        &Utils::modprint(5,13,256,0,0,sprintf ("Checking if available %s ",$rfile));

        #  Try next file if not available
        #
        unless ($rsize = &available('https',$host,$rfile)) {&Utils::modprint(0,1,96,0,1,"- Not currently available"); next;}

        #  Continue if available
        #
        &Utils::modprint(0,1,96,0,1,sprintf("- Available (%s mb)",&Utils::kbmb($rsize)));

        &Utils::modprint(5,13,256,0,0,sprintf ("Attempting to acquire %s ",$rfile));

        my $secs = time();
        my $log  = "$Bgruven{GRUVEN}->{DIRS}{logs}/download_https.log.$$";

        system($rhttp{wget} ? "$rhttp{wget} -a $log --no-check-certificate -L -nv --connect-timeout=30 --read-timeout=1200 -t 3 -O $lfile https://$host$rfile" :
                              "$rhttp{curl} -s -f -k --connect-timeout 30 --max-time 1200  https://$host$rfile -o $lfile >& $log");

        my $status = $? >> 8; &Love::int_handle if $status == 2;

        $secs = time() - $secs; $secs = 0.5 unless $secs;

        if ($status or ! -e $lfile) {
            my $reason    = $rhttp{wget} ? &WgetExitCodes($status) : &CurlExitCodes($status);
            $status       = "$status, $reason" if $reason;
            $ENV{VERBOSE} = 1;
            &Utils::modprint(0,1,96,0,2,"- Failed ($status)");
            &Utils::modprint(0,16,256,0,2,'Problem with remote host or local file system?') unless $reason;
            system "cat $log >> $Bgruven{GRUVEN}->{DIRS}{logs}/failed_download_https.log";
            &Utils::rm($lfile); next;
        }
        &Utils::rm($log);


        #  The file exists so interrogate it
        #
        my $sf = stat($lfile);
        my $lsize = $sf->size; $lsize =~ tr/,|\.//d; $lsize+=0;

        unless ($lsize) { 
            &Utils::modprint(0,1,96,0,2,"- Zero Byte File", "File size on local system is zero bytes. Problem with remote host or local file system?");
            &Utils::rm($lfile); next;
        }

        if ($lsize == $rsize) {
            my $lsmb = &Utils::kbmb($lsize);
            my $mbps = $lsmb*100/$secs; $mbps = sprintf("%.2f",$mbps*0.01);
            my $sm = $Bgruven{GRUVEN}->{INFO}{sm}[int rand @{$Bgruven{GRUVEN}->{INFO}{sm}}];
            &Utils::modprint(0,1,96,0,2,sprintf("- %-23s ($mbps mb/s)","\"$sm\""));
        } else {
            my $lsmb = &Utils::kbmb($lsize);
            my $rsmb = &Utils::kbmb($rsize);
            &Utils::modprint(0,1,96,0,2,"- Size mismatch - $rsmb mb (remote) Vs. $lsmb mb (local)");
            &Utils::rm($lfile); next;
        }

        ($lfile ne $ufile) ? push @afiles => &Files::unpack($lfile) : push @afiles => $ufile;
    }

return @afiles;
}




sub copy {
#----------------------------------------------------------------------------------
#  This routine copies the requested files to the local system via the scp or cp
#  commands.  The unix "copy" command will be used if the $host is 'LOCAL'; 
#  otherwise the SSH secure copy (SCP) command will be used.
#----------------------------------------------------------------------------------
#
%Bgruven = %Acquire::Bgruven;

    my @afiles=();

    my ($host, %files) = @_;

    my $ver = $ENV{VERBOSE};

    &Utils::modprint(0,9,96,1,2,"Copying BUFR files to local directory: $Bgruven{GRUVEN}->{DIRS}{bufdir}");

    for my $lfile (sort keys %files) {

        my $rfile = $files{$lfile};
        my $ufile = $lfile;  # Unpacked filename in case file is compressed on remote server


        if ($rfile =~ /(.gz)$|(.bz2)$|(.bz)$/) {
            $lfile = "$lfile\.gz"  if $rfile =~ /(.gz)$/;
            $lfile = "$lfile\.bz"  if $rfile =~ /(.bz)$/;
            $lfile = "$lfile\.bz2" if $rfile =~ /(.bz2)$/;
        }

        my $secs = time();
        if ($host !~ /local/i) {
            &Utils::modprint(5,11,256,0,0,"Secure copy from $host:$rfile");
            system "scp -q -p $host:$rfile $lfile  > /dev/null 2>&1";
        } else {
            &Utils::modprint(5,11,256,0,0,"Copying $rfile");
            system "cp $rfile $lfile" if -e $rfile and ! -d $rfile;
        }
        $secs = time() - $secs; $secs = 0.5 unless $secs;


        if (my $sf = stat($lfile)) {
            my $lsize = $sf->size; $lsize =~ tr/,|\.//d; $lsize+=0;
            my $size = &Utils::kbmb($lsize);
            my $mbps = $size*100/$secs; $mbps = sprintf("%.2f",$mbps*0.01);
            my $sm = $Bgruven{GRUVEN}->{INFO}{sm}[int rand @{$Bgruven{GRUVEN}->{INFO}{sm}}];
            &Utils::modprint(0,1,96,0,2,sprintf("- %-23s ($mbps mb/s)","\"$sm\""));
        } else {
            &Utils::modprint(0,1,96,0,1,"- Not Currently Available");
            next;
        }
        ($lfile ne $ufile) ? push @afiles => &Files::unpack($lfile) : push @afiles => $ufile;
    }    


return @afiles;
}


sub ftp {
#----------------------------------------------------------------------------------
#  This routine copies the requested files to the local system via the FTP
#  command.  It takes an argument list consisting of the ftp hostname or IP
#  and a hash containing the remote and local files.
#----------------------------------------------------------------------------------
#
use Net::FTP;

%Bgruven = %Acquire::Bgruven;

    my @afiles=();
    my $ver   = $ENV{VERBOSE};

    my ($err, $ftp);

    my ($host,%files) = @_;

    &Utils::modprint(0,11,96,1,2,"Initiating FTP connection to $host");

    $ENV{FTP_PASSIVE} = 1;
    #  Establish the FTP connection to $host or report failure
    #
    $err=5;
    while ($err > 0) {
#       $err = ($ftp=Net::FTP->new(lc $host, Timeout => 20, Debug => 10000)) ? 0 : $err-2; #  Debugging
        $err = ($ftp=Net::FTP->new(lc $host, Timeout => 20)) ? 0 : $err-2;
        if ($@ and $@ =~ /hostname/i) {$ENV{VERBOSE} = 1; &Utils::modprint(6,14,144,0,1,"While acquiring BUFR files from $host: CONNECTION ERROR - $@");}
        elsif ($err) {$ENV{VERBOSE} = 1; &Utils::modprint(6,14,144,0,1,sprintf("While acquiring BUFR files from $host: CONNECTION ERROR: Attempt #%s of 3 - $@",int((5-$err)/2)));}
    } $ENV{VERBOSE} = $ver;
    return if $err;


    #  Log into server. Note that this step will fail if non-anonymous login information
    #  is not located in ~/.netrc file
    #
    unless ($ftp->login()) {$ENV{VERBOSE} = 1;&Utils::modprint(6,14,96,0,2,"LOGIN ERROR",$ftp->message);$ENV{VERBOSE} = $ver; return;}
    $ftp->binary();

    for my $lfile (sort keys %files) {

        my $rfile = $files{$lfile};
        my $ufile = $lfile;  # Unpacked filename in case file is compressed on remote server

        if ($rfile =~ /(.gz)$|(.bz2)$|(.bz)$/) {
            $lfile = "$lfile\.gz"  if $rfile =~ /(.gz)$/;
            $lfile = "$lfile\.bz"  if $rfile =~ /(.bz)$/;
            $lfile = "$lfile\.bz2" if $rfile =~ /(.bz2)$/;
        }


        &Utils::modprint(5,13,256,0,0,sprintf("Attempting to acquire %s ",$rfile));

        my $secs = time();
        if ($ftp->get($rfile,$lfile)) {
            $secs = time() - $secs; $secs = 0.5 unless $secs;

            if (my $sf = stat($lfile)) {
                my $lsize = $sf->size; $lsize =~ tr/,|\.//d; $lsize+=0;
                my $size  = &Utils::kbmb($lsize);
                my $mbps  = $size*100/$secs; $mbps = sprintf("%.2f",$mbps*0.01);
                my $sm = $Bgruven{GRUVEN}->{INFO}{sm}[int rand @{$Bgruven{GRUVEN}->{INFO}{sm}}];
                &Utils::modprint(0,1,96,0,2,sprintf("- %-23s ($mbps mb/s)","\"$sm\""));
            } else {
                &Utils::modprint(0,1,96,0,1,"- Not Currently Available"); next;
            }

        } elsif ($ftp->message =~ /No such file or directory|Failed to open file/i) {
            &Utils::modprint(0,1,96,0,1,"- Not Currently Available"); next;
        } else {
            $ftp->message ? &Utils::modprint(6,13,96,0,2,$ftp->message) : &Utils::modprint(6,14,96,0,2,'Unknown FTP failure'); next;
        }
        ($lfile ne $ufile) ? push @afiles => &Files::unpack($lfile) : push @afiles => $ufile;
    }

return @afiles;
}


sub available {
#----------------------------------------------------------------------------------
#  This routine checks the availability of a file given the method of acquisition
#  the host and filename including path. It returns the size of the file if
#  successful or 0 upon failure.
#----------------------------------------------------------------------------------
#
    my @size=();
    my %rhttp=();

    my ($meth, $host, $file) = @_;

    my $log = "$ENV{BGRUVEN}/logs/available.log.$$"; &Utils::rm($log);

    if ($meth =~ /http/i) {

        my @routs = qw(curl wget);
        foreach my $rout (@routs) {$rhttp{$rout} = &Utils::findcmd($rout);}

        #  Specify the options and flags being passed to curl|wget
        #
        my $tv = 20;  # Set timeout value to 20s

        #  Flags for wget:
        #    --dns-timeout     : number of seconds to wait for DNS hostname resolution
        #    --connect-timeout : number of seconds to wait to connect
        #    -t                : number of attempts
        #    --spider          : Spider mode - just check if file exists
        #
        my $wopts = "--dns-timeout=$tv --connect-timeout=$tv -t 1 --spider";


        #  Flags for curl:
        #    --connect-timeout   : number of seconds to wait for a connection
        #    -s                  : Silent mode - no status bar
        #    -I                  : Curl's "spider mode"
        #
        my $copts = "--connect-timeout $tv -sI";

        if ($meth =~ /https/i) {
            system($rhttp{wget} ? "$rhttp{wget} -o $log --no-check-certificate $wopts  https://$host$file" : "$rhttp{curl} -o $log -k $copts https://$host$file");
        } else {
            system($rhttp{wget} ? "$rhttp{wget} -o $log $wopts  http://$host$file" : "$rhttp{curl} -o $log $copts  http://$host$file");
        }

        if (-s $log) {open OF => $log; while (<OF>) {@size = split ' ', $_ if s/Content-Length:|Length://i;} close OF;}

        $_ =~ tr/,|\.//d foreach @size;
    }
    &Utils::rm($log);
    $size[0]+=0 if @size;

return @size ? $size[0] : 0;
}


sub put_scp {
#----------------------------------------------------------------------------------
#  This routine transfers a list of files via secure copy (scp)
#----------------------------------------------------------------------------------
#
use File::stat;

    %Bgruven = %Moveit::Bgruven;

    my ($host,$remdir,$type) = @_;

    my $ver   = $ENV{VERBOSE};
    my $sleep = 0.5 ; #  number of seconds between file transfers in case the remote
                      #  system can't keep up.
    my $bytestomb  = 1/1048576;

    my @files = @{$Bgruven{DATA}->{$type}};

    &Utils::modprint(0,11,144,1,2,"Initiating secure copy of $type files to $host:$remdir");

    #  Create the remote directory.
    #
    if (system "ssh -q $host mkdir -p $remdir  > /dev/null 2>&1") {
        $ENV{VERBOSE} = 1;
        $mesg = "Make sure that you are configured to run ssh commands such as:\n\n".
                "  % ssh $host mkdir -p $remdir \n\nbefore trying SCP again.";
        &Utils::modprint(6,11,144,1,1,"SSH Problem creating $remdir on $host",$mesg);
        $ENV{VERBOSE} = $ver;
        return;
    }

    my $len=0;
    foreach (@files) {
        next unless $_;
        my $f = &Utils::popit($_);
        $len = length $f if length $f > $len;
    }
    $len+=18;


    my $n = 1;
    foreach my $file (@files) {

        my $sf    = stat($file);
        my $lsize = $sf->size; $lsize =~ tr/,|\.//d; $lsize+=0;

        next unless $lsize;

        my $locfile = &Utils::popit($file);
        my $remfile = $remdir;

        $mesg = "Transfering File: $locfile";
        $mesg = sprintf("%-${len}s -",$mesg);
        &Utils::modprint(5,13,144,0,0,$mesg);


        unless (-s $file) {&Utils::modprint(0,1,144,0,0,"is Missing! Possible configuration NFS problem?");next;}

        if (system "scp -B -q -p $file $host:$remfile  > /dev/null 2>&1") {
            $ENV{VERBOSE} = 1;
            &Utils::modprint(0,1,144,0,1,"Failed");
            &Utils::modprint(6,11,144,1,1,"Premature termination of SCP to $host");
            $ENV{VERBOSE} = $ver;
            return;
        } else {
            &Utils::modprint(0,1,144,0,1,"Success");
            sleep $sleep unless $file eq $files[-1];
        }
        $n++;
    }

    my $date = gmtime();
    &Utils::modprint(0,11,144,1,2,"Completed secure file copy at $date UTC");

return;
}


sub put_copy {
#----------------------------------------------------------------------------------
#  This routine transfers a list of files via secure copy (scp)
#----------------------------------------------------------------------------------
#
use File::stat;

    %Bgruven = %Moveit::Bgruven;

    my ($remdir,$type) = @_;

    my $ver   = $ENV{VERBOSE};
    my $sleep = 0.5 ; #  number of seconds between file transfers in case the remote
                      #  system can't keep up.
    my $bytestomb  = 1/1048576;

    my @files = @{$Bgruven{DATA}->{$type}};

    &Utils::modprint(0,11,144,1,2,"Initiating copy of $type files to $remdir");

    my $len=0;
    foreach (@files) {
        next unless $_;
        my $f = &Utils::popit($_);
        $len = length $f if length $f > $len;
    }
    $len+=18;


    my $n = 1;
    foreach my $file (@files) {

        my $sf    = stat($file);
        my $lsize = $sf->size; $lsize =~ tr/,|\.//d; $lsize+=0;

        next unless $lsize;

        my $locfile = &Utils::popit($file);
        my $remfile = "$remdir/$locfile";

        if (&Utils::mkdir($remdir)) {
            $ENV{VERBOSE} = 1;
            &Utils::modprint(3,13,144,1,1,"$remdir could not be created.");
            &Utils::modprint(0,11,144,1,2,"File copy terminated");
            $ENV{VERBOSE} = $ver;
            return;
        }

        $mesg = "Copying File : $locfile";
        $mesg = sprintf("%-${len}s -",$mesg);
        &Utils::modprint(5,13,144,0,0,$mesg);

        unless (-e $file) {&Utils::modprint(0,1,144,0,0,"is Missing! Possible configuration NFS problem?");next;}

        if (system "cp -f $file $remfile  > /dev/null 2>&1") {
            $ENV{VERBOSE} = 1;
            &Utils::modprint(0,1,144,0,1,"Failed");
            &Utils::modprint(6,11,144,1,1,"Premature termination of file copy");
            $ENV{VERBOSE} = $ver;
            return;
        } else {
            &Utils::modprint(0,1,144,0,1,"Success");
            sleep $sleep unless $file eq $files[-1];
        }
        $n++;
    }

    my $date = gmtime();
    &Utils::modprint(0,11,144,1,2,"Completed local file copy at $date UTC");

return;
}


sub put_ftp {
#----------------------------------------------------------------------------------
#  This routine transfers a list of files via file transfer protocol (ftp)
#----------------------------------------------------------------------------------
#
use Net::FTP;
use File::stat;
use if defined eval{require Time::HiRes;} >0,  "Time::HiRes" => qw(time);

    %Bgruven = %Moveit::Bgruven;


    my $DEBUG = 0;   # 1 - ON, 0 - OFF
    my $TO    = 120; # Timeout

    my ($host, $remdir, $type) = @_;

    my $ver   = $ENV{VERBOSE};
    my $sleep = 0.5; #  number of seconds between file transfers in case the remote
                     #  system can't keep up.
    my $bytestomb  = 1/1048576;

    my @files = &Utils::rmdups(@{$Bgruven{DATA}->{$type}});

    my $pass = defined $ENV{FTP_PASSIVE} ? $ENV{FTP_PASSIVE} : 1;

    &Utils::modprint(0,11,144,1,2,"Initiating FTP process of $type files to $host");


    #  Set up ftp connection
    #
    my $ftp;
    unless ($ftp=Net::FTP->new(lc $host, Debug => $DEBUG, Passive => $pass)) {$ENV{VERBOSE} = 1;&Utils::modprint(6,14,144,0,1,"While FTPing $type files to $host: CONNECTION ERROR - $@");$ENV{VERBOSE} = $ver;return;}
    unless ($ftp->login())                                                   {$ENV{VERBOSE} = 1;&Utils::modprint(6,14,144,0,1,sprintf("While FTPing $type files to $host: LOGIN ERROR : %s",$ftp->message));$ENV{VERBOSE} = $ver;return;}

    my $len=0;
    foreach (@files) {
        next unless $_;
        my $f = &Utils::popit($_);
        $len = length $f if length $f > $len;
    }
    $len+=18;

    $ftp->binary();
    $ftp->mkdir($remdir,'true');

    my $n=1;
    foreach my $file (sort @files) {

        my $sf    = stat($file);
        my $lsize = $sf->size; $lsize =~ tr/,|\.//d; $lsize+=0;

        next unless $lsize;

        my $lsmb = $lsize * $bytestomb;

        my $locfile = &Utils::popit($file);
        my $remfile = "$remdir/$locfile";
        
        $mesg = "Transfering File: $locfile";
        $mesg = sprintf("%-${len}s -",$mesg);
        &Utils::modprint(5,13,144,0,0,$mesg);

        my $secs = time();
        if (!$ftp->put($file,$remfile)) {
            $ENV{VERBOSE} = 1;
            &Utils::modprint(0,1,144,0,1,"Failed");
            &Utils::modprint(0,11,92,1,2,sprintf ("Premature termination of FTP to $host - %s",$ftp->message));
            $ENV{VERBOSE} = $ver;
            return;
        } else {
            $secs = time() - $secs;
            my $mbps = $lsmb*100/$secs; $mbps = sprintf("%.2f",$mbps*0.01);
            &Utils::modprint(0,1,144,0,1,"Success at $mbps mb/s");
            sleep $sleep unless $file eq $files[-1];
        }
    }

    my $date = gmtime();
    &Utils::modprint(0,11,144,1,2,"Completed file FTP to $host at $date UTC");

return;
}


sub put_sftp {
#----------------------------------------------------------------------------------
#  This routine transfers a list of files via secure file transfer protocol (sftp)
#----------------------------------------------------------------------------------
#
use if defined eval{require Time::HiRes;} >0,  "Time::HiRes" => qw(time);

    %Bgruven = %Moveit::Bgruven;

    my ($host, $remdir, $type) = @_;

    my $ver   = $ENV{VERBOSE};
    my $ldir  = $Bgruven{GRUVEN}->{DIRS}{logs};
    my $log   = "$ldir/sftp.log.$$";

    my $sleep = 0.5; #  number of seconds between file transfers in case the remote
                     #  system can't keep up.


    my @files = &Utils::rmdups(@{$Bgruven{DATA}->{$type}});

    &Utils::modprint(0,11,144,1,2,"Initiating Secure FTP process of $type files to $host");

    #  Begin by creating the directory on the remote host. Note that I'm failing to trap
    #  for errors since if the directory already exists on the remote system SFTP will
    #  return a cryptic error that is not possible to distinguish from other errors. Thus
    #  we just have to let the user figure out the problem. Also, SFTP will not create
    #  more than one level of directories.
    #
    my $if = "$ldir/sftp\.in"; &Utils::rm($if);
    open (SFTP,">$if");
    print SFTP "mkdir -p $remdir\n";
    print SFTP "exit\n";
    close SFTP;
    if (system "sftp -b $if $host >& $log") {
        $ENV{VERBOSE} = 1;
        &Utils::modprint(6,11,86,1,2,"Premature termination of SFTP to $host","Here is what I found in $log");
        $mesg = `tail -12 $log`; $mesg =~ s/ +/ /g;
        &Utils::modprint(0,17,96,0,1,$mesg);
        &Utils::modprint(0,11,144,1,2,sprintf("Secure file transfer to %s terminated",lc $host));
        $ENV{VERBOSE} = $ver;
        return;
    } &Utils::rm($if); &Utils::rm($log);


    open (SFTP,">$if");
    foreach my $file (@files) {
        my $locfile = &Utils::popit($file);
        my $remfile = "$remdir/$locfile"; $remfile =~ s/\/\//\//g;
        print SFTP "put $file $remfile\n";
    }
    print SFTP "exit\n";
    close SFTP;

    if (system "sftp -b $if $host >& $log") {
       $ENV{VERBOSE} = 1;
       &Utils::modprint(6,11,86,1,2,"Premature termination of SFTP to $host","Here is what I found in $log");
       $mesg = `tail -12 $log`; $mesg =~ s/ +/ /g;
       &Utils::modprint(0,17,96,0,1,$mesg);
       &Utils::modprint(0,11,144,1,2,sprintf("Secure file transfer to %s terminated",lc $host));
       $ENV{VERBOSE} = $ver;
       return;
    } else {
       &Utils::modprint(0,13,144,1,1,"It appears that the SFTP was successful");
    } &Utils::rm($if); &Utils::rm($log);

    my $date = gmtime();
    &Utils::modprint(0,11,144,1,2,"Completed file FTP to $host at $date UTC");

return;
}


sub WgetExitCodes {
#=================================================================================
#  Initialize an array of Standard wget exit codes. This routine is only
#  for information purposes and should not be called unless wget returns
#  a non-zero value, so ignore the $_ == 0 condition.
#=================================================================================
#
    my $mesg = 'Unknown Cause';

    for (shift) {

       $mesg = ''                    if $_ == 0;
       $mesg = 'General Error'       if $_ == 1;
       $mesg = 'Parse error'         if $_ == 2;
       $mesg = 'File I/O Error'      if $_ == 3;
       $mesg = 'Network Failure'     if $_ == 4;
       $mesg = 'SSL verification failure' if $_ == 5;
       $mesg = 'Username/password authentication failure' if $_ == 6;
       $mesg = 'Protocol Errors'     if $_ == 7;
       $mesg = 'Server-issued Error' if $_ == 8;

    }

return $mesg;
}  #  WgetExitCodes


sub CurlExitCodes {
#=================================================================================
# Initialize an array of Standard Curl exit codes. This routine is only
# for information purposes and should not be called unless Curl returns
# a non-zero value, so ignore the $_ == 0 condition.
#=================================================================================
#
    my $mesg = 'Unknown Error';

    for (shift) {

        if (/^0$/)  {$mesg =  '';}
        if (/^1$/)  {$mesg =  'Unsupported protocol';}
        if (/^2$/)  {$mesg =  'Failed to initialize';}                                                              
        if (/^3$/)  {$mesg =  'URL format problem. The syntax was not correct';}                                    
        if (/^4$/)  {$mesg =  'URL user format error';}                                                             
        if (/^5$/)  {$mesg =  'Could not resolve proxy';}                                                           
        if (/^6$/)  {$mesg =  'Could not resolve host';}                                                            
        if (/^7$/)  {$mesg =  'Failed to connect to host';}                                                         
        if (/^8$/)  {$mesg =  'FTP weird server reply';}                                                            
        if (/^9$/)  {$mesg =  'FTP access denied';}                                                                 
        if (/^10$/) {$mesg =  'FTP user/password incorrect';}                                                       
        if (/^11$/) {$mesg =  'FTP weird PASS reply';}                                                              
        if (/^12$/) {$mesg =  'FTP weird USER reply';}                                                              
        if (/^13$/) {$mesg =  'FTP weird PASV reply';}                                                              
        if (/^14$/) {$mesg =  'FTP weird line 227 format';}                                                         
        if (/^15$/) {$mesg =  'FTP can not get host IP';}                                                           
        if (/^16$/) {$mesg =  'FTP can not reconnect';}                                                             
        if (/^17$/) {$mesg =  'FTP could not set binary';}                                                          
        if (/^18$/) {$mesg =  'Only a part of the file was transfered';}                                            
        if (/^19$/) {$mesg =  'FTP could not download/access the given file';}                                      
        if (/^20$/) {$mesg =  'FTP write error';}                                                                   
        if (/^21$/) {$mesg =  'FTP quote error';}                                                                   
        if (/^22$/) {$mesg =  'Requested file was not found';}                                                      
        if (/^23$/) {$mesg =  'Local write error';}                                                                 
        if (/^24$/) {$mesg =  'User name badly specified';}                                                         
        if (/^25$/) {$mesg =  'FTP could not STOR file';}                                                           
        if (/^26$/) {$mesg =  'Read error';}                                                                        
        if (/^27$/) {$mesg =  'Out of memory';}                                                                     
        if (/^28$/) {$mesg =  'Operation timeout';}                                                                 
        if (/^29$/) {$mesg =  'FTP could not set ASCII';}                                                           
        if (/^30$/) {$mesg =  'FTP PORT failed';}                                                                   
        if (/^31$/) {$mesg =  'FTP could not use REST';}                                                            
        if (/^32$/) {$mesg =  'FTP could not use SIZE';}                                                            
        if (/^33$/) {$mesg =  'HTTP range error';}
        if (/^34$/) {$mesg =  'HTTP post error';}
        if (/^35$/) {$mesg =  'SSL handshaking failed';}
        if (/^36$/) {$mesg =  'FTP bad download resume';}
        if (/^37$/) {$mesg =  'FILE could not read file. Permissions?';}
        if (/^38$/) {$mesg =  'LDAP bind operation failed';}
        if (/^39$/) {$mesg =  'LDAP search failed';}
        if (/^40$/) {$mesg =  'The LDAP library was not found';}
        if (/^41$/) {$mesg =  'A required LDAP function was not found';}
        if (/^42$/) {$mesg =  'An application told curl to abort the operation';}
        if (/^43$/) {$mesg =  'A function was called with a bad parameter';}
        if (/^44$/) {$mesg =  'A function was called in a bad order';}
        if (/^45$/) {$mesg =  'A specified outgoing interface could not be used';}
        if (/^46$/) {$mesg =  'Bad password entered';}
        if (/^47$/) {$mesg =  'Too many redirects';}
        if (/^48$/) {$mesg =  'Unknown TELNET option specified';}
        if (/^49$/) {$mesg =  'Malformed telnet option';}
        if (/^52$/) {$mesg =  'The server did not reply anything';}
        if (/^53$/) {$mesg =  'SSL crypto engine not found';}
        if (/^54$/) {$mesg =  'Cannot set SSL crypto engine as default';}
        if (/^55$/) {$mesg =  'Failed sending network data';}
        if (/^56$/) {$mesg =  'Failure in receiving network data';}
        if (/^57$/) {$mesg =  'Share is in use (internal error)';}
        if (/^58$/) {$mesg =  'Problem with the local certificate';}
        if (/^59$/) {$mesg =  'could not use specified SSL cipher';}
        if (/^60$/) {$mesg =  'Problem with the CA cert (permission?)';}
        if (/^61$/) {$mesg =  'Unrecognized transfer encoding';}
        if (/^62$/) {$mesg =  'Invalid LDAP URL';}
        if (/^63$/) {$mesg =  'Maximum file size exceeded';}
    }


return $mesg;
} #  CurlExitCodes


