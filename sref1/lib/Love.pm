#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Love.pm
#
#  DESCRIPTION:  Contains basic help & guidance routines for Bufrgruven
#                At least that's the plan
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  11.0
#      CREATED:  06/28/2011 10:31:20 PM
#     REVISION:  ---
#===============================================================================
#
package Love;
require 5.8.0;
use strict;
use warnings;
use English;


sub defopts {
#-------------------------------------------------------------------------------------
#  This routine defined the list of options that can be passed to the program
#  and returns them as a hash.
#-------------------------------------------------------------------------------------
#
    my %opts = (
                '--dset'        => { arg => 'data set'    , desc => 'The moniker for the requested data set identified by <data set>_bufrinfo.conf'},
                '--stations'    => { arg => 'station list', desc => 'A list of BUFR stations (STNM or STID) separated by a comma(,)'},
                '--date'        => { arg => 'yyyymmdd'    , desc => 'Specify the date (YYYYMMDD) of the requested data set'},
                '--cycle'       => { arg => 'hour'        , desc => 'Specify the cycle hour for the requested data set'},
                '--previous'    => { arg => ''            , desc => 'Download bufr files from the previous data set (not current)'},
                '--nodelay'     => { arg => ''            , desc => 'Override the default delay setting in the _bufrinfo.conf file'},
                '--metdat'      => { arg => 'directory'   , desc => 'Override metdat directory location with <directory>'},
                '--ftp'         => { arg => '[server]'    , desc => 'Acquire the desired bufr files via ftp [from server]'},
                '--http'        => { arg => '[server]'    , desc => 'Acquire the desired bufr files via http [from server]'},
                '--nfs'         => { arg => '[server]'    , desc => 'Acquire the desired bufr files from a local system (cp or scp)'},
                '--noprocess'   => { arg => ''            , desc => 'Do not process the downloaded bufr files'},
                '--noexport'    => { arg => ''            , desc => 'Do not export any processed files. Overrides all _bufrinfo.conf settings'},
                '--nobufkit'    => { arg => ''            , desc => 'Do not process the downloaded bufr files into bufkit format'},
                '--noascii'     => { arg => ''            , desc => 'Do not process the downloaded bufr files into text format'},
                '--prepend'     => { arg => ''            , desc => 'Include the YYYYMMDDCC in the bufkit file naming convention'},
                '--forced'      => { arg => ''            , desc => 'Force downloading of all bufr files'},
                '--forcep'      => { arg => ''            , desc => 'Force processing of all bufr files'},
                '--[no]verbose' => { arg => ''            , desc => '[Do not] Let me know what is going on. Overrides bufrgruven.conf file setting'},
                '--[no]zipit'   => { arg => ''            , desc => '[Do not] Compress the BUFKIT files to create "*.buz" data.'},
                '--stnlist'     => { arg => 'model [str]' , desc => 'List out bufr stations for the model data set'},
                '--dslist'      => { arg => ''            , desc => 'List out the bufr data sets available for downloading'},
                '--debug'       => { arg => ''            , desc => 'Print out oodles and oodles of information for troubleshooting. '},
                '--clean'       => { arg => ''            , desc => 'Clean up the distribution prior to bufr file download and processing'},
                '--tidy'        => { arg => ''            , desc => 'Clean up the distribution and then just exit - no data processing'}
               );
return %opts;
}

