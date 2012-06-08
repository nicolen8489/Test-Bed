#!/usr/bin/perl
$email;
$timeout;
@directories;
#@solvers;
#@solverNames;
%solvers;
$pwd;
$timeformat;
%columnData;
@fileColumnNames;
%fileColumnData;
$includeFileData = 0;

if ($#ARGV < 1) {
  print "testbed.pl #solvers 'solver1' 'solver2' ... 'solvern' flags\n";
  print "Note: the last line of a solvers output must be SAT or UNSAT";
  print "Testbed flags: \n";
#  print "-e email address to notify upon completion \n";
  print "-d <directory path> directory of cnf files \n";
  print "-t <time in seconds> timeout limit per cnf file \n";
  print "-n name for solver in previous argument \n";
  print "-f <file> include data from file \n";
  exit;
} else {
  use File::Basename;
  @timedata = localtime(time);
  $timeformat = join "", $timedata[5]+1900, "_";
  if($timedata[4] < 10) {
    $timeformat = join "", $timeformat, 0;
  }
  $timeformat = join "", $timeformat, $timedata[4], "_";
  if($timedata[3] < 10) {
    $timeformat = join "", $timeformat, 0;
  }
  $timeformat = join "", $timeformat, $timedata[3], "-";
  if($timedata[2] < 10) {
    $timeformat = join "", $timeformat, 0;
  }
  $timeformat = join "", $timeformat, $timedata[2], ":";
  if($timedata[1] < 10) {
    $timeformat = join "", $timeformat, 0;
  }
  $timeformat = join "", $timeformat, $timedata[1], ":";
  if($timedata[0] < 10) {
    $timeformat = join "", $timeformat, 0;
  }
  $timeformat = join "", $timeformat, $timedata[0];
  $outputfile = join "", ">output", $timeformat, ".csv";
  chomp($pwd = `pwd`);
  open(OUTPUT, $outputfile);
  open(PROGOUTPUT, '>testbed_output.txt');
  parseCommandLine();
  print OUTPUT "#@ARGV\n";
  print OUTPUT "filename";
  if($includeFileData) {
    foreach $columnName (@fileColumnNames) {
      chomp($columnName);
      print OUTPUT ",$columnName";
    }
  }
  @columnNames = ("SAT/UNSAT", "nodeCount", "scoutCount", "time", "solvedBy", "scoutTime", "scoutSetup", "scoutOverhead", "%overhead", "validated");
   if(keys(%solvers) > 0) {
    foreach $columnName (@columnNames) {
      foreach $solverName (values %solvers) {
        print OUTPUT ",$solverName $columnName"
      }
    }
    print OUTPUT "\n";
  } else {
    print "there must be at least one solver to run\n";
    exit;
  }
  
  $numDirectories = @directories;
  if ($numDirectories > 0) {
    foreach $directory (@directories) {
      use File::Find;
      find(\&processCnfFile, $directory);
    }
  } else {
    print "At least one cnf directory must be passed to run.\n";
    exit;
  }
  close(OUTPUT);
  close(OUTPUTPROG);
  `rm testbed_output.txt`;
#  emailOutput();
}

