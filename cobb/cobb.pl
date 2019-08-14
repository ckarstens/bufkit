#!/usr/bin/perl
# Perl Script
#
# Calculate Precip Type, SnowFall, and IceFall from bufkit files
#
# Dan Cobb  (daniel.cobb@noaa.gov)
# 
# V5.5
#
# There are two places in this script where you need to comment out one "while" line and uncomment
# a different version of that "while" line, depending on which O/S (Linux/Windows) the script is
# running on. To make finding these easier, both locations where this must be done are marked with
# a comment line exactly the same as the following...
#~~ OS FIX ~~#
#
# It is also necessary to change the value of the $myFile variable to point to the correct location
# to find the input bufkit files. To make finding this line easier, it is marked with the following
# comment line...
#~~ MY FILE ~~#
#
#######################################################################################################
#print "hello world\n";   # All programs start here :-)

use Math::Complex;
use Math::Trig;
use FileHandle;


$mode = "INTERACTIVE";
#$mode = "no" ;
$ptypeAlg = "old";
$avgHour = "NO" ;

$thermalShift = 0 ;
$RHThresh = 85.0 ;
$vvShift = 0.0 ;
$vvFactor = 1.0 ;

if ($ARGV[0] ne "" ) {
   $mode = "AUTO" ; 
   chomp ($myStation = $ARGV[0]) ; 
   chomp ($myModel = $ARGV[1])   ;
#   STDOUT->format_name("NORMAL") ; STDOUT->format_top_name("NORMAL_TOP") ;
   STDOUT->format_name("VER50") ; STDOUT->format_top_name("VER50_TOP"); 
#   STDOUT->format_name("VER51"); STDOUT->format_top_name("VER51_TOP");
   $= = 66;}
 else                {
  $myModel = "nam";
  goto GETSTATION }

print "\n" ;

