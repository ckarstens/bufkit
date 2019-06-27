<?php

// Author: 	Chris Karstens
// Date: 	February 16, 2012
// Versions:	PHP, Perl, Bufrgruven
// Purpose:	1) Generate NAM bufkit profiles
//		2) Insert data into ldm archives
// Notes:	1) To run this script on the fly, issue the following command (specify date as model run time + 2 hours in UTC):
//		php nam_bufkit.php now="2012-02-10 14:00:00" 

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
$st = $t - (2*3600);
$stime = date("Ymd",$st);
$shour = date("H",$st);
$iem_date = date("YmdHi",$st);
$model = "nam";
$model2 = "nam";
$filename = "".$model.".t".$shour."z.tm00.bufrsnd.tar.gz";
$filename2 = "".$model.".t".$shour."z.tm00.bufrsnd.tar";
$cur_dir = "/local/ckarsten/bufkit/".$model."/scripts/".$model."/";
$data_dir = "/local/ckarsten/bufkit/".$model."/scripts/".$model."/data/";
$fname = "".$data_dir."".$filename."";
$fname2 = "".$data_dir."".$filename2."";
$url = "https://nomads.ncep.noaa.gov/pub/data/nccf/com/".$model."/prod/".$model.".".$stime."/".$filename."";
//$url = "ftp://ftpprd.ncep.noaa.gov/pub/data/nccf/com/";

if($shour == "06" || $shour == "18"){
	$model1 = "namm";
}
else{
	$model1 = "nam";
}


// try to download tar ball containing bufr data to process
// attemps every miniute for one hour
$j = 180;
for($i=0;$i<=$j;$i++){
        system("wget -O ".$fname." ".$url."");
	echo "".$fname2."\n";
	system("gunzip ".$fname."");           
        if(file_exists($fname2)){
                echo "File Found!\nTime: ".date("Y-m-d H:i:s")." UTC\n\n";
	        system("tar -C ".$data_dir." -xf ".$fname2."");
        	system("rm ".$fname2."");
		break;
        }
        else{
                echo "File not there yet...\nTime: ".date("Y-m-d H:i:s")." UTC\n\n";
		system("rm ".$fname."");
                sleep(60);
        }
	if($i == $j){
		die("Timed out!");
	}
}

// generate list of files available from the bufr download
$files = scandir($data_dir);
$n = count($files) - 1;
$j = 0;
$sites = array();
$numbers = array();
$link = "/local/ckarsten/bufkit/".$model."/stations/".$model."_bufrstations.txt";
$data = file($link);
foreach($data as $line){
	$d = explode(" ", trim(ereg_replace( ' +', ' ', $line)));
	$numbers[] = $d[0];
	$sites[] = $d[3];
}


// generate bufkit data
// insert into ldm archives
for($i=2;$i<=$n;$i++){
	$j++;
	$s = explode(".",$files[$i]);
	$site = $s[1];
	$index = array_search($site,$numbers);
	echo "Processing: ".$site.", ".strtolower($sites[$index])."\n";
	system("perl /local/ckarsten/bufkit/".$model."/bufr_gruven.pl --nfs --dset ".$model1." --date ".$stime." --cycle ".$shour." --noascii --stations ".$site." --nozipit");
	$filename = "/local/ckarsten/bufkit/".$model."/metdat/bufkit/".$model1."_".strtolower($sites[$index]).".buf";
	if(file_exists($filename)){
		$cmd = "/local/ldm/bin/pqinsert -p 'bufkit ac ".$iem_date." bufkit/".$model1."/".$model1."_".strtolower($sites[$index]).".buf bufkit/".$shour."/".$model."/".$model1."_".strtolower($sites[$index]).".buf bogus' ".$filename."";
		echo "".$cmd."\n";
		system($cmd);
        }
	
	// the following block of code is needed, otherwise data processing will terminate after about 60 or 70 files are processed.
	// I believe there is memory leakage occuring.
	if($j == 50){
                system("mv /local/ckarsten/bufkit/".$model."/metdat/bufkit/*.buf /local/ckarsten/bufkit/".$model."/metdat/bufkit_temp/");
		system("rm /local/ckarsten/bufkit/".$model."/metdat/ascii/*");
		system("rm /local/ckarsten/bufkit/".$model."/metdat/bufr/*");
		system("rm /local/ckarsten/bufkit/".$model."/metdat/gempak/*");
                $j = 0;
        }        

}

// final clean-up
system("mv /local/ckarsten/bufkit/".$model."/metdat/bufkit/*.buf /local/ckarsten/bufkit/".$model."/metdat/bufkit_temp");
system("rm /local/ckarsten/bufkit/".$model."/metdat/ascii/*");
system("rm /local/ckarsten/bufkit/".$model."/metdat/bufr/*");
system("rm /local/ckarsten/bufkit/".$model."/metdat/gempak/*");
system("rm /local/ckarsten/bufkit/".$model."/scripts/".$model."/data/*");

// generate cobb data
// note: make_cobb.php inserts data into ldm
system("php /local/ckarsten/bufkit/".$model."/cobb/make_cobb.php iem_date=".$iem_date." hour=".$shour." model=".$model2."");

system("rm /local/ckarsten/bufkit/".$model."/metdat/bufkit_temp/*.buf");
system("rm /local/ckarsten/bufkit/".$model."/cobb/data/*.dat");

?>
