#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Process.pm
#
#  DESCRIPTION:  Contains basic utility routines for the BUFRgruven routine
#                At least that's the plan
#
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  20.53.3
#      CREATED:  30 December 2020
#===============================================================================
#
package Process;
require 5.8.0;
use strict;
use warnings;
use English;


use if defined eval{require Time::HiRes;} >0,  "Time::HiRes" => qw(time);
use vars qw (%Bgruven $mesg); 
use Utils;

sub bufr {
#----------------------------------------------------------------------------------
#   Calls the various BUFR file processing routines
#----------------------------------------------------------------------------------
#
#  Bring in the Bgruven hash from main
#
%Bgruven = %main::Bgruven;

    if (! $Bgruven{PROCESS}->{STATIONS}{newbufrs} and ! $Bgruven{GRUVEN}->{OPTS}{forcep}) {
       &Utils::modprint(6,6,96,1,2,"There were no new BUFR files available to process - Sigh :(");
    } elsif ($Bgruven{GRUVEN}->{OPTS}{noprocess} and %{$Bgruven{PROCESS}->{STATIONS}{process}}) {
        &Utils::modprint(6,6,96,1,2,"Your BUFR file processing is turned turned OFF - I hope that's what you wanted");
    } else {
        if (%{$Bgruven{PROCESS}->{STATIONS}{process}} and ! $Bgruven{GRUVEN}->{OPTS}{noprocess}) {
            &process_bufr   or &Love::died($mesg);  #  Processes the BUFR data into GEMPAK sounding files
            &process_bufkit or &Love::died($mesg);  #  Processes the GEMPAK sounding files into BUFKIT format
        }
    }

    chdir $Bgruven{HOME};

return %Bgruven;
}


sub  process_bufr {
#----------------------------------------------------------------------------------
#    Processes the BUFR files into GEMPAK sounding files
#----------------------------------------------------------------------------------
#
    my ($gems, $ascs) = &bufr2gem; 

    @{$Bgruven{DATA}->{GEMPAK}} = @$gems;
    @{$Bgruven{DATA}->{ASCII}}  = @$ascs;

    unless (@{$Bgruven{DATA}->{GEMPAK}}) {$mesg = "You had a problem processing BUFR files to GEMPAK format!"; return;}

return 1;
}



sub process_bufkit {
#----------------------------------------------------------------------------------
#    Processes the GEMPAK sounding files into BUFKIT files
#----------------------------------------------------------------------------------
#
    @{$Bgruven{DATA}->{BUFKIT}}  = ();
    @{$Bgruven{DATA}->{BUFKITP}} = ();

    if ($Bgruven{GRUVEN}->{OPTS}{nobufkit}) {&Utils::modprint(6,9,96,1,2,"No BUFKIT for You! Bufkit file processing turned OFF");return 1;}
        
    my $bufkts = &gem2bfkt;

    unless (@$bufkts) {$mesg = "You had a problem creating BUFKIT files!"; return;}

    foreach (@$bufkts) {
        &Utils::popit($_) =~ /^\d\d\d\d/ ? push @{$Bgruven{DATA}->{BUFKITP}} => $_ : push @{$Bgruven{DATA}->{BUFKIT}} => $_;
    }

return 1;
}


