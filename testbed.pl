#!/usr/bin/perl
$email;
$timeout;
@directories;
$outputfile;
@solvers;

if ($#ARGV < 1) {
  print "testbed.pl #solvers 'solver1' 'solver2' ... 'solvern' flags\n";
  print "Note: the last line of a solvers output must be SAT or UNSAT";
  print "Testbed flags: \n";
  print "-e email address to notify upon completion \n";
  print "-d directory of cnf files \n";
  print "-t timeout limit per cnf file \n";
  exit;
} else {
  use File::Basename;
  @timedata = localtime(time);
  $test = join "", $timedata[5]+1900, "_", $timedata[4], "_", $timedata[3], "-", $timedata[2], ":", $timedata[1], ":", $timedata[0];
  $outputfile = join "", ">output", $test, ".csv";
  open(OUTPUT, $outputfile);
  parseCommandLine();
  print OUTPUT "filename";
  $numSolvers = @solvers;
  if($numSolvers > 0) {
    foreach $solver (@solvers) {
      print OUTPUT ",$solver time, $solver SAT/UNSAT";
    }
  } else {
    print "there must be at least one solver to run\n";
    exit;
  }
  print OUTPUT "\n";
  
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
#  emailOutput();
}

sub parseCommandLine() {
  for (my $i = 0; $i <= $#ARGV; $i++) {
    if ($ARGV[$i] =~ /-s[0-9]*/) {
      $tempStr = substr $ARGV[$i], 2;
      $numSolvers = int($tempStr);
      print $numSolvers, "\n";
      for(my $j = 0; $j < $numSolvers; $j++) {
        $i++;
	if($ARGV[$i] eq "-d" || $ARGV[$i] eq "-e" || $ARGV[$i] eq "-t") {
          print "argument $i should be a solver based on the input number of solvers $numSolvers\n";
          exit;
        }
        push(@solvers, $ARGV[$i]);
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
  }
}

sub processCnfFile {
  $file = $_;
  if (!(-d $file) && $file =~ /.*\.cnf/) {
# we have a file that is a cnf file
    use Time::HiRes(gettimeofday);
    print OUTPUT $file;
    foreach $solver (@solvers) {
      runFile($file, $solver);
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
      print "alarm!!!\n";
      flock(OUTPUT, LOCK_EX);
#      flock($OUTPUT, 0, SEEK_END);
      seek(OUTPUT, 0, 2);
      print OUTPUT ",timeout,timeout";
      flock(OUTPUT, LOCK_UN);
      kill -9, $childpid;
    };
    if ($childpid != 0) {    
      waitpid($childpid, 0);
    } elsif ($childpid == 0) {
      setpgrp(0,0);
      alarm $timeout;
      $start=gettimeofday();
      $result = system "$solver $file >> output.txt 2>test.txt"; #  Call the real solver
      alarm 0;
      $end=gettimeofday();
      use File::ReadBackwards;
      my $bw = File::ReadBackwards->new("output.txt")
        or die "Can't read output.txt: $!";
      $lastLine = $bw->readline();
      print $lastLine;
      if($lastLine =~ /.*UNSAT.*/) {
        print OUTPUT ",UNSAT";
        print OUTPUT ",", $end - $start;
      } elsif ($lastLine =~ /.*SAT.*/) {
	print OUTPUT ",SAT";
        print OUTPUT ",", $end - $start;
      } else {
        print OUTPUT ",crashed,crashed";
      }
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
