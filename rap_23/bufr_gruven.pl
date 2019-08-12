#!/usr/bin/perl
#======================================================================
#                                                                      
#  The bufr_gruven.pl routine downloads and processes BUFR sounding    
#  files from both operational and non-operational model runs.         
#  The user can request the processed file format be compatible with   
#  NAWIPS, NSHARP, BUFKIT, or a more general ASCII format.             
#  Complete instructions for running bufr_gruven.pl are available      
#  on the SOO/STRC web site:                                           
#                                                                      
#     http://strc.comet.ucar.edu/software/bgruven                      
#                                                                      
#  And for the most basic of guidance:                                 
#                                                                      
#     % bufr_gruven.pl --help                                          
#  And                                                                 
#     % bufr_gruven.pl --guide                                         
#                                                                      
#  Log:                                                                
#                                                                      
#  R.Rozumalski : August 2011    - Official "B Gruven" Release         
#  R.Rozumalski : Today          - Many changes since August 2011      
#======================================================================
#
require 5.8.0;
use strict;
use warnings;
use English;
use FindBin qw($RealBin);
use lib "$RealBin/lib";
use vars qw (%Bgruven);

use Love;
use Utils;
use Start;
use Acquire;
use Process;
use Moveit;


    #  Define the top level of bufrgruven and release information
    #
    $Bgruven{HOME} = $RealBin;
    $ENV{VERBOSE}  = 1;
    $ENV{BUFRERR}  = 0;
    $ENV{LC_ALL}   = 'C';
    $ENV{BGRUVEN}  = $Bgruven{HOME};
    $Bgruven{EXE}  = &Utils::popit($0);
    $Bgruven{VER}  = "19.24.4";

    #  Override interrupt handler - Use the local one since some of the local
    #  environment variables are needed for clean-up after the interrupt.
    #
    $SIG{INT} = \&Love::int_handle;


    #  List help menu if no options passed
    #
    &Love::help($Bgruven{EXE}) unless @ARGV;

    #  Provide love and encouragement to the user
    #
    &Love::hello($Bgruven{VER});

    #  Read the configuration files and initialize the %Bgruven hash
    #
    %Bgruven = &Start::gruven;


    #  Determine which files to acquire and attempt to get them
    #
    %Bgruven = &Acquire::bufr;


    #  Process the BUFR files into the requested formats
    #
    %Bgruven = &Process::bufr;


    #  Export the data files to new and exotic locations
    #
    %Bgruven = &Moveit::gruven;

    
&Love::exit(0);

