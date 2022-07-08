#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Start.pm
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
package Start;
require 5.8.0;
use strict;
use warnings;
use English;


use vars qw (%Bgruven $mesg);
use Love;

sub gruven {
#----------------------------------------------------------------------------------
#   This routine makes the calls to the various initialization and configuration
#   routines.  Hopefully it will have all the information it needs before returning
#   to the main program for data acquisition and processing.
#----------------------------------------------------------------------------------
#
#  Bring in the Bgruven hash from main
#
%Bgruven = %main::Bgruven;


    #  Complete the preliminary initialization
    #
    &initialize or &Love::died($mesg); 


    #  Process the command-line options
    #
    &options    or &Love::died($mesg);


    #  Assimilate the options and default configuration into the 
    #  the primary Bgruven hash.
    #
    &configure  or &Love::died($mesg);


return %Bgruven;
}


sub initialize {
#----------------------------------------------------------------------------------
#   This routine reads the bufrgruven.conf file and completes the preliminary 
#   initialization of the primary hash.
#----------------------------------------------------------------------------------
#
#  Bring in the Bgruven hash from main
#
    my %bgruven=();

    # Set date to current by default. Will override if --date option is passed.
    #
    $bgruven{INFO}{yyyymmdd}   = `date -u +%Y%m%d`  ; chomp $bgruven{INFO}{yyyymmdd};     # Current system date in UTC
    $bgruven{INFO}{yyyymmddhh} = `date -u +%Y%m%d%H`; chomp $bgruven{INFO}{yyyymmddhh};   # Current system date/time in UTC


    # Have a little fun. Additional entries may be included in the lists below.
    #
    @{$bgruven{INFO}{rn}} = qw ( I. II. III. IV. V. VI. VII. VIII. IX. X. XI. XII. XIII. XIV. XV. XVI. );
    @{$bgruven{INFO}{fm}} = ("Arrrg", "Good Grief", "Ugh", "Bummer", "C'est la vie", "Shoot", "Oh Well", "Darn it", "Drats", "#%&@",
                             "#@)*^", "\$%(^*@", "I'll be back", "Que Sera Sera", "Ay Carumba", "D\'oh", "No BUFR for you",
                             "Missed it by THAT much", "Fuh-get about it!", "We blew it!" );

    @{$bgruven{INFO}{sm}} = ("Yatzee!", "Bingo!", "Hello, BUFR!", "Dyn-o-mite!", "Hasta la vista, BUFR!", "TaDa!", "Excellent!", "You Bgruven!",
                             "Please Bgruven again!", "As you wish!", "Holy BUFR Batman!", "Schwing!", "That's hot!", "Oh Yeah!",
                             "Who's your daddy!", "It's Bgruv'n time!", "Heeeeeeeere's BUFR!", "Live Long and BUFR!", 
                             'Who loves ya, baby!', "Da BUFR! Da BUFR!", "Cinderella story!", "Nailed it!", "These go to 11!",
                             'Show me the BUFR!', "It\'s a BUFR!", "Victory is ours!");


    #  Check to make sure there are no uppercase letters in the path as that will cause GEMPAK
    #  to fail unexpectedly.
    #
    if ($Bgruven{HOME} =~ /[A-Z]/) {
        $mesg = "Unfortunately, you are not allowed to use uppercase characters in the BUFRgruven ".
                "directory path.  GEMPAK may fail unexpectedly and give both of us fits in attempting ".
                "to diagnose the problem. Trust me, your \"Uncle B Gruven\" knows failure."; return;
    }


    #  Define some of the primary directories that Bufrgruven needs
    #
    $bgruven{DIRS}{conf} = "$Bgruven{HOME}/conf";
    unless (-e $bgruven{DIRS}{conf}) {
        $mesg = "It appears there is a problem with your BUFRgruven as there is no \"conf\" ".
                "directory at the under $Bgruven{HOME}."; return; 
    }


    $bgruven{DIRS}{stns} = "$Bgruven{HOME}/stations";
    unless (-e $bgruven{DIRS}{stns}) {
        $mesg = "It appears there is a problem with your BUFRgruven as there is no \"stations\" ".
                "directory at the under $Bgruven{HOME}."; return;
    }


    #  Read the user configuration from the bufrgruven.conf file
    #
    my $cfile = "$bgruven{DIRS}{conf}/bufrgruven.conf";
    unless (open (INFILE,$cfile)) {$mesg = "You're not BUFRgruven without the master configuration file: $cfile"; return;}

    while (<INFILE>) {
        next if /^#|^$|^\s+/;
        s/ //g;s/\t//g;s/\n//g;
        my @list = split(/=/,$_);
        if (/ZIPIT|VERBOSE|PASVFTP/i) {
            $list[1] = 1 unless defined $list[1];
            $list[1] = ($list[1] =~ /^N/i or $list[1] =~ /0/i) ? 0 : 1;
            $bgruven{INFO}{lc $list[0]} = $list[1];
            next;
        }
        $bgruven{HKEYS}{uc $list[0]} = $list[1];
    } close INFILE;


    #  Determine what model bufr data sets are supported by extracting the names
    #  names from the _bufrinfo.conf files in the conf directory.
    #
    @{$bgruven{DSETS}} = ();

    opendir(DIR,$bgruven{DIRS}{conf});
    my $key = "_bufrinfo.conf";
    foreach (readdir(DIR)) {next unless s/$key$//g;push @{$bgruven{DSETS}} => $_;} close DIR;

    unless (@{$bgruven{DSETS}}) {$mesg = "Unable to locate any BUFR configuration files under conf/"; return;}


    #  Define the directory where all the data processing will initially take place. Note
    #  that this location is relative to the Bgruven home directory.  If you wish to change 
    #  this location from the default "metdat" then this is the spot.
    #
    $bgruven{DIRS}{debug}  = "$Bgruven{HOME}/debug";
    $bgruven{DIRS}{logs}   = "$Bgruven{HOME}/logs";   &Utils::mkdir($bgruven{DIRS}{logs});
    $bgruven{DIRS}{metdat} = "$Bgruven{HOME}/metdat"; &Utils::mkdir($bgruven{DIRS}{metdat});


    # Define and create the directories needed for bufr data processing
    #
    $bgruven{DIRS}{bufdir} = "$bgruven{DIRS}{metdat}/bufr";
    $bgruven{DIRS}{gemdir} = "$bgruven{DIRS}{metdat}/gempak";
    $bgruven{DIRS}{ascdir} = "$bgruven{DIRS}{metdat}/ascii";
    $bgruven{DIRS}{bfkdir} = "$bgruven{DIRS}{metdat}/bufkit";


    # Set the passive FTP flag
    #
    $ENV{FTP_PASSIVE} = $bgruven{INFO}{pasvftp} ? 1 : 0;


    #  Initialze the data record
    #
    my %data=(); @{$data{$_}}=() for ('bufr', 'gempak', 'ascii', 'bufkit');

    $Bgruven{GRUVEN} = &init_recs('gruven',%bgruven);
    $Bgruven{DATA}   = &init_recs('data'  ,%data);



    #  Finally, do a test for the existence of the Perl Time::HiRes module
    #
    $Bgruven{'Time::HiRes'} = &Utils::envEvalHires;


return 1;
}


sub options {
#----------------------------------------------------------------------------------
#  The options routine parses the options passed to bufr_gruven.pl
#  from the command line. Simple enough.
#----------------------------------------------------------------------------------
#
use Getopt::Long qw(:config pass_through);

    my (%option, %gopts)=();
    my $tidy=0;

    #  Do an initial check of the options and flags to look for obvious problems
    #
    &chk_args(@ARGV) or return;

    #  Need to keep track of the requested methods of file acquisition
    #
    my @methods = qw(https http ftp nfs);
    foreach my $m (@methods) {push @{$gopts{methods}} => $m if grep /$m/i, @ARGV;}
    @{$gopts{methods}} = &Utils::rmdups(@{$gopts{methods}});
    @{$gopts{methods}} = qw(https http ftp) unless @{$gopts{methods}};


    #  Address the options passed
    #
    GetOptions ( "help"           => sub {&Love::help($Bgruven{EXE})},
                 "guide"          => sub {&Love::guide($Bgruven{EXE})},
                 "stnlist|slist"  => sub {&Love::stnlist(@ARGV)},
                 "dslist|list"    => sub {&Love::dslist},

                 "dset=s"         => \$option{DSET},

                 "date=s"         => \$option{RDATE},
                 "cycle=s"        => \$option{CYCLE},
                 "previous"       => \$option{PREV},
                 "nodelay"        => \$option{NODELAY},
                 "stations|station=s"=> \$option{STATIONS},

                 "metdat=s"       => \$option{METDAT},

                 "ftp:s"          => \$option{FTP},
                 "nfs:s"          => \$option{NFS},
                 "http:s"         => \$option{HTTP},
                 "https:s"        => \$option{HTTPS},

                 "noexport"       => \$option{NOEXPORT},
                 "noprocess"      => \$option{NOPROCESS},
                 "nobufkit"       => \$option{NOBUFKIT},
                 "noascii"        => \$option{NOASCII},

                 "monolithic"     => \$option{MONO},
                 "prepend"        => \$option{PREPEND},
                 "zipit|pack!"    => \$option{ZIPIT},

                 "forced"         => \$option{FORCED},
                 "forcep"         => \$option{FORCEP},

                 "clean"          => \$option{CLEAN},
                 "tidy"           => \$tidy,
                 "debug+"         => \$option{DEBUG},
                 "verbose!"       => \$option{VERBOSE} ) or &Love::died("Problems? Sure, we all do!  Pass \"--help\" for guidance.");


    if ($tidy) {
        &Utils::modprint(0,5,114,1,1,"Don't mind me - I'm just cleaning up after you again.");
        for my $dir ('metdat', 'logs') {my $cd = $Bgruven{GRUVEN}->{DIRS}{$dir}; &Utils::rm($cd); &Utils::mkdir($cd);}
        &Utils::rm($Bgruven{GRUVEN}->{DIRS}{debug});
        &Love::exit(-1);
    }


    # Check whether --dset was passed, which is mandatory
    #
    unless (defined $option{DSET}) {$mesg = "Missing mandatory \"--dset\" option (--dset <data set> )"; return;}


    # Check whether --stations was passed, which is mandatory
    #
    unless (defined $option{STATIONS}) {$mesg = "Missing mandatory \"--stations\" option (--stations stn0,stn1,stn2,...,stnN)"; return;}


    #  Update information in %gruven hash
    #
    for my $opt (keys %option) {$gopts{lc $opt} = $option{$opt} if defined $option{$opt};}


    #  Make sure the requested BUFR data set is supported by comparing the name to those
    #  extracted from the conf directory.
    #
    unless (grep /^$gopts{dset}$/, @{$Bgruven{GRUVEN}->{DSETS}}) {
        my $sd = join(' ',@{$Bgruven{GRUVEN}->{DSETS}});
        $mesg = "Requested BUFR data set (--dset $gopts{dset}) is not supported.\n\nSupported data sets include: $sd"; return;
    }


    #  If the user requests an alternate location for the metdat directory then 
    #  override the default location.
    #
    if ($gopts{metdat}) {
        #  Check whether the requested directory exists and is writable 
        #
        unless (-d $gopts{metdat}) {$mesg = "The requested metdat directory (--metdat $gopts{metdat}) does not exist.\n\n  Go find it and don't return to me until you do!"; return;}
        unless (-w $gopts{metdat}) {$mesg = "The requested metdat directory (--metdat $gopts{metdat}) is not writable.\n\n  Fix the problem and then return to me with open arms!"; return;}
    
        $Bgruven{GRUVEN}->{DIRS}{metdat} = $gopts{metdat}; &Utils::mkdir($gopts{metdat});
    
        # Define and create the directories needed for bufr data processing
        #
        $Bgruven{GRUVEN}->{DIRS}{bufdir} = "$gopts{metdat}/bufr";
        $Bgruven{GRUVEN}->{DIRS}{gemdir} = "$gopts{metdat}/gempak";
        $Bgruven{GRUVEN}->{DIRS}{ascdir} = "$gopts{metdat}/ascii";
        $Bgruven{GRUVEN}->{DIRS}{bfkdir} = "$gopts{metdat}/bufkit";
    }


    #  Override the date/time and cycle information if the option was passed.  Note that if
    #  the user passes the --date or --cycle flag the --prepend option is automatically
    #  turned ON.
    #
        
    if ($gopts{rdate}) {
        if (length $gopts{rdate} == 6) {
            $gopts{rdate} = substr($gopts{rdate},0,2) < 50 ? "20$gopts{rdate}" : "19$gopts{rdate}"; chomp $gopts{rdate};
        } elsif (length $gopts{rdate} != 8) {
            $mesg = "Invalid date of data set ($gopts{rdate}) < --date [YY]YYMMDD >"; return;
        }
        chomp $gopts{rdate};
        $gopts{prepend}=1;
    }


    #  Check the cycle option if passed
    #
    if ($gopts{cycle}) {
        $gopts{cycle}+=0;  # eliminate leading "0" for now
        unless ($gopts{cycle} =~ /^\d+$/) {$mesg = "The argument to --cycle must be an integer hour ($gopts{cycle})"; return;}
        $gopts{cycle} = "0$gopts{cycle}" if length $gopts{cycle} == 1; #  Put it back
        $gopts{prepend}=1;
    }


    #  Will the final BUFKIT files be zipped?
    #
    $gopts{zipit} = defined $gopts{zipit} ? $gopts{zipit} :  $Bgruven{GRUVEN}->{INFO}{zipit};


    if ($gopts{clean}) { for my $dir ('metdat', 'logs') {my $cd = $Bgruven{GRUVEN}->{DIRS}{$dir}; &Utils::rm($cd); &Utils::mkdir($cd);}}
    &Utils::rm($Bgruven{GRUVEN}->{DIRS}{debug});
    if ($gopts{debug}) {
        &Utils::mkdir($Bgruven{GRUVEN}->{DIRS}{debug});
        &Utils::modprint(6,5,114,1,1,"Debugging turned ON - Information can be found in $Bgruven{GRUVEN}->{DIRS}{debug}");
    }


    #  Set the OPTS section of the GRUVEN record
    #
    %{$Bgruven{GRUVEN}->{OPTS}} = %gopts;


return 1;
} # End options routine


sub chk_args {
#-------------------------------------------------------------------------------------
#  This routine does a basic check of the options and flags passed to the program.
#  There will be additional checks to follow in other routines but this will catch
#  the most egregious of errors.
#-------------------------------------------------------------------------------------
#
    my $fail = 0;              #  Predefine arg list as OK
    my %opts = &Love::defopts; #  Get options list

    #  Do an initial run through of the list to make sure each --[option] is valid .
    #
    foreach (@_) {
        next unless /^\-/;
        s/\-//g; $_ = "--$_";
        $_ = lc $_;

        #  Don't worry about --help or --guide
        #
        $_ = '--help'  if /-h$/  or  /-he$/  or  /-hel$/  or  /-help$/;
        $_ = '--guide' if /-gu$/ or  /-gui$/ or  /-guid$/ or  /-guide$/;
        $_ = '--stations' if /stat/;
        next if $_ eq '--help' ;
        next if $_ eq '--guide';
        next if /ver|zip|tidy|stnl|pack/;  #  Skip zipit|verbose - The [no] part is problematic


        #  Test if it's a valid option
        #
        if (defined $opts{$_}) {

            #  check if it needs an argument
            #
            if ($opts{$_}{arg} and $opts{$_}{arg} !~ /^\[/) {  #  option requires an argument - check

                my $i = &Utils::aindxe($_,@_); $i++;  #  Get the expected index of the argument to test

                if ( $i > $#_ or $_[$i] =~ /^\-/) {
                    &Utils::modprint(6,4,104,1,0,"Hey, passing \"$_\" without an argument will cause your BUFRgruven to fall off!");
                    $fail = 1;
                }
            }
        } else {
            &Utils::modprint(6,4,104,1,0,"Hey, passing \"$_\" as an option will not get your BUFRgruven on! That's not an option.");
            $fail = 1;
        }
    }

    if ($fail) {
         &Utils::modprint(0,7,114,2,2,"Try passing \"--help\" for a list of valid options and guidance on how to use them with respect");
    }

return $fail ? 0 : 1;
}
    

sub configure {
#----------------------------------------------------------------------------------
#  Complete the configuration of the BUFR structure with the available information.
#  Also check for problems.
#----------------------------------------------------------------------------------
#
use Time;
use Data::Dumper; $Data::Dumper::Sortkeys = 1;


    #  Make sure the hash is initialized
    #
    my %proc=(); %{$proc{$_}}=() for ('DATA', 'DATE', 'SOURCES', 'STATIONS');

    
    #  Read the contents of the bufrinfo.conf file for the requested data set.
    #
    my $dset = $Bgruven{GRUVEN}->{OPTS}{dset};

    $Bgruven{BINFO} = &init_recs('binfo', &read_bconf($dset)) or return;


    #  Make sure LOCFIL was defined
    #
    unless ($Bgruven{BINFO}->{DSET}{locfil}) {my $f = $Bgruven{BINFO}->{DSET}{fname} ; $mesg = "It appears that \"LOCFIL\" is not defined in $f"; return;}

   
    #  Was the --monolithic flag passed?  If so then reset locfil to YYYYMMDDCC.MOD.tCCz.class1.bufr
    #
    $Bgruven{BINFO}->{DSET}{locfil} = $Bgruven{GRUVEN}->{OPTS}{mono} if $Bgruven{GRUVEN}->{OPTS}{mono};


    #  Initialize the station table for the requested data set.
    #
    my %stntbl=();
    my $table = $Bgruven{BINFO}->{DSET}{stntbl}; $table = "$Bgruven{GRUVEN}->{DIRS}{stns}/$table";
    unless (open (INFILE,$table)) {$mesg = "You're not BUFRgruven without the $Bgruven{BINFO}->{DSET}{dset} station table: $table"; return;}

    while (<INFILE>) {
        chomp $_; next unless $_;
        my @vals = split /\s+/ => $_;
        $stntbl{numtoid}{$vals[0]} = lc $vals[3] if $vals[0] and $vals[3];
        $stntbl{idtonum}{lc $vals[3]} = $vals[0] if $vals[0] and $vals[3];
    } close INFILE;
    %{$proc{STATIONS}{table}} = %stntbl;


    #  Processes the list of user requested stations
    #
    my %valid = ();
    my @invld = ();
    $Bgruven{GRUVEN}->{OPTS}{stations} =~ s/,+|;+|:+/,/g;
    my @rstns = sort split /,/ => $Bgruven{GRUVEN}->{OPTS}{stations}; @rstns = &Utils::rmdups(@rstns);


    #  Make sure the user requested stations are valid
    #
    foreach my $req (@rstns) {
        $req = lc $req;
        if (defined $stntbl{numtoid}{$req} or defined $stntbl{idtonum}{$req}) {
            $valid{$req} = $stntbl{numtoid}{$req} if defined $stntbl{numtoid}{$req};
            $valid{$stntbl{idtonum}{$req}} = $req if defined $stntbl{idtonum}{$req};
        } else {
            push @invld => $req;
        }
    }
    %{$proc{STATIONS}{valid}} = %valid;
    @{$proc{STATIONS}{invld}} = @invld;


    #  Set the DELAY value
    #
    $Bgruven{BINFO}->{DSET}{delay} = 0 if $Bgruven{GRUVEN}->{OPTS}{nodelay};

    $Bgruven{BINFO}->{DSET}{prepend} = $Bgruven{GRUVEN}->{OPTS}{prepend} if defined  $Bgruven{GRUVEN}->{OPTS}{prepend};


    #  Check requested cycle time against those available
    #
    if ($Bgruven{GRUVEN}->{OPTS}{cycle}) {
        unless (grep /^$Bgruven{GRUVEN}->{OPTS}{cycle}$/, @{$Bgruven{BINFO}->{DSET}{cycles}}) {
            $mesg = "Your requested cycle (--cycle $Bgruven{GRUVEN}->{OPTS}{cycle}) does not match any of those ".
                    "available (@{$Bgruven{BINFO}->{DSET}{cycles}})"; return;
        }
    }


    if ($Bgruven{GRUVEN}->{OPTS}{rdate} and $Bgruven{GRUVEN}->{OPTS}{rdate} > $Bgruven{GRUVEN}->{INFO}{yyyymmdd}) {
        $mesg = "You must be ahead of your time because the date requested (--date $Bgruven{GRUVEN}->{OPTS}{rdate}) ".
                "is later the current system date ($Bgruven{GRUVEN}->{INFO}{yyyymmdd})"; return;
    }


    #  Make a list of (hourly) date/times from -24hr to the requested date/time.
    #  The actual dates & times in the list are bounded by the most current data
    #  set available for the requested data set unless the used has passed the
    #  --date and/or --cycle flags, in which case those values control the entries
    #  in the list.
    #
    #  The $Bgruven{YYYYMMDDHH} contains the current system date and time
    #
    my @bdates=();  # A list of 24 possible date/times.
    my $shr   =1;


    #  $sdate is the upper bound (most current) date/time to be used for a specified
    #  data set. The actual date/time in the list will be controlled by factors such
    #  as the date or cycle time passed by the user, the available cycle times of a
    #  data set, and the date cycle time of the initialization data set (BC data).
    #
    #  $yyyymmddhh holds the current machine date and time in UTC
    #  $yyyymmddxx holds the current machine date and time in UTC minus the DELAY
    #
    my $delay       = $Bgruven{BINFO}->{DSET}{delay};
    my  $yyyymmddhh = $Bgruven{GRUVEN}->{INFO}{yyyymmddhh};
    my  $yyyymmddxx = substr(&Time::compute_date($yyyymmddhh,$delay*-3600),0,10);

    my $sdate   = ($Bgruven{GRUVEN}->{OPTS}{rdate} and $Bgruven{GRUVEN}->{OPTS}{cycle}) ? "${Bgruven{GRUVEN}->{OPTS}{rdate}}${Bgruven{GRUVEN}->{OPTS}{cycle}}"    :
                   $Bgruven{GRUVEN}->{OPTS}{rdate}                                      ? "${Bgruven{GRUVEN}->{OPTS}{rdate}}23"                 :
                   $Bgruven{GRUVEN}->{OPTS}{cycle}                                      ? "${Bgruven{GRUVEN}->{INFO}{yyyymmdd}}${Bgruven{GRUVEN}->{OPTS}{cycle}}" :
                   $Bgruven{GRUVEN}->{INFO}{yyyymmddhh};

    #  Note that we also take into account the DELAY setting from the gribinfo file for
    #  a data set here.
    #
    #  The final pdate list should contain the available date/times from a 24hr period
    #
    while (scalar @bdates < scalar @{$Bgruven{BINFO}->{DSET}{cycles}}) { # We only want a 24-hour window of times
        $shr--; #  Count down hours
        my $pdate = substr(&Time::compute_date($sdate,$shr*3600),0,10);
        next if $pdate > $yyyymmddxx; #  Data set is not available yet (00Hr after current date/time)
        my $adate = substr(&Time::compute_date($pdate,$Bgruven{BINFO}->{DSET}{delay}*-3600),0,10);
        next if $adate > $yyyymmddxx; #  Data set is not available yet (Delay included)
        my $cc = substr($pdate,8,2);
        next unless grep /^$cc$/, @{$Bgruven{BINFO}->{DSET}{cycles}};
        push @bdates => $pdate;       #  Add it to the list
    }

    unless (@bdates)  {$mesg = "Well this is unusual. I was unable to identify and available bufr data sets."; return;}


    #  Assign the date and cycle time of the data set to be acquired.
    #
    if ($Bgruven{GRUVEN}->{OPTS}{cycle}) {until ($bdates[0]=~/${Bgruven{GRUVEN}->{OPTS}{cycle}}$/) {push @bdates => shift @bdates;}}
    shift @bdates if $Bgruven{GRUVEN}->{OPTS}{prev} and @bdates > 1;
    $proc{DATE}{acycle}   = substr($bdates[0],8,2);
    $proc{DATE}{yyyymmdd} = substr($bdates[0],0,8);


    #  Prepare for the placeholders to be populated with the updated fields. An exception will be
    #  made for ensemble BUFR files (when @{$Bgruven{BINFO}->{DSET}{model}} > 1) in which case the
    #  "MOD" placeholder will be retained.
    #
    #
    my @phs = ("$proc{DATE}{yyyymmdd}", "$proc{DATE}{acycle}", "$Bgruven{BINFO}->{DSET}{dset}", @{$Bgruven{BINFO}->{DSET}{model}} > 1 ? 'MOD' : "$Bgruven{BINFO}->{DSET}{model}[0]");

    #  This is a hack, and I don't like hacks!  Unfortunately, there is no easy alternative to account for 
    #  the GFS (V14) -> FV3GFS change on 12 June 2019. This is necessary due to the use of VVEL rather than
    #  OMEG in the BUFR files, which requires different gempak packing tables.
    #
    if ($Bgruven{BINFO}->{DSET}{dset} eq 'gfs' and $sdate < 2019061212) {
        $Bgruven{BINFO}->{GEMPAK}{sfpack} = 'sf_gfs1.prm';
        $Bgruven{BINFO}->{GEMPAK}{snpack} = 'sn_gfs1.prm';
    }


    #  WHAT IS HAPPENING HERE?
    #
    #  The methods contained in the @{$Bgruven{GRUVEN}->{OPTS}{methods}} list control which methods of
    #  acquisition are to be used to download the BUFR files.  If no method is explicitly specified on
    #  the command line then the list defaults the configuration settings defined on the options
    #  subroutine, probably https, http and ftp. 
    #
    #  If a user does specify a method on the command line then that method is used to populate
    #  the @{$Bgruven{GRUVEN}->{OPTS}{methods}} list. Additionally, the options/arguments are
    #  defined by $Bgruven{GRUVEN}->{OPTS}{lc $meth}.
    #
    my %rsources=();
    foreach my $meth (@{$Bgruven{GRUVEN}->{OPTS}{methods}}) {

        my $m = lc $meth; $m = "--$m"; $meth = uc $meth;  #  Both meth and host are UC in the SOURCES hash
    
        if ($Bgruven{GRUVEN}->{OPTS}{lc $meth}) {  #  User passed command line flag for the method of acquisition AND included arguments (not just --http)

            $Bgruven{GRUVEN}->{OPTS}{lc $meth} =~ s/:+/:/g;  #  reduce number of ":"s to one

            my ($host,$path) = split /:/ => $Bgruven{GRUVEN}->{OPTS}{lc $meth};

            if ($host =~ /\//) {$path = $host; $host = 'LOCAL';}
            if ($host eq 'LOCAL' and $meth ne 'NFS') { &Utils::modprint(6,4,104,1,1,"Hey, \"$m $Bgruven{GRUVEN}->{OPTS}{lc $meth}\" is not allowed"); next;}

            unless ($path) {
                unless ($Bgruven{BINFO}->{SOURCES}{$meth}{$host} or $Bgruven{BINFO}->{SOURCES}{$meth}{uc $host}) {
                    &Utils::modprint(6,4,104,1,1,"Hmm, there no host \"$host\" specified for method \"$meth\" in $Bgruven{BINFO}->{DSET}{fname}"); next;
                }
                $path = $Bgruven{BINFO}->{SOURCES}{$meth}{$host} if  $Bgruven{BINFO}->{SOURCES}{$meth}{$host};
                $path = $Bgruven{BINFO}->{SOURCES}{$meth}{uc $host} if  $Bgruven{BINFO}->{SOURCES}{$meth}{uc $host};
            }
            $rsources{$meth}{$host} = $path;
        } else { #  Use all the available sources
           %{$rsources{$meth}} = %{$Bgruven{BINFO}->{SOURCES}{$meth}} if keys %{$Bgruven{BINFO}->{SOURCES}{$meth}};
        }
    }

    #  Go through the list of available sources and map each HOST key to an IP or address
    #
    foreach my $meth (keys %rsources) {
        foreach my $host (keys %{$rsources{$meth}}) {
            $rsources{$meth}{$host} = &Utils::fillit($rsources{$meth}{$host},@phs);  #  Populate the placeholders
            if (my $add = &Utils::hkey_resolv(uc $host,%{$Bgruven{GRUVEN}->{HKEYS}})) {$proc{SOURCES}{$meth}{$add} = $rsources{$meth}{$host};}
        }
    }

    unless (%{$proc{SOURCES}})  {$mesg = "Well this is unusual. I was unable to identify any available data sources."; return;}

    #  Turn OFF exporting of files not being processed
    #
    if ($Bgruven{GRUVEN}->{OPTS}{noexport})  {@{$Bgruven{BINFO}->{EXPORT}{$_}}=() foreach keys %{$Bgruven{BINFO}->{EXPORT}};}
    if ($Bgruven{GRUVEN}->{OPTS}{noprocess}) {@{$Bgruven{BINFO}->{EXPORT}{$_}}=() foreach qw (GEMPAK BUFKIT ASCII);}

    @{$Bgruven{BINFO}->{EXPORT}{BUFKIT}}=() if $Bgruven{GRUVEN}->{OPTS}{nobufkit};
    @{$Bgruven{BINFO}->{EXPORT}{ASCII}} =() if $Bgruven{GRUVEN}->{OPTS}{noascii};


    #  If the user requested that BUFKITP files be exported then we better make sure
    #  that the files are created. Set prepend option ON.
    #
    $Bgruven{GRUVEN}->{OPTS}{prepend} = 1 if @{$Bgruven{BINFO}->{EXPORT}{BUFKITP}};


    #  Set the verbose mode
    #
    $ENV{VERBOSE} = defined $Bgruven{GRUVEN}->{OPTS}{verbose} ? $Bgruven{GRUVEN}->{OPTS}{verbose} : $Bgruven{GRUVEN}->{INFO}{verbose};

    $Bgruven{PROCESS} = &init_recs('proc', %proc);

    if ($Bgruven{GRUVEN}->{OPTS}{debug}) {
        #  Open the debug file if necessary
        #
        open DEBUGFL => ">$Bgruven{GRUVEN}->{DIRS}{debug}/start.debug.$$";
        my $dd = Dumper \%Bgruven; $dd =~ s/    / /mg;print DEBUGFL $dd; 
        close DEBUGFL;
    }

    #  Set the newbufrs count to zero
    #
    $Bgruven{PROCESS}->{STATIONS}{newbufrs} = 0;

return 1;
}  #  End of configure


sub read_bconf {
#----------------------------------------------------------------------------------
#  This routine reads the contents of the bufr_info configuration file and
#  parses the values before placing them in the %biconf hash. The %biconf
#  hash is returned.
#----------------------------------------------------------------------------------
#
    my (@list, %biconf) = ();

    my $dset = shift;

    my @members=();  #  for the MEMBER-KEYS enties
    my %methods=();  #  Added to help separate monolithic from single station file naming conventions

    #  We must initialize/define the record
    #
    $biconf{$_}             = ()  foreach qw (DSET GEMPAK SOURCES EXPORT);

    %{$biconf{GEMPAK}{$_}}  = ()  foreach qw (sfpack snpack packaux timstn); #  The  GEMPAK hash

    @{$biconf{EXPORT}{$_}}  = () foreach qw (BUFR GEMPAK BUFKIT ASCII BUFKITP);      #  The EXPORT  hash
    %{$biconf{SOURCES}{$_}} = () foreach qw (FTP HTTP HTTPS NFS);

    @{$biconf{DSET}{cycles}}=();
    %{$biconf{DSET}{members}}=();


    my $fname = "${dset}_bufrinfo.conf"; $biconf{DSET}{fname} = $fname;
    $biconf{DSET}{dset} = $dset;

    open INFILE => "$Bgruven{GRUVEN}{DIRS}->{conf}/$fname" or &Love::died("Read failed: $! - $fname");

    my $cl=0;
    while (<INFILE>) {
        s/^ +//g;
        if (/^#/) {$cl=0;next;}
        next unless /\w/;
        chomp; s/=//g;

        if (s/INFO//g) {s/^\s*//g;$biconf{DSET}{info} = $_; next;}
        if ($cl) {s/,+|;+/;/g;s/:+/:/g;@members = (@members,split (/;/,$_)); next;}
        if (s/MEMBER-KEYS//g) {s/,+|;+/;/g;s/:+/:/g;@members = split (/;/,$_); $cl=1; next;}

        s/ //g;
        if (s/MODEL//g) {s/,+|;+|:+/ /g; @{$biconf{DSET}{model}} = split (/ /,$_); $cl=1; next;}
        if (s/LOCFIL//g) {$biconf{DSET}{locfil}  = $_; next;}
        if (s/DELAY//g)  {$biconf{DSET}{delay}   = $_; next;}
        if (s/STNTBL//g) {$biconf{DSET}{stntbl}  = $_; next;}

        if (s/CYCLES//g) {s/,+|;+|:+/ /g; @{$biconf{DSET}{cycles}} =  split (/ /,$_); foreach (@{$biconf{DSET}{cycles}}) {$_+=0; $_ = "0$_" if length $_ == 1;} next;}

        if (s/SFPACK//g) {$biconf{GEMPAK}{sfpack}  = $_; next;}
        if (s/SNPACK//g) {$biconf{GEMPAK}{snpack}  = $_; next;}
        if (s/SFCAUX//g) {$biconf{GEMPAK}{packaux} = $_; next;}
        if (s/TIMSTN//g) {$biconf{GEMPAK}{timstn}  = $_; next;}


        if (s/SERVER-FTP//g) {
            s/,+|;+| +//g;
            @list = split (/:/,$_,2);
            if ($list[0] and $list[1]) {
                push @{$methods{FTP}{$list[0]}} => $list[1];
            } else {
                my $info = $list[0] ? $list[0] : $list[1];
                &Utils::modprint(6,7,104,1,1,sprintf("Mis-configured SERVER-FTP entry (Line with %s)",$list[0] ? $list[0] : $list[1]));
            }
            next;
        }


        if (s/SERVER-HTTPS//g) {
            s/,+|;+| +//g;
            @list = split (/:/,$_,2);
            if ($list[0] and $list[1]) {
                push @{$methods{HTTPS}{$list[0]}} => $list[1];
            } else {
                my $info = $list[0] ? $list[0] : $list[1];
                &Utils::modprint(6,7,104,1,1,sprintf("Mis-configured SERVER-HTTPS entry (Line with %s)",$list[0] ? $list[0] : $list[1]));
            }
            next;
        }


        if (s/SERVER-HTTP//g) {
            s/,+|;+| +//g;
            @list = split (/:/,$_,2);
            if ($list[0] and $list[1]) {
                push @{$methods{HTTP}{$list[0]}} => $list[1];
            } else {
                my $info = $list[0] ? $list[0] : $list[1];
                &Utils::modprint(6,7,104,1,1,sprintf("Mis-configured SERVER-HTTP entry (Line with %s)",$list[0] ? $list[0] : $list[1]));
            }
            next;
        }


        if (s/SERVER-NFS//g) {
            s/,+|;+| +//g;
            @list = split (/:/,$_,2);
            unless ($list[0] and $list[1]) {
                if ($list[0]) {
                    $list[1] = $list[0];
                    $list[0] = 'LOCAL';
                } else {
                    $list[0] = 'LOCAL';
                }
            }
            push @{$methods{NFS}{$list[0]}} => $list[1];
            next;
        }

        if (s/EXPORT_BUFR//g)    {push @{$biconf{EXPORT}{BUFR}}    => $_; next;}
        if (s/EXPORT_GEMPAK//g)  {push @{$biconf{EXPORT}{GEMPAK}}  => $_; next;}
        if (s/EXPORT_BUFKITP//g) {push @{$biconf{EXPORT}{BUFKITP}} => $_; next;}
        if (s/EXPORT_BUFKIT//g)  {push @{$biconf{EXPORT}{BUFKIT}}  => $_; next;}
        if (s/EXPORT_ASCII//g)   {push @{$biconf{EXPORT}{ASCII}}   => $_; next;}

    } close INFILE;


    #  I don't like putting this block here as I was hoping to avoid the use of
    #  command-line flags in this routine but it saves time when adding the 
    #  --monolithic option to the code.
    #
    foreach my $meth (keys %methods) {
        my @list=();
        foreach my $src (keys %{$methods{$meth}}) {
            @list = $Bgruven{GRUVEN}->{OPTS}{mono} ? grep (/class1|tm00|\.tar/i => @{$methods{$meth}{$src}}) : grep (! /class1|tm00|\.tar/i => @{$methods{$meth}{$src}});
            next unless @list;
            $biconf{SOURCES}{$meth}{$src} = $list[0];
            if ($Bgruven{GRUVEN}->{OPTS}{mono}) {
                $Bgruven{GRUVEN}->{OPTS}{mono} = &Utils::popit($list[0]);
                $Bgruven{GRUVEN}->{OPTS}{mono} =~ s/\.gz$//g;
            }
        }
    }

    $biconf{DSET}{fname}     = $fname;
    @{$biconf{DSET}{cycles}} = &Utils::rmdups(@{$biconf{DSET}{cycles}});

    #  Process the MEMBER-KEYS field and clean up the strings
    #
    @{$biconf{DSET}{members}{order}} = ();
    foreach (@members) {
        my ($mem,$key) = split (/:/,$_,2); $mem =~ s/\s+//g; $key =~ s/^\s+|\s+$//g;
        next unless $mem;
        unless ($key) {&Utils::modprint(6,7,104,1,1,"MEMBER-KEYS: Member \"$mem\" is missing a descriptor string - Syntax problem?");next;}
        $biconf{DSET}{members}{$mem} = $key;
        push @{$biconf{DSET}{members}{order}} => $mem;
    }


return %biconf;
}   #  The end of read_bconf


sub init_recs {
#----------------------------------------------------------------------------------
#  This routine initializes the BUFR data set information record, the data record,
#  and the processing record.
#----------------------------------------------------------------------------------
#
    my ($rec,%hash) = @_;

    if ($rec =~ /binfo/) { #  Initialize the bufrinfo record
        return $rec = {
            DSET     => {%{$hash{DSET}}},
            SOURCES  => {%{$hash{SOURCES}}},
            EXPORT   => {%{$hash{EXPORT}}},
            GEMPAK   => {%{$hash{GEMPAK}}}
        };
    }

    if ($rec =~ /data/) { #  Initialize the data file record
        return $rec = {
            BUFR     => [@{$hash{bufr}}],
            GEMPAK   => [@{$hash{gempak}}],
            ASCII    => [@{$hash{ascii}}],
            BUFKIT   => [@{$hash{bufkit}}]
        };
    }

    if ($rec =~ /proc/) { #  Initialize the data processing information record
        return $rec = {
            DATE       => {%{$hash{DATE}}},
            STATIONS   => {%{$hash{STATIONS}}},
            SOURCES    => {%{$hash{SOURCES}}},
            DATA       => {%{$hash{DATA}}}
        };
    }

    if ($rec =~ /gruven/) { #  Initialize the data processing information record
        return $rec = {
            INFO       => {%{$hash{INFO}}},
            DIRS       => {%{$hash{DIRS}}},
            HKEYS      => {%{$hash{HKEYS}}},
            DSETS      => [@{$hash{DSETS}}]
        };
    }

return;
} #  The end of init_brec