sub parseCommandLine() {
  for (my $i = 0; $i <= $#ARGV; $i++) {
    if ($ARGV[$i] =~ /-s[0-9]*/) {
      $tempStr = substr $ARGV[$i], 2;
      $numSolvers = int($tempStr);
      for(my $j = 0; $j < $numSolvers; $j++) {
        $i++;
	if($ARGV[$i] eq "-d" || $ARGV[$i] eq "-e" || $ARGV[$i] eq "-t") {
          print "argument $i should be a solver based on the input number of solvers $numSolvers\n";
          exit;
        }
	$solvers{$ARGV[$i]} = $ARGV[$i];
        if($ARGV[$i+1] eq "-n") {	
	  $solvers{$ARGV[$i]} = $ARGV[$i+2];
          $i++;
          $i++;
        }
      }
    }
    elsif ($ARGV[$i] eq "-d") {
      $i++;
      push(@directories, $ARGV[$i]);
    }
    elsif ($ARGV[$i] eq "-e") {
      $i++;
      $email = $ARGV[$i];
    }
    elsif ($ARGV[$i] eq "-t") {
      $i++;
      $timeout = $ARGV[$i];
    }
    elsif ($ARGV[$i] eq "-f") {
      if($includeFileData) {
        print "unable to read data from multiple files, only reading data from first file\n";
      } else {
        $includeFileData = 1;
        open(INPUTFILE, $ARGV[++$i]);
        @lineData = <INPUTFILE>;	
        close(INPUTFILE);
        $firstLine = 1;
        foreach $line (@lineData) {
          if(!($line =~ /#.*/)) {
	    if($firstLine) {
              @fileColumnNames = split(",", $line);
	      shift(@fileColumnNames);
              $firstLine = 0;
            } else {
  	      @values = split(",", $line);
  	      $temp = substr($line, length($values[0]));
              chomp($temp);
	      $fileColumnData{$values[0]} = $temp;
            }
	  }
        }
      }
    }
  }
}

sub processCnfFile {
  $file = $_;
  if (!(-d $file) && $file =~ /.*\.cnf/) {
# we have a file that is a cnf file
    use Time::HiRes(gettimeofday);
    print OUTPUT $file;
    foreach $solver (keys %solvers) {
      $values = runFile($file, $solver);
      $output = join "", $pwd, "/testbed_output.txt";
      use File::ReadBackwards;
      my $bw = File::ReadBackwards->new($output)
        or die "Can't read output.txt: $!";
      $lastLine = $bw->readline();
      chomp($lastLine);
      @values = split(",", $lastLine);
      $i = 1;
      foreach $columnName (@columnNames) {
        $columnData{$columnName} = "$columnData{$columnName},$values[$i++]";
      }
    }
    if($includeFileData) {
      if(exists $fileColumnData{$file}) {
        print OUTPUT $fileColumnData{$file};
      } else {
 	$numColumns = @fileColumnNames;
        for($i = 0; i < $numColumns; $i++) {
	  print OUTPUT ",";
        }
      }
    }
    foreach $columnName (@columnNames) {
      $columnValues = $columnData{$columnName};
      $columnData{$columnName} = "";
      print OUTPUT $columnValues;	
    }
    print OUTPUT "\n";
  }
}

sub runFile {
  use Fcntl qw(:flock);
  local($file, $solver) = @_;
  $childpid = fork();
  eval {
    $SIG{ALRM} = sub {
      flock(PROGOUTPUT, LOCK_EX);
      seek(PROGOUTPUT, 0, 2);
      print PROGOUTPUT ",timeout,,,,,,,timeout,,\n";
      flock(PROGOUTPUT, LOCK_UN);
      kill -9, $childpid;
    };
    if ($childpid != 0) {    
      waitpid($childpid, 0);
    } elsif ($childpid == 0) {
      setpgrp(0,0);
      alarm $timeout;
      $start=gettimeofday();
      $output = join "", $pwd, "/", $file, "_", $timeformat, "_", $solvers{$solver}, ".txt";
      system "$solver $file > $output 2>&1"; #  Call the real solver
      alarm 0;
      $end=gettimeofday();
      foreach $columnName (@columnNames) {
        if($columnName eq "SAT/UNSAT") {
	  use File::ReadBackwards;
          my $bw = File::ReadBackwards->new($output)
            or die "Can't read output.txt: $!";
          $lastLine = $bw->readline();
          if($lastLine =~ /.*UNSAT.*/) {
            print PROGOUTPUT ",UNSAT";
          } elsif ($lastLine =~ /.*SAT.*/) {
	    print PROGOUTPUT ",SAT";
          } else {
            print PROGOUTPUT ",crashed";
          }
        } elsif ($columnName eq "time") {
	  use File::ReadBackwards;
          my $bw = File::ReadBackwards->new($output)
            or die "Can't read output.txt: $!";
          $lastLine = $bw->readline();
          if($lastLine =~ /.*UNSAT.*/) {
            print PROGOUTPUT ",", $end - $start;
          } elsif ($lastLine =~ /.*SAT.*/) {
            print PROGOUTPUT ",", $end - $start;
          } else {
            print PROGOUTPUT ",crashed";
          }
        } elsif ($columnName eq "validated") {
          $value = `grep solution $output`;
          @parts = split(' ', $value);
          shift(@parts);
          if(@parts) {
            `java -jar /home/nicolen/Documents/Thesis/check.jar $file $parts[0] > validation.txt`;
            $valid = `grep Satisfied validation.txt`;
            if($valid eq "") {
              print PROGOUTPUT ",not-valid";
            } else {
              print PROGOUTPUT ",valid";
            }
          } else {
            print PROGOUTPUT ",";  
          }
        } else {
          $value = `grep $columnName $output`;
          @parts = split(' ', $value);
          shift(@parts);
          if(@parts) {
            print PROGOUTPUT ",", $parts[0];
          } else {
            print PROGOUTPUT ",";  
          }
        }
      }
      print PROGOUTPUT "\n";
      exit;
    } else {
      print "Problem with fork\n";
      exit;
    }
  };
}

sub emailOutput() {
  use Net::SMTP;
  $smtp = Net::SMTP->new('gmail.com', 'Debug' => 1);
# connect to an SMTP server
  if (!defined($smtp) || !($smtp)) {
    print "SMTP ERROR: Unable to open smtp session.\n";
    return 0;
  }
  $smtp->mail('nicole.nelson8489@gmail.com');
# use the sender's address here
  $smtp->to('nelson64@students.rowan.edu');        # recipient's address
  $smtp->data();
# Start the mail

# Send the header.
  $smtp->datasend("To: nelson64\@students.rowan.edu\n");
  $smtp->datasend("From: nicole.nelson8489\@gmail.com\n");
  $smtp->datasend("\n");

# Send the body.
  $smtp->datasend("Hello, World!\n");
  $smtp->dataend();
# Finish sending the mail
  $smtp->quit;
# Close the SMTP connection
  print "EMAILED";
}
