#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Method.pm
#
#  DESCRIPTION:  Contains basic acquisition routines for bufrgruven
#                At least that's the plan
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  11.0
#      CREATED:  06/28/2011 10:31:20 PM
#     REVISION:  ---
#===============================================================================
#
package Method;
require 5.8.0;
use strict;
use warnings;
use English;
use Time::HiRes qw (time);
use File::stat;
use vars qw (%Bgruven $mesg); 


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
    foreach my $rout qw (curl wget) {$rhttp{$rout} = &Utils::findcmd($rout);}

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
        my $log  = "$Bgruven{GRUVEN}->{DIRS}{logs}/download_http.log";

        system($rhttp{wget} ? "$rhttp{wget} -a $log -L -nv --connect-timeout=30 --read-timeout=1200 -t 3 -O $lfile http://$host$rfile" :
                              "curl -C -s -f --connect-timeout 30 --max-time 1200  http://$host$rfile -o $lfile >& $log"); my $status = $?;
        
        &Love::int_handle if $status == 2;

        $secs = time() - $secs; $secs = 0.5 unless $secs;

        if ($status or ! -e $lfile) {
            $ENV{VERBOSE} = 1;
            &Utils::modprint(0,1,96,0,2,"- Failed for some unknown reason ($status)","Problem with remote host or local file system?");
            &Utils::rm($lfile); next;
        }

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
            &Utils::modprint(0,1,96,0,2,"- Success   ($mbps mb/s)");
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
            system "scp -q -p $host:$rfile $lfile >& /dev/null";
        } else {
            &Utils::modprint(5,11,256,0,0,"Copying $rfile");
            system "cp $rfile $lfile" if -e $rfile and ! -d $rfile;
        }
        $secs = time() - $secs; $secs = 0.5 unless $secs;


        if (my $sf = stat($lfile)) {
            my $lsize = $sf->size; $lsize =~ tr/,|\.//d; $lsize+=0;
            my $size = &Utils::kbmb($lsize);
            my $mbps = $size*100/$secs; $mbps = sprintf("%.2f",$mbps*0.01);
            &Utils::modprint(0,1,96,0,1,"- Success ($mbps mb/s)");
        } else {
            &Utils::modprint(0,1,96,0,1,"- Not Currently Available");
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
                &Utils::modprint(0,1,96,0,1,"- Success ($mbps mb/s)");
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
    my $log = "$ENV{BGRUVEN}/logs/available\.log"; &Utils::rm($log);
    my @size=();
    my %rhttp=();

    my ($meth, $host, $file) = @_;

    if ($meth =~ /http/i) {

        foreach my $rout qw (curl wget) {$rhttp{$rout} = &Utils::findcmd($rout);}

        #  Flags for wget:
        #    -T   : timeout length
        #    -t   : attempt
        #
        system($rhttp{wget} ? "$rhttp{wget} -o $log -T 3 -t 1 --spider http://$host$file" : "$rhttp{curl} -o $log --connect-timeout 3 -sI http://$host$file");

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
%Bgruven = %Moveit::Bgruven;
use File::stat;

    my ($host,$remdir,$type) = @_;

    my $ver   = $ENV{VERBOSE};
    my $sleep = 0.5 ; #  number of seconds between file transfers in case the remote
                      #  system can't keep up.
    my $bytestomb  = 1/1048576;

    my @files = @{$Bgruven{DATA}->{$type}};

    &Utils::modprint(0,11,144,1,2,"Initiating secure copy of $type files to $host:$remdir");

    #  Create the remote directory.
    #
    if (system "ssh -q $host mkdir -p $remdir >& /dev/null") {
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

        if (system "scp -B -q -p $file $host:$remfile >& /dev/null") {
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
%Bgruven = %Moveit::Bgruven;

use File::stat;

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

        if (system "cp -f $file $remfile >& /dev/null") {
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
use Time::HiRes qw (time);
use File::stat;

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
use Time::HiRes qw (time);

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