while ( $myStation ne "exit" ) {
  splice( @fcstHR, 0 ) ;
#    $myFile = "C:/Program Files/BUFKIT/data/"."$myModel"."_"."$myStation".".buf" ;
#   $myFile = "C:/documents/DanCobb/snowratio/bufData/Data/"."$myModel"."_"."$myStation".".buf" ;
#  $myFile = "y://current/"."$myModel"."_"."$myStation".".buf" ;
#  $myFile = "p://bufkite/Data/"."$myModel"."_"."$myStation".".buf" ;
#  $myFile = "z://data/"."$myModel"."_"."$myStation".".buf";
#  $myFile = "./"."$myModel"."_"."$myStation".".buf";
#  $myFile = "//lan/bufkit_data/"."$myModel"."_"."$myStation".".buf";
#  $myFile = "/local/ckarsten/bufkit/modsnd/metdat/nam/"."$myModel"."_"."$myStation".".buf";
  $myFile = "gfs/metdat/bufkit/"."$myModel"."_"."$myStation".".buf";
#  $myFile = "/local/ckarsten/bufkit/gfs/cobb/data/"."$myModel"."_"."$myStation".".buf";
  open(BUFIN,$myFile) or goto GETSTATION ; 
    if     ($myModel eq "eta" or $myModel eq "etam" or $myModel eq "etaw" or $myModel eq "nam" or $myModel eq "nmm" or $myModel eq "arw" or $myModel eq "ruc") { ReadEtaBufkit() }
     elsif ($myModel eq "gfs" )                     { ReadGFSBufkit() }
  close (BUFIN) ;

  GetWndDirSpd() ;                            #Calculate 10 meter wind direction and speed from its u and V components.
  for($i = 0; $i <= $#fcstHR; $i++) { 
     GetRH() ;                                # Calculate Relative Humidity with wrt water and ice.  
     GetLyrMeans() ;                          # Calculate Layer means for temp, rh, wetbulb, pres, omega, and layer thickness.
  }  

  $cumHours = 0; $cumPrecipHours = 0; $cumSnow = 0.0; $cumSleet = 0.0; $cumIce = 0.0; $cumPrecip = 0.0; $cumSR = 0.0; $cumSWE = 0.0;
  if ( $statime eq "" ) {
    $= = ($#fcstHR + 4) ;
    for($i = 1; $i <= $#fcstHR; $i++) { 
       $SRpercent[$i] = 0.0; $IRpercent[$i] = 0.0; $RRpercent[$i] = 0.0;
       $snRatio[$i] = 0.0 ; $iceRatio[$i] = 0.0 ; $sleetRatio[$i] = 0.0;
       $Ptype[$i] = GetPrecipType() ;           # Determine precipitation type.
       if ($Ptype[$i] eq " SNOW " ) { GetSnow(); $snRatio[$i] *= $SRpercent[$i] }
	   if ($Ptype[$i] eq " SG   " ) { $snRatio[$i] = 4.0 } 
	   if ($Ptype[$i] eq " SNPL " ) { GetSnow(); $snRatio[$i] *= $SRpercent[$i] ; $sleetRatio[$i] = 2.0 * (1.0 - $SRpercent[$i]) }
	   if ($Ptype[$i] eq " PL   " ) { $sleetRatio[$i] = 2.0 } 
	   if ($Ptype[$i] eq " ZRPL " ) { $iceRatio[$i] = 1.05 * $RRpercent[$i]; $sleetRatio[$i] = 2.0 * (1.0 - $RRpercent[$i])  }
	   if ($Ptype[$i] eq " ZLSG " ) { $snRatio[$i] = 4.0 * $SRpercent[$i] ; $iceRatio[$i] = 1.05 * (1.0 - $SRpercent[$i]) }
	   if ($Ptype[$i] eq " FZRA " ) { $iceRatio[$i] = 1.05 } 
	   if ($Ptype[$i] eq " FZDZ " ) { $iceRatio[$i] = 1.05  } 
	   if ($Ptype[$i] eq "SNZRPL" ) { $iceRatio[$i] = 1.05 * $RRpercent[$i]; $sleetRatio[$i] = 2.0 * (1.0 - $RRpercent[$i])  }
	   if ($Ptype[$i] eq "SNRAPL" ) { $sleetRatio[$i] = 2.0 * (1.0 - $RRpercent[$i])  }
	   if ($temp2meter[$i] > 32.9 ) { $snowFall[$i] = 0.0 } else {$snowFall[$i] = $snRatio[$i]  * $precip[$i]}
       if ($temp2meter[$i] > 32.0 ) { $iceFall[$i] = 0.0 } else {$iceFall[$i]  = $iceRatio[$i] * $precip[$i]}
       if ($temp2meter[$i] > 32.9 ) { $sleetFall[$i] = 0.0 } else {$sleetFall[$i]  = $sleetRatio[$i] * $precip[$i]}

       $cumPrecip += $precip[$i];
       $cumSnow += $snowFall[$i];
	   if ( $Ptype[$i] eq " SNOW "  or $Ptype[$i] eq " SNPL " or $Ptype[$i] eq " SG   ") { $cumSWE += $precip[$i] }
	   #print "$cumSWE \n";
	   $cumIce += $iceFall[$i];
	   $cumSleet += $sleetFall[$i];
       if ( $snowFall[$i] > 0.0 ) {$cumSR = $cumSnow / $cumSWE }
       if ( $precip[$i] < 0.006 ) { if ( $myModel ne "gfs3") {$cumPrecipHours += 1.0 } else { $cumPrecipHours += 3.0 }} else { $cumPrecipHours = 0.0 } 
	   if ( $cumPrecipHours > 6.0 ) {$cumSnow = 0.0 ; $cumPrecip = 0.0 ; $cumSR = 0.0 ; $cumSleet = 0.0 ; $cumIce = 0.0 ; $cumSWE = 0.0 ; $cumPrecipHours = 0.0 ; }
       if ( $myModel ne "gfs3") {$cumHours += 1.0 } else { $cumHours += 3.0 }
	   if ( $cumHours > 6 and $myModel ne "gfs3" ) { $cumHours = 1 ;
		    print "----------------------------------------------+----++-----+-------------++--------------++-------------++-----------+---+---\n"}
		elsif ( $cumHours > 12 and $myModel eq "gfs3" ) { $cumHours = 1 ;
		    print "----------------------------------------------+----++-----+-------------++--------------++-------------++-----------+---+---\n"}
       write }}                                 # Standard output
   else { 
	   if ( $myModel eq "gfs3") { $i = $statime / 3 } else { $i = $statime }
       $snRatio[$i] = 0.0 ;
       $Ptype[$i] = GetPrecipType() ;           # Determine precipitation type.
	   GetSnow();
       if ($Ptype[$i] eq " SNOW " ) {             # If precipitation type is snow, calculate snowfall.
          $snRatio[$i] *= $SRpercent[$i] }
        else                     {
          $snRatio[$i] = 0.0 }
#       $cumPrecip += $precip[$i] ;
#       $cumSnowFall += $snowFall[$i] ;
       $= = ($#{$pres[$i]} + 6);
       for ($j = $#{$pres[$i]}; $j >=0; $j--) { write; }

	   $ps = sprintf "%5.1f", $posEnergySfc[$i] ;
	   $pa = sprintf "%5.1f", $posEnergyAlft[$i] ;
	   $pt = sprintf "%5.1f", $posEnergy[$i] ;
       $n1 = sprintf "%5.1f", $negEnergy1[$i] ;
       $n2 = sprintf "%5.1f", $negEnergy2[$i] ;
       print "----------------------------------------------------------------------------------------------------------------------------\n";
       print "Sounding type is: $pClass[$i]\n";
	   if ( $posEnergy[$i] > 0.0 ) {
	     print "Surface Based Positive Energy equaled: $ps J/kg \n";
         print "Positive Energy Aloft equaled:         $pa J/kg \n";
         print "Total Positive Energy equaled:         $pt J/kg \n\n";
	     if ($posEnergyAlft[$i] > 0.0 ) {
           print "Negative Energy wrt 0C:      $n1 J/kg \n";
           print "Negative Energy wrt -6C:     $n2 J/kg \n\n";
	   } }
       $srp = sprintf "%3.2f", $SRpercent[$i]; $irp = sprintf "%3.2f", $IRpercent[$i];$rrp = sprintf "%3.2f", $RRpercent[$i];
	   print "Ratio of snow/sleet/water = $srp/$irp/$rrp\n";
	   $snr = sprintf "%3.1f", $snRatio[$i] ;
	   print "The snowratio for the above profile was: $snr, based on a ptype of $Ptype[$i].\n" ;
  }

  print "============================================================================================================================\n\n";
  GETSTATION: exit if $mode eq "AUTO" ;
  print "Please enter stn ID or <exit> :  " ;
  @myinput = split(/ /,<STDIN>) ;
  $myStation = $myinput[0] ;
  $statime = $myinput[1] ;
  chomp($myStation) ;
  chomp($statime) ;
#  if ($statime eq "")  { STDOUT->format_name("VER50"); STDOUT->format_top_name("VER50_TOP")}
  if ($statime eq "")  { STDOUT->format_name("VER55"); STDOUT->format_top_name("VER55_TOP")}
   else                { STDOUT->format_name("DIAG"); STDOUT->format_top_name("DIAG_TOP")}

  ### Check to see user wants to select a different option (model or shift temp/dwpt profile. ###
  if     ($myStation eq "eta" )                        {$myModel = "eta"  ; print "Model now $myModel.\n" ;  goto GETSTATION}
   elsif ($myStation eq "etam")                        {$myModel = "etam"  ; print "Model now $myModel.\n" ;  goto GETSTATION}
   elsif ($myStation eq "nam")                         {$myModel = "nam"  ; print "Model now $myModel.\n" ;  goto GETSTATION}
   elsif ($myStation eq "nmm" )                        {$myModel = "nmm" ; print "Model now $myModel.\n" ;  goto GETSTATION}
   elsif ($myStation eq "arw" )                        {$myModel = "arw" ; print "Model now $myModel.\n" ;  goto GETSTATION}
   elsif ($myStation eq "ruc" )                        {$myModel = "ruc" ; print "Model now $myModel.\n" ;  goto GETSTATION}
   elsif ($myStation eq "etaw")                        {$myModel = "etaw" ; print "Model now $myModel.\n" ;  goto GETSTATION}
   elsif ($myStation eq "gfs" or $myStation eq "gfs3") {$myModel = "gfs3" ; print "Model now $myModel.\n" ;  goto GETSTATION}
   elsif ($myStation eq "profile" )                    {chomp ($thermalShift = $myinput[1]) ; print "Thermal Shift now $thermalShift degree(s) \n\n" ; goto GETSTATION }
   elsif ($myStation eq "rh" )                         {chomp ($RHThresh = $myinput[1]) ; print "Cloud RH threshold now set at $RHThresh% \n\n" ; goto GETSTATION }
   elsif ($myStation eq "vvS" or $myStation eq "vvs")  {chomp ($vvShift = $myinput[1] ) ; print "Vertical motion shift is now $vvShift\n\n" ; goto GETSTATION }
   elsif ($myStation eq "vvF" or $myStation eq "vvf")  {chomp ($vvFactor = $myinput[1]) ;
                                                         if ($vvFactor < 0.5 ) { $vvFactor = 0.5 } elsif ($vvFactor > 2.0) { $vvFactor = 2.0 }
														print "Vertical motion factor now $vvFactor\n\n" ; goto GETSTATION }
   elsif ($myStation eq "help" )                       {print "\n-----Command Listing-----\n";
                                                        print ">change model - type one of these: eta, etam, nam, gfs, etaw, nmm, arw\n";
													    print ">shift thermal profile: profile #.#  (profile -2.0)\n";
														print ">Change Cloud RH threshold:  rh ##  (rh 90)\n" ;
														print ">See Diagnosis for a certain forecast hour:  STN  ##  (KGRR 9)\n\n" ;
													    goto GETSTATION } 
  print "\n" ;
}

format NORMAL_TOP =
StnID: @<<<    Profile Thermal Adjust: @#.#       Cloud RH threshold: @##%
       $myStation,                      $thermalShift,                   $RHThresh

 Date/hour    FcstHR   Wind     SfcT  Liquid  SR   Snow    ICE    CumLiq  CumSnR  CumSnw   CumIce  Ptype  Profile
==================================================================================================================
.
format NORMAL = 
 @<<<<<<<<<<Z  @##    @<@<<KT @###F  @#.##"  @##:1 @##.#"  @#.##" @##.##"  @##:1   @##.#"   @#.##"  @<<<<   @<<<<
$dateTime[$i], $fcstHR[$i], $sfcWindDir[$i], $sfcWindSpd[$i], $temp2meter[$i], $precip[$i], $snRatio[$i], $snowFall[$i], $iceFall[$i], $cumPrecip, $cumSR, $cumSnowFall, $cumIce, $Ptype[$i], $pClass[$i]
.

format DIAG_TOP =
  Station: @<<<  DiagTime: F+@||HR  Profile Thermal Adjust: @#.#  Cloud RH threshold: @##%
           $myStation,            $statime,                    $thermalShift,               $RHThresh

                                                                                 Warm  Cold1 Cold2 
   Pres    T(C)| Tw  |  Td      LR |RHw|RHi|  Uvv      SRt| Wuvv|| SRw |  SR      >0C | <0C | <-6C   WgtSum
==================================================================================================================
.
format DIAG = 
@####MB   @##.#|@##.#|@##.#  @###.#|@##|@##|@##.#     @#:1|@#.##||@#.##| @#.#    @##.#|@##.#|@##.#   @##.#
$lyrPres[$i][$j], $lyrTemp[$i][$j], $lyrTmwc[$i][$j], $lyrDwpc[$i][$j], $lyrLapse[$i][$j], $lyrRH[$i][$j], $lyrRHice[$i][$j], $lyrOmega[$i][$j], $layerSR[$j], $percentArea[$i][$j], $percentSR[$i][$j], $cumPercentSR[$i][$j], $lyrPosEnergy[$i][$j], $lyrNegEnergy1[$i][$j], $lyrNegEnergy2[$i][$j], $wgtSum[$i][$j]
.

format VER4_TOP =
StnID: @<<<    Profile Thermal Adjust: @#.#       Cloud RH threshold: @##%    Average Hourly Sounding: @<<<
       $myStation,                      $thermalShift,                   $RHThresh,         $avgHour

 Date/hour    FHr  Wind   SfcT  Ptype   SR |Snow||CumSR|TotS     IR| ICE |TotI     QPF | Tqpf  SndgType   S%| I%| R%
=====================================================================================================================
.
format VER4 = 
@<<<<<<<<<<Z @##  @<@<<KT @##F @<<<<< @##:1|@#.#||@##:1|@#.#  @##:1|@#.##|@.##   @#.###|@#.##    @<<<<<  @##|@##|@##
$dateTime[$i], $fcstHR[$i], $sfcWindDir[$i], $sfcWindSpd[$i], $temp2meter[$i], $Ptype[$i], $snRatio[$i], $snowFall[$i], $cumSR, $cumSnow, $iceRatio[$i], $iceFall[$i], $cumIce,  $precip[$i], $cumPrecip, $pClass[$i], $SRpercent[$i]*100., $IRpercent[$i]*100., $RRpercent[$i]*100.
.
format VER50_TOP =
StnID: @<<<    Profile Thermal Adjust: @#.#       Cloud RH threshold: @##%    Average Hourly Sounding: @<<<
       $myStation,                      $thermalShift,                   $RHThresh,         $avgHour

 Date/hour    FHr  Wind    SfcT   Ptype   SR |Snow||Sleet|| FZRA|| QPF    CumSR|TotSN||TotPL||TotZR|| TQPF   S%| I%| L% 
============================================================================================================================
.
format VER50 = 
@<<<<<<<<<<Z @##  @<@<<KT @##.#F @<<<<< @##:1|@#.#||@#.##||@#.##||@#.###  @##:1| @#.#||@#.##||@#.##||@#.##  @##|@##|@## 
$dateTime[$i], $fcstHR[$i], $sfcWindDir[$i], $sfcWindSpd[$i], $temp2meter[$i], $Ptype[$i], $snRatio[$i], $snowFall[$i], $sleetFall[$i], $iceFall[$i], $precip[$i], $cumSR, $cumSnow, $cumSleet, $cumIce, $cumPrecip, $SRpercent[$i]*100., $IRpercent[$i]*100., $RRpercent[$i]*100. 
.
format VER55_TOP =
StnID: @<<<   Model: @<<<   Run: 20@<<<<<<<<<<    Cloud RH threshold: @##%    Sleet Ratio: 2:1   || CarSnowTool Ops 5.5
       $myStation,    $myModel,      $dateTime[0]  ,                     $RHThresh

 Date/hour    FHr  Wind    SfcT   Ptype   SRat|Snow||CumSR|TotSN    QPF ||TotQPF   Sleet||TotPL    FZRA||TotZR    S%| I%| L%
============================================================================================================================
.
format VER55 =
@<<<<<<<<<<Z @##  @<@<<KT @##.#F @<<<<<  @##:1|@#.#||@##:1|@#.#   @#.###||@#.##    @#.##||@#.##   @#.##||@#.##   @##|@##|@##
$dateTime[$i], $fcstHR[$i], $sfcWindDir[$i], $sfcWindSpd[$i], $temp2meter[$i], $Ptype[$i], $snRatio[$i], $snowFall[$i], $cumSR, $cumSnow, $precip[$i], $cumPrecip, $sleetFall[$i], $cumSleet, $iceFall[$i], $cumIce, $SRpercent[$i]*100., $IRpercent[$i]*100., $RRpercent[$i]*100.
.
format VER55Web_TOP =
StnID: @<<<   Model: @<<<   Run: 20@<<<<<<<<<<    Cloud RH threshold: @##%    Sleet Ratio: 2:1   || CarSnowTool Ops 5.5
       $myStation,    $myModel,      $dateTime[0],                       $RHThresh

 Date/hour    FHr  Wind    SfcT   Ptype   SRat|Snow||TotSN    QPF ||TotQPF   Sleet||TotPL    FZRA||TotZR    S%| I%| L%
========================================================================================================================
.
format VER55Web =
@<<<<<<<<<<Z @##  @<@<<KT @##.#F @<<<<<  @##:1|@#.#||@#.#   @#.###||@#.##    @#.##||@#.##   @#.##||@#.##   @##|@##|@##
$dateTime[$i], $fcstHR[$i], $sfcWindDir[$i], $sfcWindSpd[$i], $temp2meter[$i], $Ptype[$i], $snRatio[$i], $snowFall[$i], $cumSnow, $precip[$i], $cumPrecip, $sleetFall[$i], $cumSleet, $iceFall[$i], $cumIce, $SRpercent[$i]*100., $IRpercent[$i]*100., $RRpercent[$i]*100.
.



#### End Main ##############

#### Read in Bufkit data for Eta or Workstation Eta ASCII Bufkit Files ###
sub ReadEtaBufkit {

 my $i=0 ; 
 my $j=0 ;
 my $k=0 ;
 $stationID = 999999 ;

 while (<BUFIN>) {

   ### This section reads in the bufkit header information that precedes each forecast hour. ###
   if ( $_ =~ /^STID\b/){ 
     @stationData = split(/ /,$_);
     chomp($stationID = $stationData[5]);
     chomp($dateTime[$i] = $stationData[8]);
     chomp($data = <BUFIN>);  
     @stationData = split(/ /,$data);
     chomp($hght[$i][0] = $stationData[8]);
     chomp($data = <BUFIN>);     
     @stationData = split(/ /,$data);
     chomp($fcstHR[$i] = $stationData[2]);
   } 

   ### This section reads in sounding level data for each forecast hour. ###
   if ( $_ =~ /^CFRL\b/) {
     $j=1;
     chomp($data = <BUFIN>);     
     #while ( $data ne "" and $data !~ /^STN\b/) {            # Use this line on Windows OP
     while ( $data ne "\r" and $data !~ /^STN\b/) {          # Use this line on Linux
       ($pres[$i][$j], $tmpc[$i][$j], $tmwc[$i][$j], $dwpc[$i][$j], $thte[$i][$j], $drct[$i][$j], $sknt[$i][$j], 
             $omega) = split(/ /,$data);
       chomp($data = <BUFIN>);     
       ($cfrl[$i][$j], $hght[$i][$j]) = split(/ /,$data); 
       
       # pres - pressure (mb), tmpc - temperature (C), dwpc - dewpoint (C), tmwc - wetbulb (C), thte - equiv potential temp (C),
       # drct - wind direction, sknt - windspeed (kt), oemga - upward vertical motion (microbars/s), cfrl - Cloud Fraction (%), 
       # hght - geopotential height (m). 
       
       if ($dwpc[$i][$j] == -9999.00 ) { $dwpc[$i][$j] = $tmpc[$i][$j] - 30.0 }         # Set dewpoint depression to 30 if missing.
       if ($tmwc[$i][$j] == -9999.00 and $pres[$i][$j] > 100.0 ) { $tmwc[$i][$j] = GetWetBulbTemp($i, $j) }  # Calculate wetbulb if missing. 
       $tmpc[$i][$j] += $thermalShift ; $dwpc[$i][$j] += $thermalShift ; $tmwc[$i][$j] += $thermalShift ;  #User option to warm or cool entire sounding
       chomp($data = <BUFIN>);

	   if ($omega > 0.0 ) {$omeg[$i][$j] = 10 *( $omega ** $vvFactor ) + $vvShift }
	    else              {$omeg[$i][$j] =  ( -10.0 * (( -1.0 * $omega) ** $vvFactor )) + $vvShift }

#print "$i,  $j,  $pres[$i][$j], $tmpc[$i][$j], $tmwc[$i][$j], $dwpc[$i][$j] \n" ;
       $j++;     
     }
   $i++;  
   }

   ### This section reads in surface and other miscellaneous data for each forecast sounding. ###         
   if ($_ =~ /^$stationID\b/) {
#     print "$_\n";
     @sfcData = split(/ /,$_); chomp($pres[$k][0] = $sfcData[3]);
     chomp($data = <BUFIN>); @sfcData = split(/ /,$data); 
       chomp($precip[$k] = $sfcData[0]);
       if ($precip[$k] == -9999.00 ) { $precip[$k] = 0.00 }
       $precip[$k] /= 25.4 ;
       if ( $precip[$k] < 0.003 ) { $precip[$k] = 0.00 }
     chomp($data = <BUFIN>); @sfcData = split(/ /,$data); 
	   chomp($uWnd = $sfcData[1]); chomp($vWnd = $sfcData[2]) ;       
       chomp($temp2meter[$k] = ($sfcData[5] + $thermalShift) * 9/5 + 32.0);
        ($sfcWindSpd[$k], $sfcWindDir[$k]) = GetWndDirSpd() ; 
        $drct[$k][0] = $sfcWindDir[$k];
		$sknt[$k][0] = $sfcWindSpd[$k];
       chomp($tmpc[$k][0] = $sfcData[5] + $thermalShift );
     chomp($data = <BUFIN>); chomp($data = <BUFIN>); chomp($data = <BUFIN>); @sfcData = split(/ /,$data); 
	   chomp($dwpc[$k][0] = $sfcData[0] + $thermalShift );
#     if ($dwpc[$k][0] > $tmpc[$k][0]) {$dwpc[$k][0] = $tmpc[$k][0] ; $tmwc[$k][0] = $tmpc[$k][0]}
#	  else { $tmwc[$k][0] = GetWetBulbTemp($k, 0)}
     $tmwc[$k][0] = $tmpc[$k][0] ;
	 $thte[$k][0] = 0.0; # variable not used
	 $omeg[$k][0] = 0.0;
	 $cfrl[$k][0] = 0.0; # variable not used
     $k++;    
   }
 }
}  ### End ReadEtaBufkit ###


#### Read in Bufkit data for GFS3 ASCII Bufkit Files ###
sub ReadGFSBufkit {

 my $i=0 ; 
 my $j=0 ;
 my $k=0 ;
 $stationID = 999999 ;
   
 while (<BUFIN>) {
   ### This section reads in the bufkit header information that precedes each forecast hour. ###
   if ( $_ =~ /^STID\b/){
     @stationData = split(/ /,$_);
	 chomp($checkforId = $stationData[2]); 
	 if ( $checkforId eq "STNM") 
		{ chomp($stationID = $stationData[4]); chomp($dateTime[$i] = $stationData[7])}
      else
		{ chomp($stationID = $stationData[5]); chomp($dateTime[$i] = $stationData[8])}
	 chomp($data = <BUFIN>);     
     @stationData = split(/ /,$data);
     chomp($hght[$i][0] = $stationData[8]);
     chomp($data = <BUFIN>);     
     @stationData = split(/ /,$data);
     chomp($fcstHR[$i] = $stationData[2]);
   }

   ### This section reads in sounding level data for each forecast hour. ###
   if ( $_ =~ /^HGHT\b/) {
     $j=0;
     chomp($data = <BUFIN>);     
     #while ( $data ne "" and $data !~ /^STN\b/) {      # Use this line on Windows OP
     while ( $data ne "\r" and $data !~ /^STN\b/) {   # Use this line on Linux OP
       ($pres[$i][$j], $tmpc[$i][$j], $tmwc[$i][$j], $dwpc[$i][$j], $thte[$i][$j], $drct[$i][$j], $sknt[$i][$j], 
             $omega) = split(/ /,$data);
       chomp($data = <BUFIN>);      
       $hght[$i][$j] = $data;

       # pres - pressure (mb), tmpc - temperature (C), dwpc - dewpoint (C), tmwc - wetbulb (C), thte - equiv potential temp (C),
       # drct - wind direction, sknt - windspeed (kt), oemga - upward vertical motion (microbars/s), hght - geopotential height (m). 

       if ($dwpc[$i][$j] == -9999.00 ) { $dwpc[$i][$j] = $tmpc[$i][$j] - 30.0 }         # Set dewpoint depression to 30 if missing.
       if ($tmwc[$i][$j] == -9999.00 and $pres[$i][$j] > 100.0) { $tmwc[$i][$j] = GetWetBulbTemp($i, $j) }  # Calculate wetbulb if missing. 
       $tmpc[$i][$j] += $thermalShift ; $dwpc[$i][$j] += $thermalShift ; $tmwc[$i][$j] += $thermalShift ;  #User option to warm or cool entire sounding

       chomp($data = <BUFIN>);

	   if ($omega > 0.0 ) {$omeg[$i][$j] = 10 *( $omega ** $vvFactor ) + $vvShift }
	    else              {$omeg[$i][$j] =  ( -10.0 * (( -1.0 * $omega) ** $vvFactor )) + $vvShift }

#print "$i,  $j,  $pres[$i][$j], $tmpc[$i][$j], $tmwc[$i][$j], $dwpc[$i][$j] \n" ;
       $j++;     
     }
     $i++;
   }
 
   ### This section reads in surface and other miscellaneous data for each forecast sounding. ###         
   if ($_ =~ /^$stationID\b/) {
     @sfcData = split(/ /,$_);
	   chomp($pres[$k][0] = $sfcData[3]);
	   chomp($precip[$k] = $sfcData[7]);
       if ($precip[$k] == -9999.00 ) { $precip[$k] = 0.000 }
       $precip[$k] = $precip[$k] / 25.4;
       if ( $precip[$k] < 0.006 ) { $precip[$k] = 0.00 }
     chomp($data = <BUFIN>); @sfcData = split(/ /,$data);
       chomp($uWnd = $sfcData[5]);          
     chomp($data = <BUFIN>); @sfcData = split(/ /,$data);
       chomp($vWnd = $sfcData[0]);       
       chomp($temp2meter[$k] = ($sfcData[1] + $thermalShift) * 9/5 + 32.0);
       chomp($tmpc[$k][0] = $sfcData[1] + $thermalShift );
     chomp($data = <BUFIN>); @sfcData = split(/ /,$data);
       chomp($dwpc[$k][0] = $sfcData[2] + $thermalShift );
     ($sfcWindSpd[$k], $sfcWindDir[$k]) = GetWndDirSpd() ;
	    $drct[$k][0] = $sfcWindDir[$k];
		$sknt[$k][0] = $sfcWindSpd[$k];
#	 if ($dwpc[$k][0] > $tmpc[$k][0]) {$dwpc[$k][0] = $tmpc[$k][0] ; $tmwc[$k][0] = $tmpc[$k][0]}
#	  else { $tmwc[$k][0] = GetWetBulbTemp($k, 0)}
     $tmwc[$k][0] = $tmpc[$k][0] ;
	 $thte[$k][0] = 0.0; # variable not used
	 $omeg[$k][0] = 0.0;
     $k++;    
   }
 }
}  ### End ReadGFSBufkit ###


### Calculate wind speed and direction from u an v components and save in METAR format ###
  # This subroutine is called from the GetBufkit subroutines
sub GetWndDirSpd {
    my $wndSpd ;
    my $wndDir ;

    $wndSpd = 1.9425 * sqrt(($uWnd * $uWnd) + ($vWnd*$vWnd)) + 0.5; 
    if ($wndSpd < 3.0) {$wndSpd = "B0"."$wndSpd";  $wndDir = "VRB" }
     elsif ($wndSpd >= 3.0 and $wndSpd < 10)   {$wndSpd = "00"."$wndSpd"}
     elsif ($wndSpd >= 10.0 and $wndSpd < 100) {$wndSpd = "0"."$wndSpd" }
    if ($wndDir ne "VRB") { 
      if (abs($uWnd) > 0.01) {$wndDir = 185 + (57.3 * atan2($uWnd,$vWnd))}
       elsif ($uWnd == 0.0 and $vWnd < 0.01) {$wndDir = 360}
       elsif ($uWnd == 0.0 and $vWnd > 0.01) {$wndDir = 180}
      if ($wndDir > 360 ) { $wndDir -= 360 }
      if ($wndDir < 10 ) {
         $wndDir = "0"."$wndDir";
         if ($wndDir < 10) { $wndDir = 360 }}
       elsif ($wndDir < 100 ) {$wndDir = "0"."$wndDir"}
    }
    return ($wndSpd, $wndDir);
}

### Calculate layer means for several variables
sub GetLyrMeans {
  $maxCloudLyrOmega[$i] = -0.1 ;
  my $j;
  for ($j = ($#{$pres[$i]}-1); $j >=1; $j--) { 
     $lyrRH[$i][$j] = ($rh[$i][$j]);
     $lyrRHice[$i][$j] = ($rhi[$i][$j]);
     $lyrDwpc[$i][$j] = ($dwpc[$i][$j]);
     $lyrTmwc[$i][$j] = ($tmwc[$i][$j]);
     $lyrTemp[$i][$j] = ($tmpc[$i][$j]);
     $lyrPres[$i][$j] = ($pres[$i][$j]);
     $lyrThick[$i][$j] = ($hght[$i][$j+1] - $hght[$i][$j-1])/2.0;
     $lyrOmega[$i][$j] = (($omeg[$i][$j+1] + $omeg[$i][$j] + $omeg[$i][$j-1])/ 3.0);
     $lyrLapse[$i][$j] = ($tmpc[$i][$j-1] - $tmpc[$i][$j+1])/($hght[$i][$j+1] - $hght[$i][$j-1]) * 1000.;
    if ($lyrOmega[$i][$j] < $maxCloudLyrOmega[$i] and $lyrRH[$i][$j] >= $RHThresh) {$maxCloudLyrOmega[$i] = $lyrOmega[$i][$j]}  # "max" in term of the greatest upward vertical motion (negative omega).

  #print "$i, $j, $lyrRH[$i][$j],  $lyrRHice[$i][$j],  $lyrTmwc[$i][$j],  $lyrTemp[$i][$j],  $lyrPres[$i][$j],  $lyrThick[$i][$j],  $lyrOmega[$i][$j]\n";
  }
  $lyrRH[$i][0] = $rh[$i][0]; $lyrRHice[$i][0] = $rhi[$i][0]; $lyrDwpc[$i][0] = ($dwpc[$i][0]); $lyrTmwc[$i][0] = ($tmwc[$i][0]); $lyrTemp[$i][0] = ($tmpc[$i][0]);
  $lyrPres[$i][0] = ($pres[$i][0]); $lyrOmega[$i][0] = 0.0; 
  $lyrThick[$i][0] = $hght[$i][$j+1] - $hght[$i][$j];
  if ( $lyrThick[$i][0] > 0.0 ) {$lyrLapse[$i][0] = ($tmpc[$i][$j] - $tmpc[$i][$j+1])/$lyrThick[$i][0] * 1000.}
   else                         {$lyrLapse[$i][0] = 6.5}
#print "$i,  $maxCloudLyrOmega[$i]\n"
}  ### End GetLyrMeans


### Calculate RH at each level with respect to water and ice. #####
sub GetRH {
  my $j;
  my $tmpv ;
  my $dwpv ;
  my $tfvp ; 
  for($j = $#{$pres[$i]}; $j >=0; $j--) { 
     if ($dwpc[$i][$j] == -9999.00 ) { $dwpc[$i][$j] = $tmpc[$i][$j] - 30.0 }
     $tmvp = 10*exp((16.78 * $tmpc[$i][$j] - 116.9)/($tmpc[$i][$j] + 237.3));         # Saturation Vapor Pressure wrt water
     $dwvp = 10*exp((16.78 * $dwpc[$i][$j] - 116.9)/($dwpc[$i][$j] + 237.3));         # Vapor Pressure wrt water
     $rh[$i][$j] = 100 * $dwvp/$tmvp ;                                                # Relative Humidity wrt water
       
     $tfvp = exp(10.55 * ln(10) - (2667 * ln(10)) / ($tmpc[$i][$j] + 273.15)) ;       # Saturation Vapor Pressure wrt ice
     $rhi[$i][$j] = 100 * $dwvp/$tfvp ;                                               # Relative Humidity wrt ice
  }
}  ### End GetRH ###


### Calculate wetbulb wrt to water if "tmwc" variable missing in bufkit file...uses iterative bisection method to solve.
  # This function is called from GetBufkit subs...
sub GetWetBulbTemp {
  my ($i, $j) = @_ ;
  my $tw = 0.0 ;                                                                  # wetbulb temperature
  my $dwvp = 10*exp((16.78 * $dwpc[$i][$j] - 116.9)/($dwpc[$i][$j] + 237.3));     # Vapor Pressure wrt water
  my $mixr = 0.6214 * $dwvp/($pres[$i][$j]-$dwvp);                                # mixing ratio
  my $uL = $tmpc[$i][$j] ;                                                        # upper bound - temperature
  my $lL = $tmpc[$i][$j] - 30.0 ;                                                 # lower bound - dewpoint
  my $k = 0 ;                                                                     # generic counter
  my $diff = 10.0 ;
#print " $i, $j, $uL, $lL\n" ;  

  while ( abs($diff) > 0.1 ) {                                                    # Bisection - itteration to conv on answer
    $tw = ($uL + $lL)/2.0 ;
    $vp = 10*exp((16.78 * $tw - 116.9)/($tw + 237.3));                            # vapor pressure
    $mixtw = 0.6214 * $vp/($pres[$i][$j] - $vp);                                  # mixing ratio of wetbulb temp
    $diff = 1004.0 * ( $tw - $tmpc[$i][$j] ) + 25000000.0 * ( $mixtw - $mixr );
    if ( $diff < 0.1 ) {
     $lL = $tw ;
    }else{
     $uL = $tw ;
    }
#print " $i, $j, $uL, $lL, $diff\n" ;  
    $k ++ ;  
  }  
  return($tw);
}  ### End GetWetBulbTemp

### Calculate precipitation type using combo of approaches including "Top Down", "Bourgoin", and "Ramer".
sub GetPrecipType {
 my $j = 0 ;
 my $ptype = "   UP " ;
 my $warm = "NO";
 my $ice = "NO";
 my $warmPresMin = 9999;
 $posEnergy[$i] = 0;
 $posEnergySfc[$i] = 0;
 $posEnergyAlft[$i] = 0;
 $negEnergy1[$i] = 0;
 $negEnergy2[$i] = 0;
 $pClass[$i] = "9.9.9";

 ### Look for probable ice in cloud with upward vertical motion (i.e. Top Down Approach) - if yes, then set ptype as snow for now.
 for($j = $#{$pres[$i]}; $j >=0; $j--) { 
    if ($pres[$i][$j] > 300.0 ) {
      if ( $lyrTemp[$i][$j] < -8.0 and $lyrRHice[$i][$j] > $RHThresh ) { $ptype = "  ICE " }
    } 
 }

 ### If snow is a possibility, use area method (i.e. Bourgouin Method) to evaluate warm and cold layers. Calculate area of wetbulb
   # wrt water above 0C to evaluate warm area (i.e. Ramer or Baldwin).  Calculate area of cold layer below 0C for sleet from partially
   # melted snowflakes and -8C for formation of ice pellets from rain (i.e. Bourgouin and Top Down).
# if ($ptype ne "RAIN" ) {
  
   for($j = $#{$pres[$i]}; $j >=0; $j--) { 
     if ($pres[$i][$j] > 100.0 ) {       # This logic works only in top-down sense...
       if ((0.67 * $lyrTmwc[$i][$j] + 0.33 * $lyrTemp[$i][$j]) > 0.00 ) { 
         if ($warm eq "NO" ) { $warmPresMin = $pres[$i][$j] ; $warm = "YES" }
         $lyrPosEnergy[$i][$j] = abs(9.80655 * ((0.67 * $lyrTmwc[$i][$j] + 0.33 * $lyrTemp[$i][$j]) / 273.0) * $lyrThick[$i][$j]) ;    # Calculate amount of warm energy (area above freezing)
         $posEnergy[$i] += $lyrPosEnergy[$i][$j] }                                                                                     # sums this area over each layer.
       else                         {
         $lyrPosEnergy[$i][$j] = 0.0}
     }
     if ($pres[$i][$j] > $warmPresMin and $lyrTemp[$i][$j] < 0.00 ) {         
       $lyrNegEnergy1[$i][$j] = abs(9.80655 * ($lyrTemp[$i][$j] / 273.0) * $lyrThick[$i][$j]) ;  # Calculate amount of cold energy below warm layer (area below freezing).
       $negEnergy1[$i] += $lyrNegEnergy1[$i][$j]                   }                                   # Sum this area over each layer.
     else                                                          {
       $lyrNegEnergy1[$i][$j] = 0.0                                }

#     if ($pres[$i][$j] > $warmPresMin and $lyrTemp[$i][$j] < -3.0 ){ 
#       $lyrNegEnergy2[$i][$j] = -9.80655 * (($lyrTemp[$i][$j] + 3.0 ) / 270.0) * $lyrThick[$i][$j] ;     # Calculate freezing energy below warm layer (area below -8 C to (re)introduce ice).  
#       $negEnergy2[$i] += $lyrNegEnergy2[$i][$j]                   }                                     # Sum this area over each layer.
#     else                                                          {
#       $lyrNegEnergy2[$i][$j] = 0.0                                }

     if ($pres[$i][$j] > $warmPresMin and $lyrTemp[$i][$j] < -6.0 ){ 
       $lyrNegEnergy2[$i][$j] = abs(9.80655 * (($lyrTemp[$i][$j] + 6.0 ) / 267.0) * $lyrThick[$i][$j]) ;  # Calculate freezing energy below warm layer (area below -8 C to (re)introduce ice).  
       $negEnergy2[$i] += $lyrNegEnergy2[$i][$j]                   }                                            # Sum this area over each layer.
     else                                                          {
       $lyrNegEnergy2[$i][$j] = 0.0                                }

#     if ($pres[$i][$j] > $warmPresMin and $lyrTemp[$i][$j] < -9.0 ){ 
#       $lyrNegEnergy2[$i][$j] = -9.80655 * (($lyrTemp[$i][$j] + 9.0 ) / 264.0) * $lyrThick[$i][$j] ;     # Calculate freezing energy below warm layer (area below -8 C to (re)introduce ice).  
#       $negEnergy2[$i] += $lyrNegEnergy2[$i][$j]                   }                                     # Sum this area over each layer.
#     else                                                          {
#       $lyrNegEnergy2[$i][$j] = 0.0                                }

#     if ($pres[$i][$j] > $warmPresMin and $lyrTemp[$i][$j] < -12.0 ){ 
#       $lyrNegEnergy2[$i][$j] = -9.80655 * (($lyrTemp[$i][$j] + 12.0 ) / 261.0) * $lyrThick[$i][$j] ;    # Calculate freezing energy below warm layer (area below -8 C to (re)introduce ice).  
#       $negEnergy2[$i] += $lyrNegEnergy2[$i][$j]                   }                                     # Sum this area over each layer.
#     else                                                          {
#       $lyrNegEnergy2[$i][$j] = 0.0                                }

#     if ($pres[$i][$j] > $warmPresMin and $lyrTemp[$i][$j] < -15.0 ){ 
#       $lyrNegEnergy2[$i][$j] = -9.80655 * (($lyrTemp[$i][$j] + 15.0 ) / 258.0) * $lyrThick[$i][$j] ;    # Calculate freezing energy below warm layer (area below -8 C to (re)introduce ice).  
#       $negEnergy2[$i] += $lyrNegEnergy2[$i][$j]                   }                                     # Sum this area over each layer.
#     else                                                          {
#       $lyrNegEnergy2[$i][$j] = 0.0                                }
   }

   $j = 0;
   while ((0.67 * $lyrTmwc[$i][$j] + 0.33 * $lyrTemp[$i][$j]) > 0.00 and $pres[$i][$j] > $warmPresMin ) {
      $posEnergySfc[$i] += abs(9.80655 * ((0.67 * $lyrTmwc[$i][$j] + 0.33 * $lyrTemp[$i][$j]) / 273.0) * $lyrThick[$i][$j]) ; 
      $j++;
   }
   if ($posEnergySfc[$i] < 0.1 ) { $posEnergySfc[$i] = 0.0 }
   $posEnergyAlft[$i] = $posEnergy[$i] - $posEnergySfc[$i];
   
#print " $i  wetbulb = $lyrTmwc[$i][1]\n";

   ### Consider four generic cases: 1) - Entire sounding below freezing, 2) - Surface based warm layer, 3) - Elevated warm layer(s), 
     #                              and 4) - Both elevated and surface warm layers.
   
   ### Case 1: Entire Sounding Below Freezing - SNOW or FZDZ ( posEnergy = 0 )
   if ($posEnergy[$i] < 0.1 ) { 
	   $pClass[$i] = "1.9.9";
     if ($precip[$i] < 0.001 ) { $pClass[$i] = "1.0.0"; $ptype = "    " ; goto EndPtype }
     if ( $ptype eq "  ICE " ){ 
        $SRpercent[$i] = 1.0; $IRpercent[$i] = 0.0; $RRpercent[$i] = 0.0;
		$pClass[$i] = "1.1.1"; $ptype = " SNOW " }
     elsif ( $ptype eq "   UP " ) {  # If UP then no ice in cloud and snow not a possiblity. This is the supercooled freezing precip scenario.
        if ($maxCloudLyrOmega[$i] < -10.0 ) {
           $SRpercent[$i] = 0.0; $IRpercent[$i] = 0.0; $RRpercent[$i] = 1.0;
		   $pClass[$i] = "1.2.1"; $ptype = " FZRA " } #If no ice in cloud but strong upward motion then FZRA.
        else {
           $SRpercent[$i] = 0.0; $IRpercent[$i] = 0.0; $RRpercent[$i] = 1.0;
		   $pClass[$i] = "1.2.2"; $ptype = " FZDZ " } #If no ice and weak upward motion then FZDZ. 
	 } #close ptype  
   } #close posEnergy
   
   ### Case 2: Sufaced based warm layer - SNOW, RASN, RAIN, DRIZZLE ( posEnergy = posEnergySfc )
   elsif ( $posEnergyAlft[$i] < 0.1  and  $lyrTmwc[$i][1] > 0.0) { 
     $pClass[$i] = "2.9.9";
     if ($precip[$i] < 0.001 ) { $pClass[$i] = "2.0.0"; $ptype = "    " ; goto EndPtype }
     if ( $ptype eq "  ICE " ){
        if ( $posEnergySfc[$i] <= 15.0 ) { 
           $SRpercent[$i] = 1.0 - ($posEnergySfc[$i]/15.0)**0.5; $IRpercent[$i] = 0.0; $RRpercent[$i] = 1.0 - $SRpercent[$i]}
         else {
		   $SRpercent[$i] = 0.0; $IRpercent[$i] = 0.0; $RRpercent[$i] = 1.0}
        if     ( $SRpercent[$i] >  0.79 ) { $pClass[$i] = "2.1.1"; $ptype = " SNOW " } # 
		 elsif ( $SRpercent[$i] >  0.19 ) { $pClass[$i] = "2.1.2"; $ptype = " RASN " } # 
		 else                             { $pClass[$i] = "2.1.3"; $ptype = " RAIN " }
     }
     elsif ( $ptype eq "   UP " ) {
        $SRpercent[$i] = 0.0; $IRpercent[$i] = 0.0; $RRpercent[$i] = 1.0;
        if ($maxCloudLyrOmega[$i] > -10.0 ) { $pClass[$i] = "2.2.1"; $ptype = "   DZ "} #If no ice in cloud but weak upward motion then Drizzle.
        else                                { $pClass[$i] = "2.2.2"; $ptype = " RAIN "} #If no ice and strong upward motion then Rain. 
	 }	
   }
  
   ### Case 3: Elevated warm layer - SNOW, SNPL, SNZR, PL, ZRPL, FZRA, FZDZ ( posEnergy > 0 and posEnergySfc = 0 )
     # Note: two-meter temperatures can be at or slightly above freezing allowing for RAIN vs FZRA as a possibility.
   elsif ( $posEnergySfc[$i] < 0.1  and  $temp2meter[$i] < 32.1) { 
   #elsif ( $temp2meter[$i] < 32.1) { 
	 $pClass[$i] = "3.9.9";
	 if ($precip[$i] < 0.001 ) { $pClass[$i] = "3.0.0"; $ptype = "    " ; goto EndPtype }
     if ( $ptype eq "  ICE " ) {
         if ( $posEnergyAlft[$i] <= 15.0 ) #percent of snow melted aloft
		   {$SRpercent[$i] = 1.0 - ($posEnergyAlft[$i]/15.0)**0.5; $IRpercent[$i] = 0.0; $RRpercent[$i] = 1.0 - $SRpercent[$i]}
         else 
		   {$SRpercent[$i] = 0.0; $IRpercent[$i] = 0.0; $RRpercent[$i] = 1.0}
         if ( $SRpercent[$i] > 0.0) { #percent of melted liquid refrozen into ice if some snow still present
			 if ( $negEnergy1[$i] <= 25.0 ) {$IRpercent[$i] = ($negEnergy1[$i]/25.0)*$RRpercent[$i]; $RRpercent[$i] -= $IRpercent[$i]}
              else                          {$IRpercent[$i] =  1.0 - $SRpercent[$i] ; $RRpercent[$i] = 0.0 }}
		 else                       { #percent of melted liquid refrozen into ice given no snow present
			 if ( $negEnergy2[$i] <= 25.0 ) {$IRpercent[$i] = $negEnergy2[$i]/25.0; $RRpercent[$i] -= $IRpercent[$i]}
              else                          {$IRpercent[$i] = 1.0; $RRpercent[$i] = 0.0 }}

         # decision time - 6 choices
		 if    ( $SRpercent[$i] > 0.89 )                  { $pClass[$i] = "3.1.1"; $ptype = " SNOW " }
		 elsif ( $IRpercent[$i] > 0.89 )                  { $pClass[$i] = "3.1.2"; $ptype = " PL   " }
		 elsif ( $RRpercent[$i] > 0.89 )                  { $pClass[$i] = "3.1.3"; $ptype = " FZRA " }
		 elsif ( $SRpercent[$i] + $IRpercent[$i] > 0.89 ) { $pClass[$i] = "3.1.4"; $ptype = " SNPL " }
		 elsif ( $IRpercent[$i] + $RRpercent[$i] > 0.89 ) { $pClass[$i] = "3.1.5"; $ptype = " ZRPL " }
		 elsif ( $RRpercent[$i] + $SRpercent[$i] > 0.89 ) { $pClass[$i] = "3.1.6"; $ptype = " ZRSN " }
		 else                                             { $pClass[$i] = "3.1.7"; $ptype = "SNZRPL" }
	 }
     elsif ( $ptype eq "   UP " ) { #no snow present
       $SRpercent[$i] = 0.0; $IRpercent[$i] = 0.0; $RRpercent[$i] = 1.0;
	   if ( $negEnergy2[$i] <= 25.0 ) {$IRpercent[$i] = $negEnergy2[$i]/25.0; $RRpercent[$i] -= $IRpercent[$i]}
        else                          {$IRpercent[$i] = 1.0; $RRpercent[$i] = 0.0 }
       if ($maxCloudLyrOmega[$i] > -10.0 ) { 
		   if    ( $IRpercent[$i] > 0.89 )  { $pClass[$i] = "3.2.1"; $ptype = " SG   " } 
		   elsif ( $IRpercent[$i] > 0.09 )  { $pClass[$i] = "3.2.2"; $ptype = " ZLSG " }
	       else                             { $pClass[$i] = "3.2.3"; $ptype = " FZDZ " }}
	   else {
		   if    ( $IRpercent[$i] > 0.89 )  { $pClass[$i] = "3.2.1"; $ptype = " PL   " } 
		   elsif ( $IRpercent[$i] > 0.09 )  { $pClass[$i] = "3.2.2"; $ptype = " ZRPL " }
	       else                             { $pClass[$i] = "3.2.3"; $ptype = " FZRA " }}  
     }
   }

   ### Case 4: Both Elevated and surface warm layers - SNOW, SNPL, PL, PLRA, RAIN, DZ ( posEnergyAlft > 0 and posEnergySfc > 0 )
   elsif ($temp2meter[$i] > 32.0 ) {
	 $pClass[$i] = "4.9.9";
	 if ($precip[$i] < 0.001 ) { $pClass[$i] = "4.0.0"; $ptype = "    " ; goto EndPtype }
      if ( $ptype eq "  ICE " )   {
         if ( $posEnergyAlft[$i] <= 15.0 ) #percent of snow melted aloft
		   {$SRpercent[$i] = 1.0 - ($posEnergyAlft[$i]/15.0)**0.5; $IRpercent[$i] = 0.0; $RRpercent[$i] = 1.0 - $SRpercent[$i]}
         else 
		   {$SRpercent[$i] = 0.0; $IRpercent[$i] = 0.0; $RRpercent[$i] = 1.0}
         if ( $SRpercent[$i] > 0.0) { #percent of melted liquid refrozen into ice if some snow still present
			 if ( $negEnergy1[$i] <= 25.0 ) {$IRpercent[$i] = ($negEnergy1[$i]/25.0)*$RRpercent[$i]; $RRpercent[$i] -= $IRpercent[$i]}
              else                          {$IRpercent[$i] =  1.0 - $SRpercent[$i] ; $RRpercent[$i] = 0.0 }}
		 else                       { #percent of melted liquid refrozen into ice given no snow present
			 if ( $negEnergy2[$i] <= 25.0 ) {$IRpercent[$i] = $negEnergy2[$i]/25.0; $RRpercent[$i] -= $IRpercent[$i]}
              else                          {$IRpercent[$i] = 1.0; $RRpercent[$i] = 0.0 }}
         
         if ( $posEnergySfc[$i] <= 15.0 ) #percent of snow melted below cold layer
		    {$RRpercent[$i] += ($SRpercent[$i]*($posEnergySfc[$i]/15.0)**0.5); $SRpercent[$i] *= (1.0-($posEnergySfc[$i]/15.0)**0.5)}
         else 
		    {$RRpercent[$i] += $SRpercent[$i]; $SRpercent[$i] = 0.0}

         if ( $posEnergySfc[$i] <= 25.0 ) #percent of ice melted below cold layer
		    {$RRpercent[$i] += ($IRpercent[$i]*($posEnergySfc[$i]/25.0)); $IRpercent[$i] *= (1.0-($posEnergySfc[$i]/25.0))}
         else 
		    {$RRpercent[$i] += $IRpercent[$i]; $IRpercent[$i] = 0.0}
		 
         # decision time - 6 choices
		 if    ( $SRpercent[$i] > 0.89 )                  { $pClass[$i] = "4.1.1"; $ptype = " SNOW " }
		 elsif ( $IRpercent[$i] > 0.89 )                  { $pClass[$i] = "4.1.2"; $ptype = " PL   " }
		 elsif ( $RRpercent[$i] > 0.89 )                  { $pClass[$i] = "4.1.3"; $ptype = " RAIN " }
		 elsif ( $SRpercent[$i] + $IRpercent[$i] > 0.89 ) { $pClass[$i] = "4.1.4"; $ptype = " SNPL " }
		 elsif ( $IRpercent[$i] + $RRpercent[$i] > 0.89 ) { $pClass[$i] = "4.1.5"; $ptype = " RAPL " }
		 elsif ( $RRpercent[$i] + $SRpercent[$i] > 0.89 ) { $pClass[$i] = "4.1.6"; $ptype = " RASN " }
		 else                                             { $pClass[$i] = "4.1.7"; $ptype = "SNRAPL" }
	  }
     elsif ( $ptype eq "   UP " )           {
       $SRpercent[$i] = 0.0; $IRpercent[$i] = 0.0; $RRpercent[$i] = 1.0;
	   if ( $negEnergy2[$i] <= 25.0 ) {$IRpercent[$i] = $negEnergy2[$i]/25.0; $RRpercent[$i] -= $IRpercent[$i]}
        else                          {$IRpercent[$i] = 1.0; $RRpercent[$i] = 0.0 }
	   if ( $posEnergySfc[$i] <= 25.0 ) #percent of ice melted below cold layer
		    {$RRpercent[$i] += ($IRpercent[$i]*($posEnergySfc[$i]/25.0)); $IRpercent[$i] *= (1.0-($posEnergySfc[$i]/25.0))}
        else 
          {$RRpercent[$i] += $IRpercent[$i]; $IRpercent[$i] = 0.0}
       if ($maxCloudLyrOmega[$i] > -10.0 ) { 
		   if    ( $IRpercent[$i] > 0.89 )  { $pClass[$i] = "3.2.1"; $ptype = " SG   " } 
		   elsif ( $IRpercent[$i] > 0.20 )  { $pClass[$i] = "3.2.2"; $ptype = " SGDZ " }
	       else                             { $pClass[$i] = "3.2.3"; $ptype = "   DZ"  }}
	   else {
		   if    ( $IRpercent[$i] > 0.89 )  { $pClass[$i] = "3.2.1"; $ptype = " PL  "  } 
		   elsif ( $IRpercent[$i] > 0.09 )  { $pClass[$i] = "3.2.2"; $ptype = " RAPL " }
	       else                             { $pClass[$i] = "3.2.3"; $ptype = " RAIN " }}
      }  # End If ice in cloud (snow/no snow)
   }  # End pClass of 4.x.x

#  if ($i == 30 ) {print "$i,  $temp2meter[$i],  $warm,  $warmPresMin, PS $posEnergySfc[$i],  PA $posEnergyAlft[$i],  P $posEnergy[$i],  N1 $negEnergy1[$i],  N2 $negEnergy2[$i],  $SRpercent[$i]\n"}    
# }

 EndPtype:
 return ($ptype) ;
}  ### End GetPrecipType


### Calculate snowratio and snow accumulation using Caribou(Cobb) method.
sub GetSnow {
my $j ;
my $a ;
my $b ;
my $c ;
my $d ;
my $tdiff ;
my $srUvvWgt ;
my $cumArea = 1.0 ;
#my @layerSR ;
my @omegArea ;
$cumOmeg[$i][$j] = 1.0 ;
#$snRatio[$i] = 0.0 ;

#print "I am in GetSnow :-)  $i \n" ;
  for($j = $#{$pres[$i]}; $j >=1; $j--) {
    if ( $lyrRHice[$i][$j] >= $RHThresh  and  $lyrOmega[$i][$j] < 0.0 ) {           ### Need to fix lyrRH thresh...
      ### Calculate layer snow ratio 
        # Use a cubic spline of 5 piecewise polynomials to represent snow ratio as a
        # function of temperature.
      if ( $lyrTemp[$i][$j] < -40.0 ) {
         $tdiff = 0.0;
         ($a, $b, $c, $d) = split(/ /,"2.00 0.0000 0.0000 0.0000") }
	   elsif ( $lyrTemp[$i][$j] < -28.0 ) {
         $tdiff = $lyrTemp[$i][$j] + 40.0;
         ($a, $b, $c, $d) = split(/ /,"2.00	0.3218 0.0000 0.0012") }     
	   elsif ( $lyrTemp[$i][$j] < -21.0 ) {
         $tdiff = $lyrTemp[$i][$j] + 28.0;
         ($a, $b, $c, $d) = split(/ /,"8.00	0.8564 0.0446 0.0111") }
       elsif ( $lyrTemp[$i][$j] < -18.0 ) {
         $tdiff = $lyrTemp[$i][$j] + 21.0;
         ($a, $b, $c, $d) = split(/ /,"20.00 3.1182	0.2786 -0.0689") }
       elsif ( $lyrTemp[$i][$j] < -15.0 ) {
         $tdiff = $lyrTemp[$i][$j] + 18.0;
         ($a, $b, $c, $d) = split(/ /,"30.00 2.9280 -0.3420 -0.0262") }
       elsif ( $lyrTemp[$i][$j] < -12.0 ) {
         $tdiff = $lyrTemp[$i][$j] + 15.0;
         ($a, $b, $c, $d) = split(/ /,"35.00 0.1699 -0.5774 -0.0857") }
       elsif ( $lyrTemp[$i][$j] < -10.0 ) {
         $tdiff = $lyrTemp[$i][$j] + 12.0;
         ($a, $b, $c, $d) = split(/ /,"28.00 -5.6075 -1.3484 0.4511") }
       elsif ( $lyrTemp[$i][$j] < -8.0 ) {
         $tdiff = $lyrTemp[$i][$j] + 10.0;
         ($a, $b, $c, $d) = split(/ /,"15.00 -5.5883 1.3580 -0.1569") }
       elsif ( $lyrTemp[$i][$j] < -5.0 ) {
         $tdiff = $lyrTemp[$i][$j] + 8.0;
         ($a, $b, $c, $d) = split(/ /,"8.00 -2.0395 0.4164 -0.0233") }
       elsif ( $lyrTemp[$i][$j] < -3.0 ) {
         $tdiff = $lyrTemp[$i][$j] + 5.0;
         ($a, $b, $c, $d) = split(/ /,"5.00 -0.1702 0.2067 -0.0608") }
       elsif ( $lyrTemp[$i][$j] <= 0.0 ) {
         $tdiff = $lyrTemp[$i][$j] + 3.0;
         ($a, $b, $c, $d) = split(/ /,"5.00 -0.0730 -0.1581 0.0105") }
       elsif ( $lyrTemp[$i][$j] > 0.0 ) {
         $tdiff = 0.0;
         ($a, $b, $c, $d) = split(/ /,"0.00 0.0000 0.0000 0.0000") ;
      }
#print "$a, $b, $c, $d\n";
      $layerSR[$j] = $a + $b*$tdiff + $c*($tdiff**2) + $d*($tdiff**3);
         
      # Adjust layer SR based on layer RH, pressure, lapse rate, and omega.
      $layerSR[$j] -= 10.0 ;
#      $layerSR[$j] *= ($lyrRHice[$i][$j]/98.);    
      if ($lyrPres[$i][$j] < 700. and $layerSR[$j] > 0.0)                            # Adjust SR to decrease w/ lower pressures
         {$layerSR[$j] *= ($lyrPres[$i][$j]/700.0)}
      if ($lyrOmega[$i][$j] > -10.) {$layerSR[$j] *= (1.0 - (($lyrOmega[$i][$j] + 10.0)/20.))}
       else                         {$layerSR[$j] *= (1.0 - (($lyrOmega[$i][$j] + 10.0)/200.))}
      if ($lyrLapse[$i][$j] > 5.)   {$layerSR[$j] *= (1.0 + (($lyrLapse[$i][$j] - 5.0)/20.))}
       else                         {$layerSR[$j] *= (1.0 - (($lyrLapse[$i][$j] - 5.0)/50.))}
      $layerSR[$j] += 10.0 ;
      if    ($layerSR[$j] > 50. ) {$layerSR[$j] = 50.}
      elsif ($layerSR[$j] < 3. )  {$layerSR[$j] = 3.}
          
      ### Calculate weight for each layer and sum - weight function of uvv, layer thickness, rh, and lapse rate.
      $omegArea[$j] = -1.0 * $lyrOmega[$i][$j] * $lyrThick[$i][$j];
#      if ($lyrOmega[$i][$j] <= (0.50 * $maxCloudLyrOmega[$i])) {$omegArea[$j] *= 1000.0} 
#      if ($lyrOmega[$i][$j] <= -10.0 ) {$omegArea[$j] *= 10000.0} 
#      if ($lyrLapse[$i][$j] > 5.) {$omegArea[$j] *= ($lyrLapse[$i][$j]/3.)}         # Cumuliform clouds strongly effect ratio either way...
#      if ($lyrPres[$i][$j] < 700.)                                                   
#         {$omegArea[$j] *= ($lyrPres[$i][$j]/700.0)}
#      $omegArea[$j] *= (($lyrRHice[$i][$j] - 80.)/20.0);

      $cumArea += $omegArea[$j]}  
    else                      {
      $layerSR[$j] = 0.0 ;
      $omegArea[$j] = 0.0 }
      #if ($i == 37 ) {print "$i, $layerSR[$j],  $lyrTemp[$i][$j],  $lyrThick[$i][$j],  $lyrOmega[$i][$j],  $omegArea[$j],  $cumArea\n" }
    } ### End for $j...loop

  if ($cumArea < 0.00001 ) { $cumArea = 1.0 } # avoid divide by zero error if no UVV in column
  for($j = $#{$pres[$i]}; $j >=0; $j--) {
    $percentArea[$i][$j] = 100 * ( $omegArea[$j] / $cumArea )  ;
	$wgtSum[$i][$j] = $percentArea[$i][$j] + $wgtSum[$i][$j+1] ;     #used in diag display
	$percentSR[$i][$j] = ($layerSR[$j] * ( $omegArea[$j] / $cumArea )) ;  #used in diag display
    $cumPercentSR[$i][$j] = $percentSR[$i][$j] + $cumPercentSR[$i][$j+1]; #used in diag display
    $snRatio[$i] += ($layerSR[$j] * ( $omegArea[$j] / $cumArea )) ;
  } ### End for $j...loop - Top Down calcs of layer SR and weights
  if ( $snRatio[$i] < 1.0 ) { $snRatio[$i] = 10.0} # snow occuring with no UVV in column - default to 10:1.
  
#  $snowFall[$i] = $snRatio[$i] * $precip[$i] ;
}  ### End GetSnow
