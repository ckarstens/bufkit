#!/usr/bin/perl
#===============================================================================
#
#         FILE:  Utils.pm
#
#  DESCRIPTION:  Contains basic utility routines for the BUFRgruven routine
#                At least that's the plan
#
#
#       AUTHOR:  Robert Rozumalski - NWS
#      VERSION:  18.30.3
#      CREATED:  25 July 2018
#===============================================================================
#
package Utils;
require 5.8.0;
use strict;
use warnings;
use English;



sub popit {
#----------------------------------------------------------------------------------
#  This routine accepts the fully qualified path/name and returns both
#  the name of the file and the path.
#----------------------------------------------------------------------------------
#
    for (shift) {
        s/\^.//g;
        my @list = split /\// => $_;
        my $prog = pop @list;
        my $path = join "/" => @list;
        return $path, $prog;
    }
}


sub rmdups {
#----------------------------------------------------------------------------------
#  This routine eliminates duplicates from a list.
#----------------------------------------------------------------------------------
#
    my @list = ();
    foreach (@_) {push @list => $_ if length $_;}
    return @list unless @list;

    my %temp = ();
    @list = grep ++$temp{$_} < 2 => @list; 

return @list;
}


sub cklib {
#----------------------------------------------------------------------------------
#   This routine accepts a list of dynamic linked binaries and returns
#   a list of missing libraries on the system.
#----------------------------------------------------------------------------------
#
    my @libs=();

    my @routs = @_; return @libs unless @routs;

    #  Get the ldd command
    #
    my $ldd = &findcmd('ldd');
    my $fe  = &findcmd('file');

    return @libs unless -e $ldd;

    foreach (@routs) {
       next unless $_;
       my $type = (grep /ELF 64-bit/i => `$fe $_`) ? '64-bit' : (grep /ELF 32-bit/i => `$fe $_`) ? '32-bit' : 'Unknown';
       foreach (grep /not found/i => `$ldd $_`) {
           chomp; s/\s//g;
           my @list = split /=/ => $_;
           push @libs => "$type $list[0]";
       }
    }

    #  Eliminate duplicates
    #
    @libs = &rmdups(@libs);

return @libs;
}


sub envEvalHires {
#----------------------------------------------------------------------------------
#  This routine checks for the existence of needed Perl Modules.
#----------------------------------------------------------------------------------
#
    #  Perl Module Time::HiRes
    #
    my $hires = (defined eval{require Time::HiRes}) ? 1 : 0;

    #  Provide early warning messages
    #
    unless ($hires) {

        my $mesg =  "It is recommended that you install this library on your system, which ".
                    "is simple enough to do and should relieve the pain and suffering caused ".
                    "by seeing this message again and again, which you will.";

         &modprint(6,5,86,1,1,"WARNING: Perl Module not Available - Time::HiRes",$mesg);

    }


return $hires;
}


sub emptydir {
#---------------------------------------------------------------------------------
#  A routine to check whether a directory is empty. Returns 0 for empty
#  and 1 if it contains something.
#---------------------------------------------------------------------------------
#
    opendir my $dh, +shift or return(0);
    return grep { not /^\.+$/ } readdir $dh;

}


sub execute {
#---------------------------------------------------------------------------------
#  Thus routing uses the "system" command to run the passed command and
#  returns the exit status
#
#  Note exit values:
#
#    exit_value  - $? >> 8
#    signal_num  - $? & 127
#    dumped_core - $? & 128
#    Everything is coming up roses - 0
#---------------------------------------------------------------------------------
#
    $|=1;

    my ($prog, $log) = @_; &rm($log) if $log;

    my $cmd = $log ? "$prog > $log 2>&1" : $prog;

    if (system($cmd)) {

        return 2 if $? == 2;

        if ($? == -1) {
            &modprint(0,1,70,0,2,"- Failed to execute: $!");
            return -1;
        }

        if ($? & 127) {
            &modprint(0,1,114,0,2,sprintf("- Died with signal %d, %s coredump",($? & 127),($? & 128) ? 'with' : 'without'));
        }

        my $rc = $? >> 8;
        return $rc;
    }

return 0;
}


sub mkdir {
#----------------------------------------------------------------------------------
#  This routine creates a directory unless it already exists.
#----------------------------------------------------------------------------------
#
    my $dir    = shift;
    my $status = 0;
       $status = system "mkdir -m 755 -p $dir  > /dev/null 2>&1" unless -e $dir;
       &modprint(6,18,144,1,1,"Error with mkdir system command","$dir - $!") if $status;

return $status;
}


sub rm {
#----------------------------------------------------------------------------------
#  This routine deletes files, links and directories if found. Ya, that's all
#----------------------------------------------------------------------------------
#
    my $t = shift;
    my $status = -d $t ? system "rm -fr $t" : (-f $t or -l $t) ? system "rm -f $t" : 0;

return $status;
}


