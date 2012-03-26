#!/usr/bin/perl
$solver1;
$solver2;
$email;
$timeout;
@directories;

if ($#ARGV < 1) {
  print "testbed.pl #solvers 'solver1' 'solver2' ... 'solvern' flags\n";
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
  $solver1 = $ARGV[0];
  $solver2 = $ARGV[1];
  print OUTPUT ",",$solver1,",",$solver2,"\n";
  parseCommandLine();
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
  for (my $i = 2; $i <= $#ARGV; $i++) {
    if ($ARGV[$i] eq "-d") {
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
    use File::Basename;
    use Time::HiRes(gettimeofday);
    print OUTPUT basename($file), ",";
    print basename($file), "\n";
    runFile($file);
    print OUTPUT "\n";
  }
}

sub runFile {
  local($file) = @_;
  $didtimeout=0;
  $childpid = fork();
  eval {
    local $SIG{ALRM} = sub {
      print "alarm!!!\n";
      print OUTPUT "timeout";
      kill -9, $childpid;
    };
    if ($childpid != 0) {    
      waitpid($childpid, 0);
    } elsif ($childpid == 0) {
      setpgrp(0,0);
      alarm $timeout;
      $start=gettimeofday();
      $result = system "$solver1 $file >> output.txt"; #  Call the real solver
      alarm 0;
      print "test again ", $result, " -- ", $result >> 8, "\n";
      $end=gettimeofday();
      print OUTPUT $end - $start, ",";
      exit;
    } else {
      print "Problem with fork\n";
      exit;
    }
  };
  # if $@ is defined then the call did not exit successfully
  if($@) {
    # the call has either timed out or crashed
    # if it timed out we already handled it,
    # if it crashed we need to record it
    print "defined\n";
  }
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