sub bufr2gem {
#----------------------------------------------------------------------------------
#  This routine converts BUFR files to GEMPAK sounding files using the namsnd
#  routine. It returns a list if gempak sourding and surface files.
#----------------------------------------------------------------------------------
#
    my (@gemfls, @ascfls)=();    #  Initialize the list of files to be created

    my $MAX_GEM_STATIONS = 30000;# The maximum number of stations that can be handled
                                 # by GEMPAK as defined in the GEMPRM.PRM file
                                 #

    my $MAX_GEM_TIMES    = 300;  # The maximum output times that can be handled
                                 # by GEMPAK as defined in the GEMPRM.PRM file
                                 #

    my %bufrs = %{$Bgruven{PROCESS}->{STATIONS}{process}}; return (\@gemfls, \@ascfls) unless %bufrs;


    #  If the --monolithic flag was passed, then this is where the logic becomes difficult because the 
    #  GEMPAK files do not need to be recreated if the BUFR file was downloaded and processed previously. 
    #  All the BUFR information already exists in the GEMPAK file. However, the names of the GEMPAK files 
    #  are needed for processing into BUFKIT and those are obtained below so we must to through part of 
    #  the GEMPAK conversion. Also, the monolithic BUFR file needs only to be processed once and not 
    #  multiple times as for the individual files.
    #
    if ($Bgruven{GRUVEN}->{OPTS}{mono}) { 
       my %mono=();
       foreach my $mod (keys %bufrs) {foreach my $stn (keys %{$bufrs{$mod}}) {$mono{$mod}{mono} = $bufrs{$mod}{$stn};}}
       %bufrs = %mono;
    }
    

    &Utils::modprint(0,2,96,1,1,sprintf("%5s  Creating GEMPAK sounding files from BUFR files",shift @{$Bgruven{GRUVEN}->{INFO}{rn}}));


    #  Create the gempak and ascii directories if necessary and delete any files in 
    #  the local working directory that are greater than 2 days old.
    #
    my @dirs = qw(gemdir ascdir);
    foreach my $dir (@dirs) {
        &Utils::mkdir($Bgruven{GRUVEN}->{DIRS}{$dir});
        opendir DIR => $Bgruven{GRUVEN}->{DIRS}{$dir};
        foreach (readdir(DIR)) {next if /^\./; &Utils::rm("$Bgruven{GRUVEN}->{DIRS}{$dir}/$_") if -M "$Bgruven{GRUVEN}->{DIRS}{$dir}/$_" > 2;}
        closedir DIR;
    }

    
    #  Did the use want ascii profiles genarted?
    #
    my $ascii = $Bgruven{GRUVEN}->{OPTS}{noascii} ? 0 : @{$Bgruven{BINFO}->{EXPORT}{ASCII}} ? 1 : 1;


    # Turn off Ascii file creation with monolithic BUFR files
    #
    $ascii = 0 if $Bgruven{GRUVEN}->{OPTS}{mono};
    

    #  Get the list of placeholders for the filenames
    #
    my $ymd       = $Bgruven{PROCESS}->{DATE}{yyyymmdd};
    my $cc        = $Bgruven{PROCESS}->{DATE}{acycle};


    #   GEMPAK needs to have environment variables set
    #
    $ENV{NAWIPS} = "$Bgruven{HOME}/gempak";
    $ENV{GEMPDF} = "$ENV{NAWIPS}/pdf";
    $ENV{GEMNTS} = "$ENV{NAWIPS}/nts";
    $ENV{GEMEXE} = "$ENV{NAWIPS}/bin";
    $ENV{GEMPARM}= "$ENV{NAWIPS}/parm";
    $ENV{GEMTBL} = "$ENV{NAWIPS}/tables";

  
    my $exe = "$ENV{GEMEXE}/namsnd";
    # Now check for missing system libraries.
    #
    my @libs = &Utils::cklib($exe);
    if (@libs) {
        &Utils::modprint(6,11,144,1,1,"Missing System Libraries","You are missing necessary system libraries required for BUFR file processing:");
        &Utils::modprint(1,26,144,1,0,$_) foreach @libs;
        return (\@gemfls, \@ascfls)
    }


    #  Create a work directory for creating all the GEMPAK files
    #
    chdir $Bgruven{GRUVEN}->{DIRS}{gemdir};

    
    #  Begin the processing of the BUFR files with namsnd. Any ascii files will be moved following
    #  each BUFR file
    #
    my $pf=0;
    my $ens = (keys %bufrs) - 1;
    my @mbrs=();
    foreach my $mod (sort keys %bufrs) {

        my @phs = ($ymd, $cc, $Bgruven{BINFO}->{DSET}{dset}, $mod);

        my $gemsfc    = 'YYYYMMDDCC_MOD_bufr.sfc';      #  Define the GEMPAK surface filename
        my $gemaux    = 'YYYYMMDDCC_MOD_bufr.sfc_aux';  #  Define the aux GEMPAK surface filename
        my $gemsnd    = 'YYYYMMDDCC_MOD_bufr.snd';      #  Define the GEMPAK sounding filename


        #  Populate the date, time, and model placeholders in LOCFIL
        #
        for ($gemsfc, $gemsnd, $gemaux) {$_ = &Utils::fillit($_,@phs); $_ = "$Bgruven{GRUVEN}->{DIRS}{gemdir}/$_";}


        #  If processing a monolithic BUFR file then check whether the GEMPAK already exists, which 
        #  indicates that the file was processed previously and thus does not need to be processed again. 
        #  The exception is when the --forcep flag is passed.
        #
        if ($Bgruven{GRUVEN}->{OPTS}{mono}) {
            for ($gemsfc, $gemsnd, $gemaux) {push @gemfls => $_ if -s $_;}

            $Bgruven{GRUVEN}->{OPTS}{forcep} = 1 if $Bgruven{GRUVEN}->{OPTS}{forced};

            if (@gemfls == 3 and ! $Bgruven{GRUVEN}->{OPTS}{forcep}) {
                &Utils::modprint(1,11,144,1,1,sprintf("It appears the BUFR file has already been processed. Very well then, moving on."));
                return (\@gemfls, \@ascfls);
            } else {
                for ($gemsfc, $gemsnd, $gemaux) {&Utils::rm($_);}
                @gemfls=();
            }
        }

                
        #  Get the model family from the model name as this will be used to identify the packing files to use.
        #  This could be a problem should the underscore not be included in the name.
        #
        my ($mf, $me) = split /_/, $mod, 2;  $me = $mf unless $me;

        if ($pf ne $mf) {
            my $str = join ' ' => @mbrs; @mbrs=(); &Utils::modprint(0,1,144,0,0,"Completed ($str)") if $pf;
            &Utils::modprint(1,11,144,1,0,sprintf("Creating GEMPAK files for the %-8s %s",$mf,$ens ? 'ensemble members - ' : 'data set - '));
        }
        $pf = $mf;


        if ($Bgruven{GRUVEN}->{OPTS}{debug}) {
#           &Utils::modprint(1,5,144,1,0,"GEMPAK Sounding File   : $gemsnd");
#           &Utils::modprint(1,5,144,1,0,"GEMPAK Surface  File   : $gemsfc");
#           &Utils::modprint(1,5,144,1,1,"GEMPAK Aux Surface File: $gemaux") if $Bgruven{BINFO}->{GEMPAK}{packaux};
        }


        while (my ($stnm,$bufr) = each %{$bufrs{$mod}}) {

            my $stid = $ascii ? lc substr $Bgruven{PROCESS}->{STATIONS}{table}{numtoid}{$stnm},1,3 : 'none' ;
 
            my $log = "$Bgruven{GRUVEN}->{DIRS}{logs}/${mod}_gempak_namsnd.log"; &Utils::rm($log);
            &Utils::rm($_) for ("prof.$stid", "${mod}_namsnd.in", 'gemglb.nts', 'last.nts');

        
            #  Write the necessary information to the namsnd.in file
            #
            unless (open (GEMFILE,">${mod}_namsnd.in")) {&Utils::modprint(6,5,96,1,1,"You're not BUFRgruven in bufr2gem - Unable to open ${mod}_namsnd.in for writing!"); return (\@gemfls, \@ascfls);}

            (my $snpack = $Bgruven{BINFO}->{GEMPAK}{snpack}) =~ s/SREF/$mf/g;
            (my $sfpack = $Bgruven{BINFO}->{GEMPAK}{sfpack}) =~ s/SREF/$mf/g;

            unless (-e "$ENV{GEMTBL}/pack/$snpack" and -e "$ENV{GEMTBL}/pack/$sfpack") {
                $mesg = "You will have to locate the whereabouts of the necessary GEMPAK packing files for this data set, because I simply ".
                        "can not continue without them.  In case you are wondering they look like:\n\n".
                        
                        "    $ENV{GEMTBL}/pack/$snpack\n".
                        "And\n".         
                        "    $ENV{GEMTBL}/pack/$sfpack\n".
                        "And\n".
                        "    $ENV{GEMTBL}/pack/${sfpack}_aux\n\n".

                        "And don't run me again until your little problem is addressed!";

                &Utils::modprint(6,11,114,2,2,"Missing GEMPAK packing files",$mesg);

                @gemfls=(); @ascfls=();
                return (\@gemfls, \@ascfls);
            }

            print GEMFILE "SNOUTF = $gemsnd\n",
                          "SNPRMF = $ENV{GEMTBL}/pack/$snpack\n",
                          "SFPRMF = $ENV{GEMTBL}/pack/$sfpack\n",
                          "TIMSTN = $Bgruven{BINFO}->{GEMPAK}{timstn}\n";

            $Bgruven{BINFO}->{GEMPAK}{packaux} ? print GEMFILE "SFOUTF = $gemsfc+\n" :  print GEMFILE "SFOUTF = $gemsfc\n";
            $ascii                             ? print GEMFILE "SNBUFR = $bufr|$stid=$stnm\n" : print GEMFILE "SNBUFR = $bufr\n";

            print GEMFILE  "list\nrun\n \nexit\n"; close GEMFILE;

            if (&Utils::execute("$exe < ${mod}_namsnd.in", $log)) {
    
                my $rc = $? >> 8;
    
                my @lines=();
                open LOG => "$log"; @lines = <LOG>; close LOG;
    
                if ( ($? == 2) or (grep /Ctrl-C/i,@lines) ) {
                    &Utils::modprint(0,0,24,0,1,"Interrupted");
                    &Love::exit(99);
                }

                #  Else - continue to processes the failed processes
                #
                &Utils::modprint(0,1,24,0,1,"Failed (return code $rc)");

                my $sl = $#lines-10 < 0 ? 0 : $#lines-10;
                my $err = @lines ? join '' => @lines[$sl .. $#lines] : 0;

                my $elog = &Utils::popit($log);
                my $mesg0 = "Error converting BUFR file to GEMPAK sounding";
                system "mv $log $log\_failed" if -s $log;

                if (grep /binary|architecture/i,@lines) {
                    my $mesg1 = "Log file information:\n\n$err\n\n";
                    &Utils::modprint(6,14,144,1,1,"$mesg0 - System architecture",$mesg1);
                } elsif ($rc==11 or grep /Segmentation/i,@lines) { #  Segmentation fault
                    my $mesg1 = "Log file information:\n\n$err\n\n";
                    &Utils::modprint(6,14,144,1,1,"$mesg0 - Segmentation fault",$mesg1);
                } elsif ($rc==136 or $rc==9 or grep /Segmentation/i,@lines) { #  Segmentation fault
                    my $mesg1 = $err ? "Log file information:\n\n$err\n\n" : ' ';
                    &Utils::modprint(6,14,144,1,1,"$mesg0 - Possible Floating Point Exception",$mesg1);
                } elsif (@lines and $err) {
                    my $mesg1 = "Log file information:\n\n$err\n\nMaybe you can make some sense of it.";
                    &Utils::modprint(6,14,144,1,2,$mesg0,$mesg1);
                } else {
                    my $mesg1 = "I just don't know what happened";
                    &Utils::modprint(6,14,144,1,2,$mesg0,$mesg1);

                }
                &Utils::modprint(0,9,96,2,2,"Leaving bufr2gem with nothing to show for my efforts - Bummer");
                &Utils::rm($_) foreach ($gemsfc, $gemsnd, "$gemaux", "${mod}_namsnd.in", "gemglb.nts", "last.nts");
                return (\@gemfls, \@ascfls);
            }

            #  Move the ascii profiles is needed
            #
            system "mv prof.$stid $Bgruven{GRUVEN}->{DIRS}{ascdir}/${ymd}${cc}_${mod}.prof.$stid" if $ascii;
            push @ascfls => "$Bgruven{GRUVEN}->{DIRS}{ascdir}/${ymd}${cc}_${mod}.prof.$stid" if -s "$Bgruven{GRUVEN}->{DIRS}{ascdir}/${ymd}${cc}_${mod}.prof.$stid";
            &Utils::rm($_) for ("prof.$stid", "${mod}_namsnd.in", 'gemglb.nts', 'last.nts', $log);
        }

        foreach ($gemsfc, $gemaux, $gemsnd) {next unless -s $_; push @gemfls => $_;}

        push @mbrs => $me if $ens;
    
    }  #  Foreach model loop

    my $str = join ' ' => @mbrs;
    &Utils::modprint(0,1,144,0,0,sprintf("%s", $ens ? "Completed ($str)" : "Completed"));
    &Utils::modprint(0,9,96,2,2,"Processing of BUFR files to GEMPAK completed");

return (\@gemfls, \@ascfls);
}


sub gem2bfkt {
#----------------------------------------------------------------------------------
#  This routine converts GEMPAK sounding files to BUFKIT using a very messy
#  algorithm that needs to be clean up by somebody with time. It returns a list 
#  of bufkit files.
#----------------------------------------------------------------------------------
#
    my @bufkits=();  #  Define the files to be passed out


    #  Define the BUFKIT file naming conventions
    #
    my $bufkit  = 'MOD_STID.buf';
    my $bufkitp = 'YYYYMMDDCC.MOD_STID.buf';
#   my $bufkit  = 'MOD_STNM.buf';
#   my $bufkitp = 'YYYYMMDDCC.MOD_STNM.buf';

    my %wkbfkts=();

    my @gemsnds = @{$Bgruven{DATA}->{GEMPAK}}; return unless @gemsnds;
    my ($ntimes, $nstns) = split /\//, $Bgruven{BINFO}->{GEMPAK}{timstn};

    my $bfkdir    = $Bgruven{GRUVEN}->{DIRS}{bfkdir};
    my $ymd       = $Bgruven{PROCESS}->{DATE}{yyyymmdd};
    my $cc        = $Bgruven{PROCESS}->{DATE}{acycle};

    #  Open the debug file if necessary
    #
    open DEBUGFL => ">>${Bgruven{GRUVEN}->{DIRS}{debug}}/gem2bfkt.debug.$$" if $Bgruven{GRUVEN}->{OPTS}{debug};


    #  Provide some information to the user as to what is going on
    #
    &Utils::modprint(0,2,96,1,1,sprintf("%5s  Cook'n up some BUFKIT files - Just the way you like them",shift @{$Bgruven{GRUVEN}->{INFO}{rn}}));


    #  Get the list of placeholders for the filenames
    #
    my @phs = ($ymd, $cc, "$Bgruven{BINFO}->{DSET}{dset}", 'MOD');
    for ($bfkdir, $bufkit, $bufkitp) {$_ = &Utils::fillit($_,@phs);}


    #  Create the bufkit if necessary and delete any files in the local working
    #  directory that are greater than 2 days old.
    #
    &Utils::mkdir($bfkdir);
    opendir DIR => $bfkdir;
    foreach (readdir(DIR)) {next if /^\./; &Utils::rm("$bfkdir/$_") if -M "$bfkdir/$_" > 2;}
    closedir DIR;


    #  GEMPAK needs to have environment variables set
    #
    $ENV{NAWIPS} = "$Bgruven{HOME}/gempak";
    $ENV{GEMPDF} = "$ENV{NAWIPS}/pdf";
    $ENV{GEMNTS} = "$ENV{NAWIPS}/nts";
    $ENV{GEMEXE} = "$ENV{NAWIPS}/bin";
    $ENV{GEMPARM}= "$ENV{NAWIPS}/parm";
    $ENV{GEMTBL} = "$ENV{NAWIPS}/tables";


    #  Set the GEMPAK binary directory
    #
    my $gembin = $ENV{GEMEXE};

    #  Go through the GEMPAK routines used during this process and make sure the
    #  necessary libraries are on the system.
    #
    my @libs=();
    foreach my $bin ('snlist','sfcfil','sfedit','sflist') {@libs = (@libs, &Utils::cklib("$gembin/$bin"));}
    if (@libs) {
        &Utils::modprint(6,9,144,1,1,"Missing System Libraries","You are missing necessary system libraries required for bufkit file processing:");
        &Utils::modprint(1,26,144,1,0,$_) foreach @libs;
        return \@bufkits;
    }


    #  Create the working directory
    #
    my $work = "$bfkdir/work"; 
    &Utils::mkdir($work); chdir $work;


    #  ---------------------------------------------------------------------------
    #
    #  STEP I. - Formulate arguments to snlist and write them to snlist.$$
    #

    #-----------------------------------------------------------------------------------
    #  Begin primary loop over each of the models, which there should be only 
    #  one unless a ensemble data set was requested.
    #
    foreach my $mod (keys %{$Bgruven{PROCESS}->{STATIONS}{process}}) {


        #  Again, make sure $mods is not an empty string
        #
        $mod =~ s/ //g;
        next unless $mod;

        #  Create a unique work directory for each model. Needed for ensembles
        #
        my $mwork = "$work/$mod"; &Utils::rm($mwork);
        &Utils::mkdir($mwork); chdir $mwork;

        
        my @stnms   = keys %{$Bgruven{PROCESS}->{STATIONS}{process}{$mod}};

        $_ =~ s/ //g foreach @stnms;
        @stnms = &Utils::rmdups(@stnms);
        next unless @stnms;
        
        $nstns   = @stnms;  #  Override configuration file value

        my $bfkf  = $bufkit;  
        my $bfkfp = $bufkitp;

        #  Populate the date, time, and model placeholders in LOCFIL
        #
        for ($bfkf, $bfkfp) {$_ = &Utils::fillit($_,@phs);}


        #  The three necessary gempak files are in the @gemsnds list; however,
        #  we don't know the location of the surface and sounding files within
        #  the array. We'll figure it out here.
        #
        my ($gemaux,$gemsfc,$gemsnd);
        foreach (@gemsnds) {
            $gemaux = $_ if /${mod}/ and /sfc_aux/;
            $gemsfc = $_ if /${mod}/ and /sfc$/;
            $gemsnd = $_ if /${mod}/ and /snd/;
        }


        my $snlist = 'snlist.st1';
        open GEMFILE => ">>$snlist";
        my $file = &Utils::popit($gemsnd); symlink $gemsnd => $file;
        print GEMFILE "SNFILE = $file\n",
                      "LEVELS = ALL\n",
                      "STNDEX = show;lift;swet;kinx;lclp;pwat;totl;cape;lclt;cins;eqlv;lfct;brch\n",
                      "SNPARM = pres;tmpc;tmwc;dwpc;thte;drct;sknt;omeg;cfrl;hght\n",
                      "DATTIM = ALL\n",
                      "VCOORD = PRES\n",
                      "MRGDAT = YES\n" ;

        foreach my $stnm (@stnms) {
           print GEMFILE "AREA     =\@$stnm\n",
                         "OUTPUT   = f/ascii_${stnm}_snd.txt\n",
           "list\n"  ,
           "run \n"  ,
           "    \n"  ;
        }
        print GEMFILE "exit\n";
        close GEMFILE;

   
        #  Run SNLIST to generate ascii text file containing the sounding information.
        #
        my $output = `$gembin/snlist  < $snlist`;
         
        if ($Bgruven{GRUVEN}->{OPTS}{debug}) {
            print DEBUGFL "\n\n  STEP I",
                          "\n\n  Input to SNLIST - $snlist:\n\n",`cat $snlist`,
                          "\n\n  Output from SNLIST:\n\n",$output," \n\n\n";
        }
        &Utils::rm($_) foreach ($file, "gemglb.nts", "last.nts");


        #  -------------------------------------------------------------------------------
        #
        #  STEP II
        #
        my $sfcout = 'sfcout.st2';

        if ($gemaux) {

            #  Proceed to dumping out the surface information. This becomes messy
            #  as it requires the dumping out of surface data and writing it back
            #  to a gempak data. This step could be rewritten to use sndiag but
            #  time is not available.
            #
            my $sfprmf = $Bgruven{BINFO}->{GEMPAK}{packaux};
            my $sfcfil = 'sfcfil.st2';

            unless (-s "$ENV{GEMTBL}/pack/$sfprmf") {
               $mesg = "You are missing the necessary GEMPAK packing file:\n\n".
                        "  $ENV{GEMTBL}/pack/$sfprmf\n\n".
                        "to process BUFR files to gempak format.";
                &Utils::modprint(6,11,144,1,2,$mesg);
                return \@bufkits;
            }
            system "cp $ENV{GEMTBL}/pack/$sfprmf .";
 
            open GEMFILE => ">>$sfcfil";
            print GEMFILE "SFOUTF = ",$sfcout,"\n",
                          "SFPRMF = ./$sfprmf\n",
                          "STNFIL = \n",
                          "SHIPFL = NO\n",
                          "TIMSTN = $ntimes\/$nstns\n",
                          "SFFSRC = \n",
                          "list\n",
                          "run \n",
                          "    \n",
                          "exit\n";
            close GEMFILE;

            #  Run SNCFIL to create an empty surface file. Will populate later.
            #  Run SNLIST to generate ascii text file containing the sounding information.
            #
            $output = `$gembin/sfcfil < $sfcfil`;

            if ($Bgruven{GRUVEN}->{OPTS}{debug}) {
                print DEBUGFL "\n\n  STEP II",
                              "\n\n  Input to SFCFIL - $sfcfil:\n\n",`cat $sfcfil`,
                              "\n\n  Output from SFCFIL:\n\n",$output," \n\n\n";
                return \@bufkits unless -s $sfcout;
            }

            &Utils::rm($sfprmf); # don't need it anymore
        }

        #  -------------------------------------------------------------------------------
        #
        #  STEP III
        #
        #  Now run sflist multiple times for each station to extract the necessary data
        #  from the file and write it to temporary ascii files. These data will be placed
        #  into the empty surface file created above in STEP II.
        #
        my ($gemsfcal, $gemsfcl);  #  Links to gempak aux and regular surface files

        $gemsfcl  = &Utils::popit($gemsfc); symlink $gemsfc => $gemsfcl;
        if ($gemaux) {$gemsfcal  = &Utils::popit($gemaux); symlink $gemaux => $gemsfcal;}

        my $sflist = 'sflist.st3';

        STEPIII: foreach my $stnm (@stnms) {

            my $stid = $Bgruven{PROCESS}->{STATIONS}{table}{numtoid}{$stnm};

            if ($gemaux) {

                my $sfparm = "pmsl;pres;sktc;stc1;snfl;wtns;p01m;c01m;stc2";
                open GEMFILE => ">$sflist";
                print GEMFILE "SFFILE = $gemsfcl\n",
                              "AREA   = @",$stnm,"\n",
                              "DATTIM = ALL\n",
                              "IDNTYP = STNM \n",
                              "SFPARM = $sfparm\n",
                              "OUTPUT = f/list01\.out\n",
                              "list\n"  ,
                              "run \n"  ,
                              "    \n"  ,
        
                              "SFPARM = uwnd;vwnd;r01m;bfgr;t2ms;q2ms\n",
                              "OUTPUT = f/list02\.out\n",
                              "list\n"  ,
                              "run \n"  ,
                              "    \n"  ,
        
                              "SFFILE = $gemsfcal\n",
                              "SFPARM = lcld;mcld;hcld;snra;wxts;wxtp;wxtz;wxtr\n",
                              "OUTPUT = f/list03\.out\n",
                              "list\n"  ,
                              "run \n"  ,
                              "    \n"  ,
        
                              "SFPARM = ustm;vstm;hlcy;sllh;wsym;cdbp;vsbk;td2m\n",
                              "OUTPUT = f/list04\.out\n",
                              "list\n"  ,
                              "run \n"  ,
                              "    \n"  ,
                              "exit\n"  ;
    
                close GEMFILE;
    
                my $output = `$gembin/sflist < $sflist`;

                if ($Bgruven{GRUVEN}->{OPTS}{debug}) {
                    print DEBUGFL "\n\n  STEP III",
                                  "\n\n  Input to SFLIST - $sflist:\n\n",`cat $sflist`,
                                  "\n\n  Output from SFLIST:\n\n",$output," \n\n\n";
                }

                #  -------------------------------------------------------------------------------
                #
                #  STEP IV
                #
                #  Now (finally), write all the data from these 4 $$.list files into
                #  the empty gempak surface file. We are getting close to the end.
                #
                my $sfedit = 'sfedit.st4';
                open  GEMFILE => ">$sfedit";
                print GEMFILE "SFFILE =",$sfcout,"\n",
                              "SFEFIL = list01\.out\n",
                              "list\n"  ,
                              "run \n"  ,
                              "    \n"  ,
                              "SFEFIL = list02\.out\n",
                              "run \n"  ,
                              "    \n"  ,
                              "SFEFIL = list03\.out\n",
                              "run \n"  ,
                              "    \n"  ,
                              "SFEFIL = list04\.out\n",
                              "run \n"  ,
                              "    \n"  ,
                              "exit\n"  ;
                close GEMFILE;
    
                $output = `$gembin/sfedit < $sfedit`;

                if ($Bgruven{GRUVEN}->{OPTS}{debug}) {
                    print DEBUGFL "\n\n  STEP IV",
                                  "\n\n  Input to SFEDIT - $sfedit:\n\n",`cat $sfedit`,
                                  "\n\n  Output from SFEDIT:\n\n",$output," \n\n\n";
                }
            } else {
                $sfcout = $gemsfcl;
            }



            #  -------------------------------------------------------------------------------
            #
            #  STEP V
            #
            #  Write out the final ascii text file containing the data for the station.
            #  This file is essentially the same as the final BUFKIT file except for
            #  some minor massaging that takes place at the end.
            #
            my $sffout = "acsii_$stnm\_sfc.txt";
            my $sflist = 'sflist.st5';
            open  GEMFILE => ">$sflist";
            print GEMFILE "SFFILE =",$sfcout,"\n",
                           "AREA   = @",$stnm,"\n",
                           "DATTIM = ALL\n",
                           "IDNTYP = STNM \n",
                           "SFPARM = dset\n",
                           "OUTPUT = f/$sffout\n",
                           "list\n"  ,
                           "run \n"  ,
                           "    \n"  ,
                           "exit\n"  ;
            close GEMFILE;

            $output = `$gembin/sflist < $sflist`;

            if ($Bgruven{GRUVEN}->{OPTS}{debug}) {
                print DEBUGFL "\n\n  STEP V",
                              "\n\n  Input to SFLIST - $sflist:\n\n",`cat $sflist`,
                              "\n\n  Output from SFLIST:\n\n",$output," \n\n\n";
            }

            #  -------------------------------------------------------------------------------
            #
            #  STEP V.a
            #
            #  Massage the raw ascii files to get rid of unwanted white spaces and other
            #  undesirable characters :) .
            #

            #  Create BUFKIT file name and write data to the file. This step gets messy.
            #
            my $sndout  = "ascii_${stnm}_snd.txt";
               $stid    = lc $stid;

            # Take the ascii surface and sounding data files and merge them
            #
            my $PRINTF = "";
            my $tmpfile = 'tmpfile';
            open TMPFIL => ">$tmpfile";

            #  If the necessary surface ascii surface and sounding files do not exist chances are that there was
            #  a problem with the raw BUFR file. Better to move on to next BUFR file than die.
            #
            unless (open SFCOUT => "<$sffout") {
                $mesg = "Likely problem (1) with BUFR file for $stid ($stnm) - Continue to next file";
                &Utils::modprint(6,9,144,0,1,$mesg);
                next STEPIII;
            }

            unless (open SNDOUT => "<$sndout") {
                $mesg = "Likely problem (2) with BUFR file for $stid ($stnm) - Continue to next file";
                &Utils::modprint(6,9,144,0,1,$mesg);
                next STEPIII;
            }

            while (<SNDOUT>) { print TMPFIL "$_"; }
            while (<SFCOUT>) {
                if ( /STN/i ) { $PRINTF = 1; }
                if ( $PRINTF ) { print TMPFIL "$_"; }
            }
            close TMPFIL;
            close SFCOUT;
            close SNDOUT;

            #  Now process the almost complete bufkit files by removing white spaces and adding a
            #  ^M to the end of each line for windows.
            #
            unless (open TMPFIL => "<$tmpfile") {
                &Utils::modprint(6,9,144,0,1,"Likely problem with $mod BUFR file for $stid ($stnm) - Continue to next file");
                next STEPIII;
            }

            my $bfkt  = $bfkf;
            for ($bfkt) {
                s/MOD/$mod/g;
                s/STNM/$stnm/g;
                s/STID/$stid/g;
            }


            open OUTFILE => ">$bfkt";
            while (<TMPFIL>) {
                tr/ / /s;
                s/^ //g;
                s/\n/\15\n/g;
                print OUTFILE "$_";
            }
            close OUTFILE;
            close TMPFIL;

            my $file = &Utils::popit($bfkt);
            unless (-s $bfkt) {&Utils::modprint(6,9,144,1,1,"Problem creating BUFKIT file - $file");next;}
            
            $wkbfkts{$stnm}{$mod} = "$mwork/$bfkt";
        }

 
    }  #  Foreach Model

    chdir $work;

    #   Make sure the information is written to the file in the order that the user requested
    #
    my @order = @{$Bgruven{BINFO}->{DSET}{members}{order}} ? @{$Bgruven{BINFO}->{DSET}{members}{order}} : @{$Bgruven{BINFO}->{DSET}{model}};
       @order = &Utils::rmdups(@order);

    foreach my $stnm (sort { $a <=> $b } keys %wkbfkts) {

        my $stid = lc $Bgruven{PROCESS}->{STATIONS}{table}{numtoid}{$stnm};

        #  Assign the final BUFKIT filenames
        #
        my $bfkt  = "$bfkdir/$bufkit";
        my $bfktp = "$bfkdir/$bufkitp";

        for ($bfkt, $bfktp) {
            s/STNM/$stnm/g;
            s/STID/$stid/g;
            s/MOD/$Bgruven{BINFO}->{DSET}{model}[0]/g;
        }

        open OBFKT => ">$bfkt"; 
        foreach my $mod (@order) {

            next unless $wkbfkts{$stnm}{$mod};

            unless (-s $wkbfkts{$stnm}{$mod}) {
                my $file = &Utils::popit($wkbfkts{$stnm}{$mod});
                &Utils::modprint(6,11,144,1,1,"Problem creating member BUFKIT file - $file") if @{$Bgruven{BINFO}->{DSET}{members}{order}};
                &Utils::rm($wkbfkts{$stnm}{$mod});
                next;
            }

            open INBFKT => $wkbfkts{$stnm}{$mod}; my @lines = <INBFKT>;close INBFKT;
            print OBFKT "$Bgruven{BINFO}->{DSET}{members}{$mod}" if @{$Bgruven{BINFO}->{DSET}{members}{order}};
            foreach (@lines) {print OBFKT "$_";}
#           foreach (@lines) {tr/ / /s;s/^ //g;s/\n/\15\n/g;print OBFKT "$_";}
        } close OBFKT;


        #  Gzip the file if requested. Now it will be a ".buz" file.
        #
        if ($Bgruven{GRUVEN}->{OPTS}{zipit}) {
            #  Locate the curl and wget commands
            #
            my %comp = ();
            my @zips = qw(zip gzip);
            foreach my $meth (@zips) {$comp{$meth} = &Utils::findcmd($meth);}

            if ($comp{zip} or $comp{gzip}) {
                my $zpfl  = $bfkt;
                my $zpflp = $bfktp;
                for ($zpfl, $zpflp) {s/\.buf$/\.buz/g;&Utils::rm($_);}
               
                if ($comp{zip} ? system "$comp{zip} -q -j $zpfl $bfkt" : system "$comp{gzip} -q -c $bfkt > $zpfl") {
                   &Utils::modprint(6,11,144,1,1,sprintf("Oops - Gzip'n %s -> %s failed",&Utils::popit($bfkt),&Utils::popit($zpfl)));
                   &Utils::rm($zpfl);
                } else {
                   &Utils::rm($bfkt);
                   $bfkt  = $zpfl;
                   $bfktp = $zpflp;
                }
            } else {
                my $ver = $ENV{VERBOSE}; $ENV{VERBOSE} = 1;
                $mesg = "Could not find either \"zip\" or \"gzip\" routines on your system, which are to compress ".
                    "your BUFKIT files.  Since these routines are available with most Linux distributions ".
                    "it is likely that were left out during the OS install."; 
                &Utils::modprint(3,11,96,2,1,$mesg);
                $ENV{VERBOSE} = $ver;
                return;
            }
        }

        my $file = &Utils::popit($Bgruven{GRUVEN}->{OPTS}{prepend} ? $bfktp : $bfkt);

        unless (-s $bfkt) {&Utils::modprint(6,11,144,1,1,"Problem creating BUFKIT file - $file"); &Utils::rm($bfkt); next;}

        system "cp $bfkt $bfktp" if $Bgruven{GRUVEN}->{OPTS}{prepend};

        &Utils::modprint(1,11,144,1,0,"BUFKIT file created - $file");

        push @bufkits => $bfkt;
        push @bufkits => $bfktp if $Bgruven{GRUVEN}->{OPTS}{prepend};

    }
        
    my $dw = &Utils::popit($work);
    system "mv $work $Bgruven{GRUVEN}->{DIRS}{debug}/$dw.debug.$$" if $Bgruven{GRUVEN}->{OPTS}{debug};


    #  Clean up the working directory but be carefull not to step on any other
    #  Bgruven processes.
    #
    foreach (keys %{$Bgruven{PROCESS}->{STATIONS}{process}}) {&Utils::rm("$work/$_") if $_;}
    &Utils::rm($work) unless &Utils::emptydir($work);

    my $ct = gmtime();
    &Utils::modprint(0,9,144,2,2,"BUFKIT file processing completed");

    @bufkits = sort @bufkits;

#  Return array reference and not arrays
#
return \@bufkits;
}
                                                                              