sub aindxe {
#----------------------------------------------------------------------------------
#  This routine returns the index of an array element that exactly matches the first element
#----------------------------------------------------------------------------------
#
    my $e = pop @_;
    $e = pop @_ while @_ and $e ne $_[0];
    @_-1;
}


sub fillit {
#----------------------------------------------------------------------------------
#  This routine takes a format string and a list of placeholder:value pairs and
#  returns the string with the requested placeholder characters replaced with the
#  appropriate values.
#----------------------------------------------------------------------------------
#
   my ($str, $yyyymmdd, $cycle, $dset, $model) = @_;

   my $julian = &Time::julian($yyyymmdd);

   my $yymmdd = substr $yyyymmdd,2;
   my $yyyy   = substr $yyyymmdd,0,4;
   my $yy     = substr $yyyymmdd,0,2;
   my $mm     = substr $yyyymmdd,4,2;
   my $dd     = substr $yyyymmdd,6,2;


   #  Note that the order is important here. For example, "DDD" must 
   #  come before "DD".  


   for ( $str ) {
      s/NMM/ZZZ/g;
      s/YYYYMMDD/$yyyymmdd/g;
      s/YYMMDD/$yymmdd/g;
      s/YYYY/$yyyy/g;
      s/MM/$mm/g;
      s/YY/$yy/g;
      s/DDD/$julian/g;
      s/DD/$dd/g;
      s/CC/$cycle/g;
      s/MOD/$model/g;
      s/DSET/$dset/g;
      s/ZZZ/NMM/g;
      s/\/\//\//g;
      s/\n//g;
   }

return $str;
}

sub hkey_resolv {
#----------------------------------------------------------------------------------
#  This routine attempts to match a host key used in the bufrinfo.conf file with
#  an assigned hostname or IP address which is defined in the bufrgruven.conf file.
#----------------------------------------------------------------------------------
#
    my ($hkey, %keys) = @_; return unless $hkey;

    #  Check for passed IP or hostname
    #
    for ($hkey) {
        if (/^local/i)                                      {return 'LOCAL';}
        if (/^([\d]+)\.([\d]+)\.([\d]+)\.([\d]+)$/)         {return $hkey;} # IP address
        if (/^([\w]|-)+\.([\w]|-)+\.([\w]|-)+\.([\w]|-)+$/) {return $hkey;} # Hostname
        if (/^([A-Z0-9])+$/)                                {return $keys{uc $hkey} if defined $keys{uc $hkey};}  # All upper get key
        if (/^([\w]|-)+$/)                                  {defined $keys{uc $hkey} ? return $keys{uc $hkey} : return lc $hkey;} # Assume short hostname
    }

    &modprint(6,9,114,1,1,sprintf("Could not match %s to IP or hostname. Is it defined in bufrgruven.conf?",$hkey));

return;
}


sub findcmd {
#----------------------------------------------------------------------------------
#  This routine attempts to locate the system command that is passed.
#----------------------------------------------------------------------------------
#
    my $rutil = shift;

    my $util = `whereis $rutil`; my @utils = split / / => $util;

    return $utils[1] if $utils[1] and -X $utils[1];

    $rutil = -e "/usr/bin/$rutil" ? "/usr/bin/$rutil" : -e "/bin/$rutil" ? "/bin/$rutil" : 0 unless -X $rutil;

return $rutil;
}

sub kbmb {
#----------------------------------------------------------------------------------
#    Returns the size of a file in mb
#----------------------------------------------------------------------------------
#
  my $kbs = shift;
     $kbs =~ tr/,|\.//d;
  my $rfs = $kbs * 0.0000953674316; return sprintf ("%.2f",$rfs*0.01);
}