sub stnlist {
#----------------------------------------------------------------------------------
#  This routine simply provides a listing of the available stations for a given 
#  specified data set.
#----------------------------------------------------------------------------------

my %Bgruven = %Start::Bgruven;

    my $mesg;
    my ($dset, @strs) = @_;

    if (@strs) {$_ = uc $_ foreach @strs; @strs = &Utils::rmdups(@strs);}

    #  Grab the data set that sould have been passed first
    #
    unless ($dset) {
         &Utils::modprint(6,4,88,1,1,"The first argument to --stnlist DSET must be a data set.\n\nPick one: @{$Bgruven{GRUVEN}->{DSETS}}");
         &exit(1);
    }

    unless (grep /^$dset$/i, @{$Bgruven{GRUVEN}->{DSETS}}) {
         &Utils::modprint(6,4,88,1,1,"The first argument to --stnlist ($dset) must be a valid data set.\n\nPick again: @{$Bgruven{GRUVEN}->{DSETS}}");
         &exit(1);
    }


    my $table;
    my $fname = "${dset}_bufrinfo.conf"; 
    open INFILE => "$Bgruven{GRUVEN}{DIRS}->{conf}/$fname" or &died("Read failed: $! - $fname");
    while (<INFILE>) {
        next if /^#/; next unless /\w/; chomp;
        next unless /STNTBL/;
        s/ //g; s/=//g;
        $table  = $_ if s/STNTBL//g;
    } close INFILE; $table = "$Bgruven{GRUVEN}->{DIRS}{stns}/$table" if $table;

    unless (open (INFILE,$table)) {$mesg = "You're not bufrgruven without the $dset station table:\n\n$table"; &died($mesg);}

    @strs ? &Utils::modprint(0,5,104,1,1,"Here are the matching stations from the $dset BUFR station list:") : 
            &Utils::modprint(0,5,104,1,1,"You wanted to see it - Here's the entire $dset BUFR station list:");
    
    &Utils::modprint(0,8,104,1,1,"Number    ID      Description                       Latitude   Longitude");
    &Utils::modprint(0,6,104,0,1,"----------------------------------------------------------------------------");
    
    my $m;
    while (<INFILE>) { 
        chomp; next unless $_;
        $m=1;
        if (@strs) {$m=0; foreach my $str (@strs) {$m = 1 if $_ =~ /$str/i;}}
        next unless $m;
        
        my @fields = split / +/ => $_; pop @fields;
        &Utils::modprint(0,8,104,0,1,sprintf("%-6s    %-6s  %-32s  %-8s   %-8s",$fields[0],$fields[3],(join ' ', @fields[5..$#fields]),$fields[1],$fields[2]));
   }

   &Utils::modprint(0,6,104,0,1,"----------------------------------------------------------------------------");

&exit(-1);
}

sub dslist {
#----------------------------------------------------------------------------------
#  This routine simply provides a listing of the supported data sets
#----------------------------------------------------------------------------------

my %Bgruven = %Start::Bgruven;

    my $mesg;
    my %info=();

    &Utils::modprint(0,5,104,1,1,"BUFRgruven is a proud supporter of the following data sets:");
    &Utils::modprint(0,8,104,1,1,"Data Set         Description");
    &Utils::modprint(0,6,104,0,1,"------------------------------------------------------------------------------------");


    foreach my $dset (@{$Bgruven{GRUVEN}->{DSETS}}) {
        my $fname = "${dset}_bufrinfo.conf";
        open INFILE => "$Bgruven{GRUVEN}{DIRS}->{conf}/$fname" or &died("Read failed: $! - $fname");
        while (<INFILE>) {
            next if /^#/; next unless /\w/; chomp;
            next unless /INFO/;
            s/=//g;
            $info{$dset} = $_ if s/INFO//g;
        } close INFILE; 
    }

    
    foreach my $ds (sort keys %info) {&Utils::modprint(0,9,144,0,1,sprintf("%-8s %s",$ds,$info{$ds}));}
   &Utils::modprint(0,6,104,0,1,"------------------------------------------------------------------------------------");

&exit(-1);
}


sub hello {
#----------------------------------------------------------------------------------
#  Provide a semi-informative greeting to the user
#----------------------------------------------------------------------------------
#
    my $date = gmtime();
    &Utils::modprint(0,2,144,1,1,sprintf ("You started BUFRgruven (V%s) on %s UTC",shift,$date));

return;
}


sub help {
#-------------------------------------------------------------------------------------
#  This routine prints out a help menu to the user when the "--help" option is passed
#-------------------------------------------------------------------------------------
#
    my %opts = &defopts;  #  Get options list
    my $exe  = shift;

    &Utils::modprint(0,7,114,2,1,"Bufrgruven Usage: % $exe [Options]");

    &Utils::modprint(0,7,114,1,1,"Where the option list consists of the following:");
    
    &Utils::modprint(0,14,114,1,2,"Option       argument         Description");

    foreach my $opt (sort keys %opts) {
        &Utils::modprint(0,12,144,0,1,sprintf("%-15s %-15s %-60s",$opt,$opts{$opt}{arg},$opts{$opt}{desc}));
    }

    &Utils::modprint(0,7,114,0,2,"Or");
    &Utils::modprint(0,9,114,0,1,"% $0 --guide     For additional help, love, and understanding");
    &Utils::modprint(0,9,114,0,2,"% $0 --help      For help, love, understanding, and this menu again");

&exit(-1);
}

sub guide {
#-------------------------------------------------------------------------------------
#  This routine prints out the bufr_gruven guide
#-------------------------------------------------------------------------------------
#
    my $mesg;
    my ($exe,$ver) = @_;

    &Utils::modprint(0,4,114,2,2,"The Uncensored Guide to the SOO/STRC BUFR File Acquisition and Processing Program (BUFRgruven)*");

    &Utils::modprint(0,7,94,1,1,"BUFRgruven - What is it?");

    $mesg = "The BUFRgruven package downloads and processes BUFR sounding files into a format for use by ".
            "BUFKIT, NAWIPS, NSHARP, and other display packages. These data sets are popular with forecasters ".
            "and politicians as they originate from operational models on native coordinates and have a ".
            "temporal resolution greater than that currently available from any gridded operational data source.";

    &Utils::modprint(0,10,94,1,2,$mesg);

    &Utils::modprint(0,7,94,1,1,"UNLEASHING THE POWER (You know you want to):");
 
    $mesg = "When processing BUFR files, the typical bufr_gruven.pl usage will be:\n\n".

            "  % bufr_gruven.pl --dset <data set> --stations <station list> [other options]\n\n".

            "Where:\n".
            "     --dset <data set>          (mandatory)   Defines the BUFR data set you wish to process,\n".
            "     --stations <station list>  (mandatory)   The list of BUFR stations, and\n".
            "     [other options]            (optional)    The list of other available options.";

    &Utils::modprint(0,10,114,1,2,$mesg);

    &Utils::modprint(0,7,94,1,1,"MANDATORY OPTIONS (And an Oxymoron for you):");

    &Utils::modprint(0,10,114,1,1,"Flag:  --dset DSET\n\n    Specifies the BUFR data set to use");

    $mesg = "The \"--dset\" flag specifies the BUFR data set you wish to acquire and process. ".
            "The DSET must be one of the supported BUFR data sets and have a corresponding ".
            "DSET_bufrinfo.conf file in the conf directory. For example:\n\n".

            "    % bufr_gruven.pl --dset nam  [other options & stuff]\n\n".

            "Use the \"--dslist\" flag to get a listing of the available data sets.";

    &Utils::modprint(0,12,94,1,1,"Description:");
    &Utils::modprint(0,14,94,1,2,$mesg);


    &Utils::modprint(0,10,114,1,1,"Flag:  --stations stn1,stn2,...,stnN\n\n    Specifies stations you want to process");

    $mesg = "The argument list for the \"--stations\" option is a list of BUFR stations, separated ".
            "by a comma (,) and without spaces. Either a station number or ID may be used. For example:\n\n".

            "    % bufr_gruven.pl --dset nam --stations KRDU,041001,KGSO,723170   (yes)\n\n".
            "    % bufr_gruven.pl --dset nam --stations KRDU, 041001, KGSO, 723170 (no)\n\n".

            "In the above examples the BUFR station KGSO is identified by both the station ".
            "number (723170) and ID (KGSO).  No problem as bufr_gruven.pl will eliminate any ".
            "\"monkey business\" from the list.\n\n".

            "For a list of the available stations use the \"--stnlist\" flag.";

    &Utils::modprint(0,12,94,1,1,"Description:");
    &Utils::modprint(0,14,94,1,2,$mesg);


    &Utils::modprint(0,7,94,1,1,"ACQUISITION METHODS:");

    &Utils::modprint(0,10,114,1,1,"Flag:  --ftp|http|nfs [SERVER[:LOCATION]]\n\n    Specifies the acquisition method and data source");

    $mesg = "You do not have to include a method of acquisition with bufr_gruven.pl as the default behavior ".
            "is to use the list of non-nfs sources from the DSET_bufrinfo.conf file. However, should you feel ".
            "the urge to limit the search or specify a new source of BUFR booty then you have the power.\n\n".

            "Passing the --ftp, --http, and/or --nfs flags will cause bufr_gruven.pl to search for BUFR files ".
            "from a ftp, http, or nfs (local) source respectively. Passing --ftp, --http, and/or --nfs without ".
            "arguments will result in bufr_gruven.pl using those FTP, HTTP, and/or NFS sources listed in the ".
            "DSET_bufrinfo.conf file. So passing only \"--nfs\" will result in bufr_gruven.pl excluding any ".
            "FTP or HTTP sources from the search.  Passing both --ftp and --http is the same as not passing ".
            "any acquisition methods since that is the default.  If your source is local then you ".
            "must include the \"--nfs\" flag; otherwise only HTTP and FTP will be used.";

    &Utils::modprint(0,12,94,1,1,"Description:");
    &Utils::modprint(0,14,94,1,1,$mesg);
    &Utils::modprint(0,14,94,1,1,"FTP or HTTP");

    $mesg = "Arguments to --ftp and --http may either be a SERVER ID that is used to identify a remote system ".
            "or a string that specifies the IP/hostname of a server followed by the path to the file and a ".
            "naming convention. See a DSET_bufrinfo.conf file for appropriate naming conventions. The SERVER ".
            "ID must have a corresponding entry in the DSET_bufrinfo.conf and also be defined in the ".
            "bufrgruven.conf file. E.g.:\n\n".

            "    % bufr_gruven.pl --dset nam --http STRC\n\n".

            "Where STRC has an entry in the nam_bufrinfo.conf file as:\n\n".

            "    SERVER-HTTP = STRC:/data/YYYYMMDD/nam/bufr.STNM.YYYYMMDDCC\n\n".

            "And STRC is defined in the conf/bufrgruven.conf file as:\n\n".

            "    STRC = strc.comet.ucar.edu\n\n".

            "It is also possible to specify a hostname and directory/filename string separated by a ".
            "colon(:) as an argument to --ftp and --http, E.g.:";

    &Utils::modprint(0,14,94,1,1,$mesg);

    $mesg = "    % bufr_gruven.pl --dset nam --ftp strc.comet.ucar.edu:/data/YYYYMMDD/bufr.STNM.YYYYMMDDCC\n".
            "Or\n".
            "    % bufr_gruven.pl --dset nam --ftp 128.117.110.214:/data/YYYYMMDD/bufr.STNM.YYYYMMDDCC";

    &Utils::modprint(0,14,114,1,1,$mesg);

    $mesg = "Note that in each of the above examples, the YYYY, MM, DD, FF, and CC will be replaced with the ".
            "appropriate values.";

    &Utils::modprint(0,14,94,1,1,$mesg);
    &Utils::modprint(0,14,94,2,1,"NFS");

    $mesg = "Passing --nfs will cause bufr_gruven.pl to search for BUFR files on a locally-accessible ".
            "system using either secure copy (scp) or copy (cp) commands. Not passing any arguments, ".
            "i.e, just \"--nfs\", will instruct the routine to use each machine listed in the appropriate ".
            "DSET_bufrinfo.conf file by a SERVER-NFS identifier.\n\n".

            "An argument to --nfs may either be a SERVER ID that is used to identify a system. The ".
            "SERVER ID must have a corresponding entry in the DSET_bufrinfo.conf and be defined in the ".
            "bufrgruven.conf file. E.g.:\n\n".

            "    % bufr_gruven.pl --dset nam --nfs system_a\n\n".

            "Where SYSTEM_A has an entry in the nam_bufrinfo.conf file as:\n\n".

            "    SERVER-NFS = SYSTEM_A:/data/YYYYMMDD/nam/bufr.STNM.YYYYMMDDCC\n\n".

            "And SYSTEM_A is also defined in the conf/bufrgruven.conf file as:\n\n".

            "    SYSTEM_A = systema.comet.ucar.edu\n".
            "Or\n".
            "    SYSTEM_A = user\@systema.comet.ucar.edu\n\n".

            "The SERVER-NFS entry does not have to include a server ID. You may include the hostname ".
            "information directly on the SERVER-NFS line. E.g.:";

    &Utils::modprint(0,14,94,1,1,$mesg);

    $mesg = "    SERVER-NFS = systema.comet.ucar.edu:/data/YYYYMMDD/nam/bufr.STNM.YYYYMMDDCC\n".
            "Or\n".
            "    SERVER-NFS = user\@systema.comet.ucar.edu:/data/YYYYMMDD/nam/bufr.STNM.YYYYMMDDCC\n\n";

    &Utils::modprint(0,14,114,1,1,$mesg);

    $mesg = "In each of the examples above secure copy (scp) is used to access the requested files ".
            "on another system; however, if your files are locally available in a directory you don't ".
            "need to include the [user@]hostname information. E.g.:\n\n".

            "    SERVER-NFS = /data/bufr/YYYYMMDD/nam/bufr.STNM.YYYYMMDDCC\n".
            "Or\n".
            "    SERVER-NFS = LOCAL:/data/bufr/YYYYMMDD/nam/bufr.STNM.YYYYMMDDCC\n\n".

            "In which case the copy (cp) command will be used to access the files.\n\n".

            "It is also possible to specify a hostname and directory/filename string separated by a ".
            "colon(:) as an argument to --nfs, E.g.:";

    &Utils::modprint(0,14,94,1,1,$mesg);

    $mesg = "    % bufr_gruven.pl --dset nam --nfs servera.comet.ucar.edu:/data/YYYYMMDD/nam/bufr.STNM.YYYYMMDDCC\n".
            "Or\n".
            "    % bufr_gruven.pl --dset nam --nfs user\@servera.comet.ucar.edu:/data/YYYYMMDD/nam/bufr.STNM.YYYYMMDDCC\n".
            "Or\n".
            "    % bufr_gruven.pl --dset nam --nfs /data/YYYYMMDD/nam/bufr.STNM.YYYYMMDDCC";

    &Utils::modprint(0,14,124,1,1,$mesg);


    &Utils::modprint(0,7,94,2,1,"ADDITIONAL SEMI-USELESS OPTIONS THAT YOU CAN'T LIVE WITHOUT:");


    &Utils::modprint(0,10,114,1,1,"Flag:  --cycle CYCLE HOUR\n\n    Specifies the cycle hour of the data set");
    &Utils::modprint(0,12,94,1,1,"Description:");
    $mesg = "Not passing the --cycle option will cause the script to use the cycle time of the ".
            "most recent model run from which data are available. In determining the cycle time ".
            "of the most recently available BUFR files, bufr_gruven.pl accounts for the amount of time ".
            "required to run the operational model and process the BUFR files for distribution.\n\n".

            "For example, if it takes NCEP two hours to run and process grib files then the script ".
            "will not attempt to obtain data from the 12Z run until after 14Z. The delay (DELAY) ".
            "and available cycles parameters for each data set are defined in each bufrinfo.conf ".
            "file.\n\n".

            "DO NOT use the --cycle option for real-time processing of BUFR files.";
    &Utils::modprint(0,14,94,1,2,$mesg);


    &Utils::modprint(0,10,114,1,1,"Flag:  --date [YY]YYMMDD\n\n    Specifies the date of the data set");
    &Utils::modprint(0,12,94,1,1,"Description:");
    $mesg = "Passing the \"--date\" option defines the date of the BUFR forecast files to use. ".
            "The argument to this option is a 4- or 2-digit year, 2-digit month (01 to 12), and ".
            "2-digit day (01 to 36).\n\n".

            "Not passing the --date option will cause bufr_gruven.pl to use the current date on ".
            "the system.\n\n".

            "DO NOT use the --date option for real-time processing of BUFR files.";
    &Utils::modprint(0,14,94,1,2,$mesg);


    &Utils::modprint(0,10,114,1,1,"Flag:  --metdat NEW METDAT DIRECTORY\n\n    Override the metdat directory and location");
    &Utils::modprint(0,12,94,1,1,"Description:");
    $mesg = "Passing --metdat <directory path> defines the directory location for the various files processed and created ".
            "by $exe.  Normally, all files are located under \"bufrgruven/metdat\"; however, the --metdat option will ".
            "override this location in favor of the specified directory.\n\nYou do not need to include \"metdat\" as part ".
            "of the specified <path>/directory. BUFRgruven will use whatever name you request.";
    &Utils::modprint(0,14,94,1,2,$mesg);


    &Utils::modprint(0,10,114,1,1,"Flag:  --nodelay\n\n    Set the DELAY value to 0 hours");
    &Utils::modprint(0,12,94,1,1,"Description:");
    $mesg = "Passing the --nodelay option will turn off (set to 0 hours) the default DELAY ".
            "value defined in each _bufrinfo.conf file.";
    &Utils::modprint(0,14,94,1,2,$mesg);


    &Utils::modprint(0,10,114,1,1,"Flag:  --nobufkit\n\n    Turns off BUFKIT file processing");
    &Utils::modprint(0,12,94,1,1,"Description:");
    $mesg = "Passing --nobufkit turns off processing of BUFR files into BUFKIT format.";
    &Utils::modprint(0,14,94,1,2,$mesg);

    
    &Utils::modprint(0,10,114,1,1,"Flag:  --noascii\n\n    Turns off generation of ASCII sounding files");
    &Utils::modprint(0,12,94,1,1,"Description:");
    $mesg = "Passing --noascii turns off processing of BUFR files into text files.";
    &Utils::modprint(0,14,94,1,2,$mesg);


    &Utils::modprint(0,10,114,1,1,"Flag:  --noexport\n\n    Turns off the exporting of files");
    &Utils::modprint(0,12,94,1,1,"Description:");
    $mesg = "Passing --noexport turns off the exporting of files to other systems as requested by the EXPORT_ ".
            "parameter in the DSET_bufrinfo.conf file.";
    &Utils::modprint(0,14,94,1,2,$mesg);


    &Utils::modprint(0,10,114,1,1,"Flag:  --noprocess\n\n    Do not process BUFR files after downloading");
    &Utils::modprint(0,12,94,1,1,"Description:");
    $mesg = "Passing --noprocess turns off the processing and exporting of BUFR files after downloading ".
            "them to the local system. You would use this option if you only wanted to grab the BUFR ".
            "files and nothing else.";
    &Utils::modprint(0,14,94,1,2,$mesg);


    &Utils::modprint(0,10,114,1,1,"Flag:  --[no]zipit\n\n    [Do not] compress the BUFKIT files into \"*.buz\" format");
    &Utils::modprint(0,12,94,1,1,"Description:");
    $mesg = "Passing --[no]zipit turns on|off the compressing of BUFKIT into \"*.buz\" format. Turning OFF this ".
            "option will result in the original ASCII version of BUFKIT files being created (\"*.buf\"). Passing ".
            "\"--zipit\" will result in the BUFKIT files being compressed and denoted with the \"*.buz\" suffix. ".
            "The default compression will be done by the \"zip\" routine (pkzip) unless it's unavailable on the ".
            "system, in which case \"gzip\" will be used.\n\n".

            "The --[no]zipit option overrides the ZIPIT parameter in the bufrgruven.conf file with the default ".
            "being to compress (zip) and create \"*.buz\" files.";
    &Utils::modprint(0,14,94,1,2,$mesg);


    &Utils::modprint(0,10,114,1,1,"Flag:  --previous\n\n    Requests that the previous cycle hour be used");
    &Utils::modprint(0,12,94,1,1,"Description:");
    $mesg = "Download and process BUFR files from the previous cycle of a model run rather than ".
            "the current one.";
    &Utils::modprint(0,14,94,1,2,$mesg);


    &Utils::modprint(0,10,114,1,1,"Flag:  --prepend\n\n    Appends YYYYMMDDCC to bufkit filenames");
    &Utils::modprint(0,12,94,1,1,"Description:");
    $mesg = "Passing --prepend will result in YYMMDDCC being added to the beginning of the newly ".
            "minted BUFKIT file. Due to popular demand a second file without the YYMMDDCC will ".
            "also be created but will not be exported.";
    &Utils::modprint(0,14,94,1,2,$mesg);


    &Utils::modprint(0,10,114,1,1,"Flag:  --forced\n\n    Forces downloading of BUFR files");
    &Utils::modprint(0,12,94,1,1,"Description:");
    $mesg = "Passing --forced will force bufr_gruven.pl to download the requested BUFR files regardless ".
            "of whether the files already exist on the local system. The default behavior is to not ".
            "attempt to download files that already exist locally. After the files have been ".
            "downloaded they are processed as expected.";
    &Utils::modprint(0,14,94,1,2,$mesg);


    &Utils::modprint(0,10,114,1,1,"Flag:  --forcep\n\n    Forces processing of BUFR files");
    &Utils::modprint(0,12,94,1,1,"Description:");
    $mesg = "Passing --forcep will force bufr_gruven.pl to process the requested BUFR files regardless ".
            "of whether the files already exist on the local system. The default behavior is to not ".
            "attempt to process files that already existed locally.";
    &Utils::modprint(0,14,94,1,2,$mesg);


    &Utils::modprint(0,10,114,1,1,"Flag:  --clean\n\n    Scours existing local files");
    &Utils::modprint(0,12,94,1,1,"Description:");
    $mesg = "Passing --clean will result in burf_gruven.pl scouring previously processed files from the ".
            "local system. It does not touch those locations identified by EXPORT in DSET_bufrinfo.conf.";
    &Utils::modprint(0,14,94,1,2,$mesg);


    &Utils::modprint(0,10,114,1,1,"Flag:  --tidy\n\n    Cleans up distribution and then exits");
    &Utils::modprint(0,12,94,1,1,"Description:");
    $mesg = "Passing --tidy will result in burf_gruven.pl scouring the logs, debug, and metdat directories ".
            "before exiting.  No data downloading or processing will be completed.";
    &Utils::modprint(0,14,94,1,2,$mesg);


    &Utils::modprint(0,10,114,1,1,"Flag:  --[no]verbose\n\n    Turn on|off the printing of interesting stuff to the screen");
    &Utils::modprint(0,12,94,1,1,"Description:");
    $mesg = "Passing --[no]verbose turns on|off the printing of interesting stuff to the screen. It will override the ".
            "default setting in the bufrgruven.conf file.  In the event of an error, the information will be ".
            "displayed regardless of that you want.";
    &Utils::modprint(0,14,94,1,2,$mesg);

 
    &Utils::modprint(0,10,114,1,1,"Flag:  --debug\n\n    Writes debug information to debug directory");
    &Utils::modprint(0,12,94,1,1,"Description:");
    $mesg = "Passing --debug will result in debugging files being written to the debug directory. ".
            "Files will be tagged with the Linux process ID for clarification.";
    &Utils::modprint(0,14,94,1,2,$mesg);


    &Utils::modprint(0,4,114,1,2,"* Feel free to create your own should you have some available time!");

&exit(-1);
}


sub int_handle {
#----------------------------------------------------------------------------------
#  Override the default behavior when sending an interrupt signal.
#----------------------------------------------------------------------------------
#
    $ENV{VERBOSE} = 1;  #  Set to verbose mode regardless of what the user wanted

    $ENV{BUFRERR}==2 ? &Utils::modprint(6,7,96,1,1,"Hey, just wait a moment while I finish my business!!") :
                       &Utils::modprint(0,7,96,2,2,"Terminated!? Me? - But I was just getting this BUFRgruven party started!");

    $ENV{BUFRERR}  = 2;  #  Set the EMS return error so that the files can be processed correctly.

    sleep 1;

&exit(99);
}



sub died {
#----------------------------------------------------------------------------------
#  Used instead of the Perl "die", this routine will allow for a more graceful
#  exit if all goes well. This routine takes a message string that is printed
#  and the name of the calling routine. It print the message and then calls
#  the exit routine.
#----------------------------------------------------------------------------------
#
    #  Override the user verbose setting
    #
    $ENV{VERBOSE} = 1;

    my $mesg = shift;

    &Utils::modprint(6,9,114,1,1,$mesg) if $mesg;
    &Utils::modprint(0,4,114,1,1,"BUFRgruven always says \"If in doubt, blame it on the tool!\"");

&exit(1);
}


sub exit {
#----------------------------------------------------------------------------------
#  Override the default behavior when exiting. Note that a return rout of < 0
#  causes nothing to be printed out. This is primarily used for the fork command.
#----------------------------------------------------------------------------------
#
#  If you are using Perl version 5.10 or higher then comment out the "use Switch 'Perl6'"
#  statement and uncomment the use feature "switch" line.
#
use Switch 'Perl6';      #  < Perl V5.10
#use feature "switch";   #  For Perl V5.10 and above

    $ENV{VERBOSE} = 1;

    my $date = gmtime();
    my $err = shift; $err  = 0 unless $err;

    my $mesg;
    given ($err) {
        when  ([-1]) {$mesg = sprintf ("Let's get this BUFRgruven party started!");$err=0;}
        when  ([ 0]) {$mesg = sprintf ("Your BUFRgruven party is complete - %s UTC",$date);}
        when  ([ 1]) {$mesg = sprintf ("Your gruven party ended at %s UTC - Ya know, stuff just happens",$date);}
        when  ([99]) {$mesg = sprintf ("BUFRgruven party terminated by Grumpy at %s UTC",$date);}
        default  {$mesg = sprintf ("There shall be no gruven for you at %s UTC",$date);}
    }
    &Utils::modprint(0,2,144,1,3,$mesg);

CORE::exit $err;
}
