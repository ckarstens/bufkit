<?php

// Author: 	Chris Karstens
// Date: 	February 21, 2012
// Versions:	PHP, Perl, Bufrgruven
// Purpose:	1) Generate SREF bufkit profiles
//		2) Insert data into ldm archives
// Notes:	1) To run this script on the fly, issue the following command (specify date as model run time + 4 hours in UTC):
//		php sref_bufkit.php now="2012-02-10 16:00:00" 

putenv("TZ=UTC");

if(isset($argv)){
	for($c=1;$c<count($argv);$c++){
        	$it = split("=",$argv[$c]);
        	$_GET[$it[0]] = $it[1];
     	}
}

$now1 = date("Y-m-d H:00:00");
$now = isset($_GET["now"]) ? $_GET["now"] : $now1;
$t = strtotime($now);
$st = $t - (4*3600);
$stime = date("Ymd",$st);
$shour = date("H",$st);
$iem_date = date("YmdHi",$st);
$model = "sref";
$model2 = "sref1";
$cur_dir = "/local/ckarsten/bufkit/".$model2."/scripts/".$model."/";
$data_dir = "/local/ckarsten/bufkit/".$model2."/scripts/".$model."/data/";

// try to download tar ball containing bufr data to process
// attemps every miniute for one hour
$k = 180;
$models = array('nmm_ctl','nmm_n1','nmm_p1','nmm_n2','nmm_p2','em_ctl','em_n1','em_p1','em_n2','em_p2','eta_ctl1','eta_n1','eta_p1','eta_ctl2','eta_n2','eta_p2','rsm_ctl1','rsm_n1','rsm_p1','rsm_n2','rsm_p2');

for($i=0;$i<=$k;$i++){
	$found = 0;
	for($j=0;$j<=20;$j++){
	        $filename = "".$models[$j].".t".$shour."z.bufrsnd.tar.gz";
	        $filename2 = "".$models[$j].".t".$shour."z.bufrsnd.tar";
	        $fname = "".$data_dir."".$filename."";
	        $fname2 = "".$data_dir."".$filename2."";
        	$url = "http://nomads.ncep.noaa.gov/pub/data/nccf/com/sref/prod/sref.".$stime."/".$shour."/bufr/".$filename."";
	        system("wget -O ".$fname." ".$url."");
		echo "".$fname2."\n";
		system("gunzip ".$fname."");           
	        if(file_exists($fname2)){
			$found++;
	                echo "File #".$found." Found!\nTime: ".date("Y-m-d H:i:s")." UTC\n\n";
	        }
	        else{
			$found1 = $found + 1;
	                echo "File #".$found1." not there yet...\nTime: ".date("Y-m-d H:i:s")." UTC\n\n";
			system("rm ".$fname."");
			break;
	        }
	}
	if($found == 21){
		echo "All 21 models downloaded, unleashing the beast!\n";
		for($j=0;$j<=20;$j++){
	                $filename2 = "".$models[$j].".t".$shour."z.bufrsnd.tar";
	                $fname2 = "".$data_dir."".$filename2."";
			echo "Un-tarring ".$filename2."\n";
			system("tar -C ".$data_dir." -xf ".$fname2."");
                        system("rm ".$fname2."");
		}
		break;
	}
	else{
		sleep(60);
	}
	if($i == $k){
		die("Timed Out!");
	}
}

/*
// initiate trigger for other cron scripts
$trigger = "trigger.txt";
$fh = fopen($trigger,"w");
fwrite($fh, "1");
fclose($fh);
*/

for($i=2;$i<=4;$i++){
	$cmd = "php /local/ckarsten/bufkit/sref".$i."/scripts/sref/sref_bufkit.php >& /local/ckarsten/bufkit/sref".$i."/scripts/sref/cron_sref_".$shour."_".$i.".txt&";
	echo "".$cmd."\n";
	system($cmd);
}

// generate list of files available from the bufr download
$files = scandir($data_dir);
$n = 343;
$j = 0;
$sites = array();
$numbers = array();
$link = "/local/ckarsten/bufkit/".$model2."/stations/".$model."_bufrstations.txt";
$data = file($link);
foreach($data as $line){
	$d = explode(" ", trim(ereg_replace( ' +', ' ', $line)));
	$numbers[] = $d[0];
	$sites[] = $d[3];
}


// generate bufkit data
// insert into ldm archives
for($i=2;$i<=$n;$i++){
	echo "".$i."\n";
	$j++;
	$s = explode(".",$files[$i]);
	$site = $s[1];
	$index = array_search($site,$numbers);
	echo "Processing: ".$site.", ".strtolower($sites[$index])."\n";
	system("perl /local/ckarsten/bufkit/".$model2."/bufr_gruven.pl --nfs --dset ".$model." --date ".$stime." --cycle ".$shour." --noascii --stations ".$site."");
	$filename = "/local/ckarsten/bufkit/".$model2."/metdat/bufkit/".$model."_".strtolower($sites[$index]).".buz";
	if(file_exists($filename)){
		$cmd = "/local/ldm/bin/pqinsert -p 'bufkit ac ".$iem_date." bufkit/".$model."/".$model."_".strtolower($sites[$index]).".buz bufkit/".$shour."/".$model."/".$model."_".strtolower($sites[$index]).".buz bogus' ".$filename."";
		echo "".$cmd."\n";
		system($cmd);
        }
	
	// the following block of code is needed, otherwise data processing will terminate after about 60 or 70 files are processed.
	// I believe there is memory leakage occuring.
	if($j == 50){
                system("mv /local/ckarsten/bufkit/".$model2."/metdat/bufkit/*.buz /local/ckarsten/bufkit/".$model2."/metdat/bufkit_temp/");
		system("rm /local/ckarsten/bufkit/".$model2."/metdat/ascii/*");
		system("rm /local/ckarsten/bufkit/".$model2."/metdat/bufr/*");
		system("rm /local/ckarsten/bufkit/".$model2."/metdat/gempak/*");
                $j = 0;
        }        

}

// final clean-up
system("mv /local/ckarsten/bufkit/".$model2."/metdat/bufkit/*.buz /local/ckarsten/bufkit/".$model2."/metdat/bufkit_temp");
system("rm /local/ckarsten/bufkit/".$model2."/metdat/ascii/*");
system("rm /local/ckarsten/bufkit/".$model2."/metdat/bufr/*");
system("rm /local/ckarsten/bufkit/".$model2."/metdat/gempak/*");

// generate cobb data
// note: make_cobb.php inserts data into ldm
//system("php /local/ckarsten/bufkit/".$model2."/cobb/make_cobb.php iem_date=".$iem_date." hour=".$shour." model=".$model2."");

system("rm /local/ckarsten/bufkit/".$model2."/metdat/bufkit_temp/*.buz");
system("rm /local/ckarsten/bufkit/".$model2."/cobb/data/*.dat");
sleep(1800);
system("mv /local/ckarsten/bufkit/".$model2."/scripts/".$model."/data /local/ckarsten/bufkit/".$model2."/scripts/".$model."/data2");
system("mkdir /local/ckarsten/bufkit/".$model2."/scripts/".$model."/data");
system("rm -rf /local/ckarsten/bufkit/".$model2."/scripts/".$model."/data2");

?>