sub modprint {
#----------------------------------------------------------------------------------
#  This routine prints all error, warning, and information statements to the
#  user with a consistent format.
#----------------------------------------------------------------------------------
#
use Text::Wrap;

    my ($type,$indnt,$cols,$leadnl,$trailnl,$head,$body,$text)  = @_;

    return unless $ENV{VERBOSE};

    #  Note Types:
    #
    #    1 - "*"
    #    2 - "EMS WARNING"
    #    3 - "EMS ERROR"
    #    4 - "EMS DEBUG"
    #    5 - "->"
    #    6 - "!"
    #    7 - ">"
    #

    #  Set defaults
    #
    local $Text::Wrap::columns = $cols > 80 ? $cols : 80;  # sets the wrap point. Default is 80 columns.
    local $Text::Wrap::separator="\n";
    local $Text::Wrap::unexpand;

    my $nl = "\n";
    unless ($head) {
        print "\n\n    Problem in modprint: $type,$indnt,$cols,$leadnl,$trailnl,$head\n";
        print "    No harm - no foul\n\n";
        return;
    }

    $indnt   = ! $indnt ? 6 : $indnt < 0 ? 6 : $indnt;
    $leadnl  = $leadnl  < 0 ? sprintf ("%s",$nl x 1) : sprintf ("%s",$nl x $leadnl);
    $trailnl = $trailnl < 0 ? sprintf ("%s",$nl x 1) : sprintf ("%s",$nl x $trailnl);

    $type  = $type == 1 ? '*' : $type == 2 ? "EMS WARNING" : $type == 3 ? "EMS ERROR  "
                              : $type == 4 ? "EMS DEBUG "  : $type == 5 ? '->'
                              : $type == 6 ? '!'           : $type == 7 ? '>'   : "";
    $text  = $text ? " ($text)" : "";

    #  Format the text
    #
    my $header = $type eq '*' ? "$type$text  " : $type eq '!' ? "$type$text  " : $type eq '->' ? "$type$text " : $type eq '>' ? "$type$text  " : $type ? "$type$text: " : "";
    $head      = "$header$head";
    $body      = "\n\n$body" if $body;

    #  Format the indent
    #
    my $hindnt = $indnt < 0 ? sprintf ("%s"," " x 1) : sprintf ("%s"," " x $indnt);
    my $bindnt = sprintf ("%s"," " x length "$hindnt$header");
    my $windnt = $type eq '*' ? "   $hindnt" : $type eq '->' ? "  $hindnt" : $type eq '>' ? "   $hindnt" : $type eq '!' ? "   $hindnt" : $type eq '!' ? "   $hindnt" : $bindnt;

    $| = 1;
    print "$leadnl";
    print wrap($hindnt,$windnt,$head);
    print wrap($bindnt,$bindnt,$body)   if $body;
    print "$trailnl";

return;
}


sub prnt_brec {
#----------------------------------------------------------------------------------
#  Prints out information within the data structure for each data set in debug
#----------------------------------------------------------------------------------
#
    my $brec = shift;  return unless $brec;

    my $ymd = $brec->yyyymmdd;
    my $cc  = $brec->acycle;

    &modprint(0,4,84,1,2,sprintf("Contents of BUFR information structure:"));

    &modprint(0,6,84,0,1,sprintf("DATA SET        : %s",$brec->dset));
    &modprint(0,6,144,0,1,sprintf("DESCRIPTION     : %s",$brec->info));
    &modprint(0,6,84,0,1,sprintf("MODEL NAME      : %s",$brec->model));
    &modprint(0,6,84,0,1,sprintf("CONFIG FILE     : %s",$brec->fname));
    &modprint(0,6,84,0,1,sprintf("AVAILABLE CYCLES: %s",join(' ',@{$brec->cycles})));
    &modprint(0,6,84,0,2,sprintf("DELAY HOURS     : %s",$brec->delay));

    &modprint(0,6,84,0,2,sprintf("REQUESTED DATE  : %s",&Time::dateprnt("$ymd$cc")));

    while (my ($key, $value) = each %{$brec->stations}) {
        &modprint(0,6,84,0,1,sprintf("STATIONS        : %-4s (%s)",uc $value, $key));
    }
    
    &modprint(0,6,84,0,1,sprintf("INVALID STATIONS: %s",join(', ',@{$brec->invalstn}))) if @{$brec->invalstn};

    &modprint(0,6,84,1,1,sprintf("ACQUIRE METHODS : %s",join(' ',@{$brec->methods})));
    &modprint(0,6,84,0,2,sprintf("LOCAL BUFR NAME : %s",$brec->locfil));

    foreach my $dir (@{$brec->bfdirs}) {&modprint(0,6,84,0,1,sprintf("EXPORT BUFR     : %s",$dir));}
    foreach my $dir (@{$brec->bfdirs}) {&modprint(0,6,84,0,1,sprintf("EXPORT BUFKIT   : %s",$dir));}
    foreach my $dir (@{$brec->bfdirs}) {&modprint(0,6,84,0,1,sprintf("EXPORT GEMPAK   : %s",$dir));}
    foreach my $dir (@{$brec->bfdirs}) {&modprint(0,6,84,0,1,sprintf("EXPORT ASCII    : %s",$dir));}
    
    foreach (@{$brec->methods}) {
        if (/ftp/i) {
            while (my ($key, $value) = each %{$brec->ftpservers}) {
                &modprint(0,6,144,0,1,sprintf("FTP SERVER      : %-6s %s",$key,$value));
            }
        }
       
        if (/http/i) {
            while (my ($key, $value) = each %{$brec->htpservers}) {
                &modprint(0,6,144,0,1,sprintf("HTTP SERVER      : %-6s %s",$key,$value));
            }
        }

        if (/nfs/i) {
            while (my ($key, $value) = each %{$brec->nfsservers}) {
                &modprint(0,6,144,0,1,sprintf("NFS SOURCE       : %-6s %s",$key,$value));
            }
        }
   }

return;
}
